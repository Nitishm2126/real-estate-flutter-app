-- ============================================================
-- Migration: customers + customer_follow_ups Row Level Security
-- MCP Avadi CRM — Supabase Auth & RBAC
-- Run in Supabase SQL Editor AFTER 20261011_profiles_rls.sql
-- ============================================================

-- 1. Add created_by attribution column to customers
ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id);

-- 2. Enable RLS on customers
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;

-- 3. Enable RLS on customer_follow_ups
ALTER TABLE public.customer_follow_ups ENABLE ROW LEVEL SECURITY;

-- ── Helper function: returns the caller's role from profiles ──────────────────
CREATE OR REPLACE FUNCTION public.get_my_role()
  RETURNS TEXT
  LANGUAGE SQL
  STABLE
  SECURITY DEFINER
  SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- ── customers policies ────────────────────────────────────────────────────────

-- GM and BDM can both SELECT all customers (shared CRM data)
DROP POLICY IF EXISTS "customers_select_authenticated" ON public.customers;
CREATE POLICY "customers_select_authenticated"
  ON public.customers
  FOR SELECT
  TO authenticated
  USING (true);

-- Any authenticated user (GM or BDM) can INSERT customers
DROP POLICY IF EXISTS "customers_insert_authenticated" ON public.customers;
CREATE POLICY "customers_insert_authenticated"
  ON public.customers
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- Any authenticated user can UPDATE any customer
-- (GM has full access; BDM can update any record — scope restricted at app layer if needed)
DROP POLICY IF EXISTS "customers_update_authenticated" ON public.customers;
CREATE POLICY "customers_update_authenticated"
  ON public.customers
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Only GM can delete customers
DROP POLICY IF EXISTS "customers_delete_gm_only" ON public.customers;
CREATE POLICY "customers_delete_gm_only"
  ON public.customers
  FOR DELETE
  TO authenticated
  USING (public.get_my_role() = 'gm');

-- ── customer_follow_ups policies ─────────────────────────────────────────────

-- All authenticated users can select all follow-ups (shared CRM)
DROP POLICY IF EXISTS "follow_ups_select_authenticated" ON public.customer_follow_ups;
CREATE POLICY "follow_ups_select_authenticated"
  ON public.customer_follow_ups
  FOR SELECT
  TO authenticated
  USING (true);

-- Any authenticated user can insert follow-ups
DROP POLICY IF EXISTS "follow_ups_insert_authenticated" ON public.customer_follow_ups;
CREATE POLICY "follow_ups_insert_authenticated"
  ON public.customer_follow_ups
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

-- Any authenticated user can update follow-ups
DROP POLICY IF EXISTS "follow_ups_update_authenticated" ON public.customer_follow_ups;
CREATE POLICY "follow_ups_update_authenticated"
  ON public.customer_follow_ups
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Only GM can delete follow-ups
DROP POLICY IF EXISTS "follow_ups_delete_gm_only" ON public.customer_follow_ups;
CREATE POLICY "follow_ups_delete_gm_only"
  ON public.customer_follow_ups
  FOR DELETE
  TO authenticated
  USING (public.get_my_role() = 'gm');

-- ── fcm_tokens: keep existing anon policies, also allow authenticated ─────────
DROP POLICY IF EXISTS "fcm_tokens_insert_authenticated" ON public.fcm_tokens;
CREATE POLICY "fcm_tokens_insert_authenticated"
  ON public.fcm_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "fcm_tokens_update_authenticated" ON public.fcm_tokens;
CREATE POLICY "fcm_tokens_update_authenticated"
  ON public.fcm_tokens
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);
