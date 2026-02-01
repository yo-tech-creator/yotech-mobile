-- RPC functions for announcement/survey lookup data
-- These functions bypass RLS for admin operations

-- Get current user's profile (branch_id, tenant_id, and region_id from branch)
CREATE OR REPLACE FUNCTION public.get_current_user_profile()
RETURNS TABLE (
  branch_id uuid,
  tenant_id uuid,
  region_id uuid
) 
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT u.branch_id, u.tenant_id, b.region_id
  FROM public.users u
  LEFT JOIN public.branches b ON b.id = u.branch_id
  WHERE u.id = auth.uid();
END;
$$;

-- Get all regions for current user's tenant
CREATE OR REPLACE FUNCTION public.get_tenant_regions()
RETURNS TABLE (
  id uuid,
  name text
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  SELECT u.tenant_id INTO v_tenant_id FROM public.users u WHERE u.id = auth.uid();
  
  RETURN QUERY
  SELECT r.id, r.name
  FROM public.regions r
  WHERE r.tenant_id = v_tenant_id
  ORDER BY r.name;
END;
$$;

-- Get all active branches for current user's tenant
CREATE OR REPLACE FUNCTION public.get_tenant_branches()
RETURNS TABLE (
  id uuid,
  name text,
  region_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  SELECT u.tenant_id INTO v_tenant_id FROM public.users u WHERE u.id = auth.uid();
  
  RETURN QUERY
  SELECT b.id, b.name, b.region_id
  FROM public.branches b
  WHERE b.tenant_id = v_tenant_id
    AND b.active = true
  ORDER BY b.name;
END;
$$;

-- Get personnel for a specific branch (for sube_muduru)
CREATE OR REPLACE FUNCTION public.get_branch_personnel(p_branch_id uuid)
RETURNS TABLE (
  id uuid,
  first_name text,
  last_name text,
  role text,
  branch_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.first_name, u.last_name, u.role::text, u.branch_id
  FROM public.users u
  WHERE u.branch_id = p_branch_id
    AND u.role = 'personel'
  ORDER BY u.first_name;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_current_user_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tenant_regions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tenant_branches() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_branch_personnel(uuid) TO authenticated;
