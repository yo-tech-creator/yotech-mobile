-- Fix store_scoring_sessions UPDATE RLS policy
-- Ensure authenticated users can update their own sessions

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "scoring_sessions_update" ON "public"."store_scoring_sessions";
DROP POLICY IF EXISTS "tenant scoring sessions update" ON "public"."store_scoring_sessions";

-- Create a simple update policy that allows users to update their own sessions
CREATE POLICY "scoring_sessions_update" ON "public"."store_scoring_sessions"
  FOR UPDATE
  TO public
  WITH CHECK (
    -- Service role can do anything
    auth.role() = 'service_role'
    OR
    -- User can update their own session
    evaluator_id = auth.uid()
  );

-- Also create authenticated role policy
CREATE POLICY "tenant scoring sessions update" ON "public"."store_scoring_sessions"
  FOR UPDATE
  TO authenticated
  USING (
    evaluator_id = auth.uid()
    OR
    branch_belongs_to_current_tenant(branch_id)
  )
  WITH CHECK (
    evaluator_id = auth.uid()
    OR
    branch_belongs_to_current_tenant(branch_id)
  );

COMMENT ON POLICY "scoring_sessions_update" ON "public"."store_scoring_sessions" IS 
'Allows users to update their own scoring sessions';
