-- Fix store scoring policies to respect tenant isolation without relying on branch table RLS.
-- Creates helper functions that run with elevated privileges and rewrites policies.

BEGIN;

CREATE OR REPLACE FUNCTION public.branch_belongs_to_current_tenant(p_branch_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.branches b
    WHERE b.id = p_branch_id
      AND b.tenant_id = current_tenant_id()
  );
$$;

CREATE OR REPLACE FUNCTION public.session_belongs_to_current_tenant(p_session_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.store_scoring_sessions s
    WHERE s.id = p_session_id
      AND branch_belongs_to_current_tenant(s.branch_id)
  );
$$;

DROP POLICY IF EXISTS "tenant scoring sessions select" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions insert" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions update" ON public.store_scoring_sessions;

CREATE POLICY "tenant scoring sessions select"
  ON public.store_scoring_sessions
  FOR SELECT
  TO authenticated
  USING (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND branch_belongs_to_current_tenant(branch_id)
  );

CREATE POLICY "tenant scoring sessions insert"
  ON public.store_scoring_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND branch_belongs_to_current_tenant(branch_id)
  );

CREATE POLICY "tenant scoring sessions update"
  ON public.store_scoring_sessions
  FOR UPDATE
  TO authenticated
  USING (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND branch_belongs_to_current_tenant(branch_id)
  )
  WITH CHECK (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND branch_belongs_to_current_tenant(branch_id)
  );

DROP POLICY IF EXISTS "tenant scoring session items manage" ON public.store_scoring_session_items;

CREATE POLICY "tenant scoring session items manage"
  ON public.store_scoring_session_items
  FOR ALL
  TO authenticated
  USING (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND session_belongs_to_current_tenant(session_id)
  )
  WITH CHECK (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND session_belongs_to_current_tenant(session_id)
  );

COMMIT;
