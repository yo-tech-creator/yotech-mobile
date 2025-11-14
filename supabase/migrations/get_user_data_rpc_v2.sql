-- ================================================================
-- GET USER DATA RPC: String ID ile (Flutter uyumlu)
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_user_data_by_id(
  p_user_id TEXT  -- UUID yerine TEXT (Flutter string gönderir)
)
RETURNS TABLE (
  id TEXT,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  tenant_id TEXT,
  branch_id TEXT,
  region_id TEXT,
  employee_code TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id::TEXT,
    u.email::TEXT,
    u.first_name::TEXT,
    u.last_name::TEXT,
    u.role::TEXT,
    u.tenant_id::TEXT,
    u.branch_id::TEXT,
    u.region_id::TEXT,
    u.employee_code::TEXT
  FROM public.users u
  WHERE u.id = p_user_id::UUID
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_data_by_id(TEXT) TO authenticated, anon;

COMMENT ON FUNCTION public.get_user_data_by_id IS 
'Kullanıcı bilgilerini enum-safe şekilde döner (Flutter string ID)';
