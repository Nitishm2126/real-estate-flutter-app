import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { JWT } from "npm:google-auth-library@9.4.1";

// Expected Supabase Secrets:
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - FIREBASE_SERVICE_ACCOUNT (JSON stringified service account)

serve(async (req) => {
  // We only allow POST requests.
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  // Optional: Add basic security header check if called from pg_cron
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401 });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      throw new Error("Missing Supabase configuration in environment variables.");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Fetch due follow-ups
    // A follow-up is due if follow_up_date + follow_up_time <= current time
    // We will do the time calculation in JS to handle Asia/Kolkata timezone correctly.
    // First, fetch all pending, unnotified follow-ups
    const { data: followUps, error: fetchError } = await supabase
      .from("customer_follow_ups")
      .select(`
        id,
        customer_id,
        follow_up_date,
        follow_up_time,
        notes,
        status,
        notification_sent
      `)
      .eq("notification_sent", false)
      .neq("status", "Completed");

    if (fetchError) {
      throw fetchError;
    }

    if (!followUps || followUps.length === 0) {
      return new Response(JSON.stringify({ message: "No pending follow-ups to notify" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 2. Filter due follow-ups based on Asia/Kolkata time
    const now = new Date();
    
    // Function to parse India time string into a comparable JS Date
    const parseIST = (dateStr: string, timeStr: string | null) => {
      // dateStr is 'YYYY-MM-DD'
      // timeStr is '10:30', '10:30 AM', etc.
      let [year, month, day] = dateStr.split("T")[0].split("-").map(Number);
      
      let hour = 10;
      let minute = 0;
      
      if (timeStr) {
        const timeCleaned = timeStr.trim();
        const parts = timeCleaned.split(/[:\s]+/);
        if (parts.length >= 2) {
          hour = parseInt(parts[0]);
          minute = parseInt(parts[1]);
          if (parts.length >= 3) {
            const ampm = parts[2].toUpperCase();
            if (ampm === "PM" && hour < 12) hour += 12;
            if (ampm === "AM" && hour === 12) hour = 0;
          }
        }
      }

      // Create a Date object representing the time in IST, but since JS Date is tricky with zones,
      // we can construct the UTC equivalent. IST is UTC+5:30.
      const utcTime = new Date(Date.UTC(year, month - 1, day, hour - 5, minute - 30));
      return utcTime;
    };

    const dueFollowUps = followUps.filter((fu) => {
      const scheduledTime = parseIST(fu.follow_up_date, fu.follow_up_time);
      return scheduledTime.getTime() <= now.getTime();
    });

    if (dueFollowUps.length === 0) {
      return new Response(JSON.stringify({ message: "No follow-ups due yet" }), {
        headers: { "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 3. Mark them as processing atomically
    const dueIds = dueFollowUps.map((fu) => fu.id);
    
    const { error: updateError } = await supabase
      .from("customer_follow_ups")
      .update({ notification_sent: true })
      .in("id", dueIds)
      .eq("notification_sent", false); // Atomic check

    if (updateError) {
      throw updateError;
    }

    // 4. Fetch all FCM device tokens
    const { data: tokenData, error: tokenError } = await supabase
      .from("fcm_tokens")
      .select("token");

    if (tokenError) throw tokenError;

    const tokens = tokenData?.map(t => t.token) || [];
    if (tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No registered devices to notify", processed: dueIds.length }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 5. Initialize Firebase OAuth
    const serviceAccountStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountStr) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret.");
    }

    const serviceAccount = JSON.parse(serviceAccountStr);
    
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    const tokensResponse = await jwtClient.getAccessToken();
    const accessToken = tokensResponse.token;
    const projectId = serviceAccount.project_id;

    // 6. Send Notifications
    const sendPromises = [];
    
    for (const fu of dueFollowUps) {
      // Build FCM Message
      const messagePayload = {
        message: {
          // We broadcast to all tokens
          // FCM HTTP v1 doesn't support multiple tokens in a single request directly unless using topics or batch.
          // Since it's a small team CRM, we can loop over tokens or just use the legacy multicast.
          // For HTTP v1, we must send individual requests or subscribe to a topic.
          // Let's iterate over tokens.
        }
      };

      for (const token of tokens) {
        const reqPayload = {
          message: {
            token: token,
            notification: {
              title: "Follow-up Reminder",
              body: `A follow-up is due now.` + (fu.notes ? `\nNotes: ${fu.notes}` : ""),
            },
            data: {
              type: "follow_up",
              follow_up_id: fu.id.toString(),
              customer_id: fu.customer_id.toString(),
            },
            android: {
              priority: "high",
              notification: {
                channel_id: "mcp_avadi_followup_reminders",
                sound: "default"
              }
            }
          }
        };

        const reqPromise = fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(reqPayload),
          }
        ).then(res => res.json()).catch(err => ({ error: err }));
        
        sendPromises.push(reqPromise);
      }
    }

    const results = await Promise.all(sendPromises);
    
    // 7. Cleanup invalid tokens (Optional but recommended)
    const invalidTokens: string[] = [];
    results.forEach((res, index) => {
      if (res.error && res.error.code === 404) {
        // Token not found/unregistered
        const tokenIndex = index % tokens.length;
        invalidTokens.push(tokens[tokenIndex]);
      }
    });

    if (invalidTokens.length > 0) {
      await supabase.from("fcm_tokens").delete().in("token", invalidTokens);
    }

    return new Response(JSON.stringify({
      message: "Notifications sent successfully",
      processed: dueIds.length,
      successCount: sendPromises.length,
      invalidTokensCleaned: invalidTokens.length
    }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Error processing reminders:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
