# Supabase Manual Setup Steps — MCP Avadi CRM
## Required Dashboard Actions (run once by administrator)

### Step 1 — Run SQL Migrations
1. Open Supabase Dashboard -> SQL Editor
2. Run `supabase/migrations/20261011_profiles_rls.sql` (creates profiles table + RLS)
3. Run `supabase/migrations/20261011_customers_rls.sql` (adds created_by + customers/follow-ups RLS)

### Step 2 — Disable Email Confirmation (for demo)
1. Authentication -> Providers -> Email
2. Toggle "Confirm email" OFF (allows instant login without inbox access)

### Step 3 — Create GM User
1. Authentication -> Users -> Add user
2. Email: gm@mcpavadi.in
3. Password: (set a strong password, minimum 8 characters)
4. Check "Auto Confirm User" if email confirmation is still on

### Step 4 — Create BDM User
1. Authentication -> Users -> Add user
2. Email: bdm@mcpavadi.in
3. Password: (set a strong password, minimum 8 characters)

### Step 5 — Seed Profile Rows (run in SQL Editor after creating users)
```sql
-- Insert GM profile
INSERT INTO public.profiles (id, full_name, role, branch)
SELECT id, 'T. Meenakshi Sundaram', 'gm', 'Avadi Branch'
FROM auth.users WHERE email = 'gm@mcpavadi.in';

-- Insert BDM profile
INSERT INTO public.profiles (id, full_name, role, branch)
SELECT id, 'Bala Murugan', 'bdm', 'Avadi Branch'
FROM auth.users WHERE email = 'bdm@mcpavadi.in';
```

### Step 6 — Verify Setup
```sql
-- Check profiles were created correctly
SELECT u.email, p.full_name, p.role, p.branch
FROM auth.users u
JOIN public.profiles p ON p.id = u.id;
```

### Step 7 — Test Login
- Open the app -> Login screen appears
- Sign in as GM (gm@mcpavadi.in): sees GM dashboard with full name + GM badge
- Sign in as BDM (bdm@mcpavadi.in): sees BDM dashboard with Bala Murugan + BDM badge
- Logout: returns to login screen
- Restart app while signed in: session persists, goes directly to dashboard

## Security Notes
- Passwords are NEVER stored in Flutter source code
- The anon key in constants.dart is publishable (safe to expose per Supabase design)
- Service role key is NEVER in Flutter code (only used in SQL Editor / Edge Functions)
- All customer writes require an authenticated session (RLS enforced at DB level)
- Only GM role can delete customers/follow-ups (enforced via DB function get_my_role())
- Profiles can only be created/updated by service_role (users cannot self-assign roles)
