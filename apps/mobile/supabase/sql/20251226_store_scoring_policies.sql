-- Store scoring RLS policies
-- Ensures tenant managers can read and write scoring sessions while other tenants remain isolated.

BEGIN;

-- Sessions table policies
DROP POLICY IF EXISTS "tenant scoring sessions select" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions insert" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions update" ON public.store_scoring_sessions;

CREATE POLICY "tenant scoring sessions select"
  ON public.store_scoring_sessions
  FOR SELECT
  TO authenticated
  USING (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND EXISTS (
      SELECT 1
      FROM public.branches b
      WHERE b.id = branch_id
        AND b.tenant_id = current_tenant_id()
    )
  );

CREATE POLICY "tenant scoring sessions insert"
  ON public.store_scoring_sessions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND EXISTS (
      SELECT 1
      FROM public.branches b
      WHERE b.id = branch_id
        AND b.tenant_id = current_tenant_id()
    )
  );

CREATE POLICY "tenant scoring sessions update"
  ON public.store_scoring_sessions
  FOR UPDATE
  TO authenticated
  USING (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND EXISTS (
      SELECT 1
      FROM public.branches b
      WHERE b.id = branch_id
        AND b.tenant_id = current_tenant_id()
    )
  )
  WITH CHECK (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND EXISTS (
      SELECT 1
      FROM public.branches b
      WHERE b.id = branch_id
        AND b.tenant_id = current_tenant_id()
    )
  );

-- Session items table policies
DROP POLICY IF EXISTS "tenant scoring session items manage" ON public.store_scoring_session_items;

CREATE POLICY "tenant scoring session items manage"
  ON public.store_scoring_session_items
  FOR ALL
  TO authenticated
  USING (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND EXISTS (
      SELECT 1
      FROM public.store_scoring_sessions s
      JOIN public.branches b ON b.id = s.branch_id
      WHERE s.id = session_id
        AND b.tenant_id = current_tenant_id()
    )
  )
  WITH CHECK (
    current_user_role() IN ('bolge_muduru', 'sube_muduru', 'firma_admin', 'grand_admin')
    AND EXISTS (
      SELECT 1
      FROM public.store_scoring_sessions s
      JOIN public.branches b ON b.id = s.branch_id
      WHERE s.id = session_id
        AND b.tenant_id = current_tenant_id()
    )
  );

COMMIT;
