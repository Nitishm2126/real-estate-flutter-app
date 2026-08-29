-- Create fcm_tokens table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL UNIQUE,
    token TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Enable RLS on fcm_tokens (even without Auth, we can restrict to anon)
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Allow anon role to insert/update their own device tokens
-- Note: Without authenticated users, this relies on the client identifying itself with device_id.
-- This policy allows inserts.
CREATE POLICY "Allow anonymous inserts to fcm_tokens" ON public.fcm_tokens
FOR INSERT TO anon
WITH CHECK (true);

-- This policy allows updates to existing device tokens
CREATE POLICY "Allow anonymous updates to fcm_tokens" ON public.fcm_tokens
FOR UPDATE TO anon
USING (true)
WITH CHECK (true);

-- This policy allows reading (we shouldn't allow clients to read all tokens, but maybe they need to read their own).
-- However, since anon can't securely prove identity, we restrict read to the service role (which the Edge Function uses).
-- So no read policy for anon.
CREATE POLICY "Allow service_role read access to fcm_tokens" ON public.fcm_tokens
FOR SELECT TO service_role
USING (true);

-- Add notification_sent to customer_follow_ups if it doesn't exist
ALTER TABLE public.customer_follow_ups
ADD COLUMN IF NOT EXISTS notification_sent BOOLEAN DEFAULT false;

-- Create an index to speed up the scheduled function query
CREATE INDEX IF NOT EXISTS idx_customer_follow_ups_due 
ON public.customer_follow_ups(follow_up_date, status, notification_sent) 
WHERE notification_sent = false AND status != 'Completed';
