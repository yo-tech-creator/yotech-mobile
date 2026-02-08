-- Fix store_scoring_sessions INSERT RLS policy
-- The issue is that auth.role() returns Supabase auth role (authenticated, anon)
-- not the application user role (personel, sube_muduru, bolge_muduru etc.)
-- We need to use current_user_role() instead

-- Drop the problematic policy
DROP POLICY IF EXISTS "scoring_sessions_insert" ON "public"."store_scoring_sessions";

-- Create a new, simpler policy that allows authenticated users to insert sessions
-- for their own tenant's forms
CREATE POLICY "scoring_sessions_insert" ON "public"."store_scoring_sessions"
  FOR INSERT
  TO public
  WITH CHECK (
    -- Service role can do anything
    auth.role() = 'service_role'
    OR
    -- Authenticated users can insert if:
    (
      -- They are the evaluator
      evaluator_id = auth.uid()
      AND
      -- The form belongs to their tenant
      EXISTS (
        SELECT 1
        FROM store_scoring_form_versions v
        JOIN store_scoring_forms f ON f.id = v.form_id
        WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = current_tenant_id()
      )
      AND
      -- The branch belongs to their tenant (or is their own branch, or they manage it)
      (
        branch_belongs_to_current_tenant(branch_id)
        OR
        branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
      )
    )
  );

-- Also update the tenant scoring sessions insert policy to be more permissive
DROP POLICY IF EXISTS "tenant scoring sessions insert" ON "public"."store_scoring_sessions";

CREATE POLICY "tenant scoring sessions insert" ON "public"."store_scoring_sessions"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- The evaluator must be the current user
    evaluator_id = auth.uid()
    AND
    -- The branch must belong to current tenant
    branch_belongs_to_current_tenant(branch_id)
    AND
    -- The form must belong to current tenant  
    EXISTS (
      SELECT 1
      FROM store_scoring_form_versions v
      JOIN store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id
      AND f.tenant_id = current_tenant_id()
    )
  );

COMMENT ON POLICY "scoring_sessions_insert" ON "public"."store_scoring_sessions" IS 
'Allows users to create scoring sessions for forms in their tenant';

COMMENT ON POLICY "tenant scoring sessions insert" ON "public"."store_scoring_sessions" IS 
'Allows authenticated users to create scoring sessions for their own tenant forms';
