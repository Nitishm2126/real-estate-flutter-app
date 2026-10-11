-- ============================================================
-- Migration: profiles table + Row Level Security
-- MCP Avadi CRM — Supabase Auth & RBAC
-- Run in Supabase SQL Editor (postgres or service_role)
-- ============================================================

-- 1. Create profiles table linked to auth.users
CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT        NOT NULL,
  role        TEXT        NOT NULL CHECK (role IN ('gm', 'bdm')),
  branch      TEXT        NOT NULL DEFAULT 'Avadi Branch',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. Authenticated users can read ONLY their own profile
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
CREATE POLICY "profiles_select_own"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- 4. Only service_role may insert profiles (users cannot self-assign roles)
DROP POLICY IF EXISTS "profiles_insert_service" ON public.profiles;
CREATE POLICY "profiles_insert_service"
  ON public.profiles
  FOR INSERT
  TO service_role
  WITH CHECK (true);

-- 5. Only service_role may update profiles
DROP POLICY IF EXISTS "profiles_update_service" ON public.profiles;
CREATE POLICY "profiles_update_service"
  ON public.profiles
  FOR UPDATE
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 6. Only service_role may delete profiles
DROP POLICY IF EXISTS "profiles_delete_service" ON public.profiles;
CREATE POLICY "profiles_delete_service"
  ON public.profiles
  FOR DELETE
  TO service_role
  USING (true);

-- ============================================================
-- AFTER creating auth users in the Dashboard, run this to
-- seed the two staff profiles (use Supabase SQL Editor):
--
--   INSERT INTO public.profiles (id, full_name, role, branch)
--   SELECT id, 'T. Meenakshi Sundaram', 'gm', 'Avadi Branch'
--   FROM auth.users WHERE email = 'gm@mcpavadi.in';
--
--   INSERT INTO public.profiles (id, full_name, role, branch)
--   SELECT id, 'Bala Murugan', 'bdm', 'Avadi Branch'
--   FROM auth.users WHERE email = 'bdm@mcpavadi.in';
-- ============================================================
