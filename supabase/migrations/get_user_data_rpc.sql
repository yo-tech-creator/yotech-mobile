-- ================================================================
-- GET USER DATA RPC: Enum-safe kullanıcı bilgileri
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_user_data_by_id(
  p_user_id UUID
)
RETURNS TABLE (
  id UUID,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  tenant_id UUID,
  branch_id UUID,
  region_id UUID,
  employee_code TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email::TEXT,
    u.first_name::TEXT,
    u.last_name::TEXT,
    u.role::TEXT,  -- ENUM'ı TEXT'e cast et
    u.tenant_id,
    u.branch_id,
    u.region_id,
    u.employee_code::TEXT
  FROM public.users u
  WHERE u.id = p_user_id
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_data_by_id(UUID) TO authenticated, anon;

COMMENT ON FUNCTION public.get_user_data_by_id IS 
'Kullanıcı bilgilerini enum-safe şekilde döner';

-- Test
SELECT * FROM get_user_data_by_id('e1392666-dcfb-497c-9361-7c735a6d9612');
