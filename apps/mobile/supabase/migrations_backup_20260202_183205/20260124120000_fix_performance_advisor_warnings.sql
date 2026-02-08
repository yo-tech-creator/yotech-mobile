-- Migration: Fix Supabase Performance Advisor Warnings
-- Date: 2026-01-24
-- Issues Fixed:
--   1. auth_rls_initplan: Replace auth.<function>() with (SELECT auth.<function>())
--   2. multiple_permissive_policies: Consolidate duplicate policies
--   3. duplicate_index: Remove duplicate index

-- ============================================================================
-- 1. FIX: store_scoring_sessions RLS policies (auth_rls_initplan + multiple_permissive)
-- ============================================================================

-- Drop ALL existing policies for this table (to consolidate)
DROP POLICY IF EXISTS "scoring_sessions_insert" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "scoring_sessions_update" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions insert" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions update" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "store_scoring_sessions_insert" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "store_scoring_sessions_update" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "store_scoring_sessions_select" ON public.store_scoring_sessions;

-- Create consolidated SELECT policy
CREATE POLICY "store_scoring_sessions_select_v2" ON public.store_scoring_sessions
FOR SELECT TO authenticated
USING (
  (SELECT public.current_user_role()) = 'grand_admin'
  OR (
    (SELECT public.current_user_role()) = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (
    (SELECT public.current_user_role()) = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = (SELECT public.current_user_id())
        AND r.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (
    (SELECT public.current_user_role()) IN ('sube_muduru','personel')
    AND store_scoring_sessions.evaluator_id = (SELECT public.current_user_id())
  )
  OR (SELECT public.is_service_role())
);

-- Create consolidated INSERT policy with optimized auth calls
CREATE POLICY "store_scoring_sessions_insert_v2" ON public.store_scoring_sessions
FOR INSERT TO authenticated
WITH CHECK (
  (SELECT public.current_user_role()) = 'grand_admin'
  OR (
    (SELECT public.current_user_role()) = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_forms f
      WHERE f.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (
    (SELECT public.current_user_role()) = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = (SELECT public.current_user_id())
        AND r.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (SELECT public.is_service_role())
);

-- Create consolidated UPDATE policy with optimized auth calls
CREATE POLICY "store_scoring_sessions_update_v2" ON public.store_scoring_sessions
FOR UPDATE TO authenticated
USING (
  (SELECT public.current_user_role()) = 'grand_admin'
  OR (
    (SELECT public.current_user_role()) = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (
    (SELECT public.current_user_role()) = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = (SELECT public.current_user_id())
        AND r.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (SELECT public.is_service_role())
)
WITH CHECK (
  (SELECT public.current_user_role()) = 'grand_admin'
  OR (
    (SELECT public.current_user_role()) = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (
    (SELECT public.current_user_role()) = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = (SELECT public.current_user_id())
        AND r.tenant_id = (SELECT public.current_tenant_id())
    )
  )
  OR (SELECT public.is_service_role())
);

-- ============================================================================
-- 2. FIX: task_attachments RLS policies (auth_rls_initplan)
-- ============================================================================

-- Drop problematic policies
DROP POLICY IF EXISTS "task_attachments_delete_policy" ON public.task_attachments;
DROP POLICY IF EXISTS "task_attachments_insert_policy" ON public.task_attachments;
DROP POLICY IF EXISTS "task_attachments_select_policy" ON public.task_attachments;

-- Recreate with optimized auth calls
CREATE POLICY "task_attachments_select_v2" ON public.task_attachments
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.tasks t
    WHERE t.id = task_attachments.task_id
    AND t.tenant_id = (SELECT public.current_tenant_id())
  )
);

CREATE POLICY "task_attachments_insert_v2" ON public.task_attachments
FOR INSERT TO authenticated
WITH CHECK (
  uploaded_by = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.tasks t
    WHERE t.id = task_attachments.task_id
    AND t.tenant_id = (SELECT public.current_tenant_id())
  )
);

CREATE POLICY "task_attachments_delete_v2" ON public.task_attachments
FOR DELETE TO authenticated
USING (
  uploaded_by = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = (SELECT auth.uid())
    AND u.tenant_id = (SELECT public.current_tenant_id())
    AND u.role IN ('firma_admin', 'bolge_muduru')
  )
);

-- ============================================================================
-- 3. FIX: store_scoring_form_versions multiple policies
-- ============================================================================

-- Drop duplicate policies
DROP POLICY IF EXISTS "store_form_versions_select" ON public.store_scoring_form_versions;
DROP POLICY IF EXISTS "store_form_versions_write" ON public.store_scoring_form_versions;

-- Create single consolidated SELECT policy
CREATE POLICY "store_form_versions_access_v2" ON public.store_scoring_form_versions
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.store_scoring_forms f
    WHERE f.id = store_scoring_form_versions.form_id
    AND f.tenant_id = (SELECT public.current_tenant_id())
  )
);

-- ============================================================================
-- 4. FIX: store_scoring_forms multiple policies
-- ============================================================================

-- Drop duplicate policies
DROP POLICY IF EXISTS "store_forms_select" ON public.store_scoring_forms;
DROP POLICY IF EXISTS "store_forms_write" ON public.store_scoring_forms;

-- Create single consolidated SELECT policy
CREATE POLICY "store_forms_access_v2" ON public.store_scoring_forms
FOR SELECT TO authenticated
USING (
  tenant_id = (SELECT public.current_tenant_id())
);

-- ============================================================================
-- 5. FIX: Duplicate index on users table
-- ============================================================================

-- Drop one of the duplicate indexes (keep idx_users_branch_id as it's more descriptive)
DROP INDEX IF EXISTS public.idx_users_branch;

-- ============================================================================
-- Add comments for documentation
-- ============================================================================

COMMENT ON POLICY "store_scoring_sessions_select_v2" ON public.store_scoring_sessions IS 
'Consolidated select policy with optimized auth calls - fixes auth_rls_initplan warning';

COMMENT ON POLICY "store_scoring_sessions_insert_v2" ON public.store_scoring_sessions IS 
'Consolidated insert policy with optimized auth calls - fixes auth_rls_initplan and multiple_permissive warnings';

COMMENT ON POLICY "store_scoring_sessions_update_v2" ON public.store_scoring_sessions IS 
'Consolidated update policy with optimized auth calls - fixes auth_rls_initplan and multiple_permissive warnings';

COMMENT ON POLICY "task_attachments_select_v2" ON public.task_attachments IS 
'Optimized select policy - fixes auth_rls_initplan warning';

COMMENT ON POLICY "task_attachments_insert_v2" ON public.task_attachments IS 
'Optimized insert policy - fixes auth_rls_initplan warning';

COMMENT ON POLICY "task_attachments_delete_v2" ON public.task_attachments IS 
'Optimized delete policy - fixes auth_rls_initplan warning';
