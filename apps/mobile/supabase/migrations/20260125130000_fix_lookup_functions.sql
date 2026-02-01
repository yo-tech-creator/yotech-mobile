-- Fix column name issues in announcement lookup functions

-- Drop existing functions first
DROP FUNCTION IF EXISTS get_current_user_profile();
DROP FUNCTION IF EXISTS get_tenant_branches(uuid);

-- Recreate get_current_user_profile with correct column references
-- Users table has NO region_id, so we join branches to get it
CREATE OR REPLACE FUNCTION get_current_user_profile()
RETURNS TABLE(branch_id uuid, tenant_id uuid, region_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT u.branch_id, u.tenant_id, b.region_id
    FROM public.users u
    LEFT JOIN public.branches b ON b.id = u.branch_id
    WHERE u.id = auth.uid();
END;
$$;

-- Recreate get_tenant_branches with correct column name (active not is_active)
CREATE OR REPLACE FUNCTION get_tenant_branches(p_tenant_id uuid)
RETURNS TABLE(id uuid, name text, region_id uuid, code text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id uuid;
BEGIN
    v_tenant_id := COALESCE(p_tenant_id, (SELECT u.tenant_id FROM public.users u WHERE u.id = auth.uid()));

    RETURN QUERY
    SELECT b.id, b.name, b.region_id, b.code
    FROM public.branches b
    WHERE b.tenant_id = v_tenant_id
      AND b.active = true
    ORDER BY b.name;
END;
$$;
