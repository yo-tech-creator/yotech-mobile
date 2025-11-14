-- ================================================================
-- FINAL FIX (CORRECTED): region_id removed
-- ================================================================

-- 1. Email bulma RPC
CREATE OR REPLACE FUNCTION public.get_user_email_by_sicil(
  p_sicil_no TEXT
)
RETURNS TABLE (
  email TEXT,
  active BOOLEAN
) 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.email::TEXT,
    u.active
  FROM public.users u
  WHERE u.employee_code = p_sicil_no
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_email_by_sicil(TEXT) TO authenticated, anon;

-- 2. User data RPC (WITHOUT region_id)
CREATE OR REPLACE FUNCTION public.get_user_data_by_id(
  p_user_id TEXT
)
RETURNS TABLE (
  id TEXT,
  email TEXT,
  first_name TEXT,
  last_name TEXT,
  role TEXT,
  tenant_id TEXT,
  branch_id TEXT,
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
    COALESCE(u.branch_id::TEXT, NULL),
    COALESCE(u.employee_code::TEXT, NULL)
  FROM public.users u
  WHERE u.id = p_user_id::UUID
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_data_by_id(TEXT) TO authenticated, anon;

-- 3. Dummy hook
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN event;
END;
$$;

GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated, anon, public;

-- 4. User'ı yeniden oluştur
DELETE FROM auth.users WHERE email = 'ahmet@filemarket.com';
DELETE FROM public.users WHERE employee_code = 'FILE001';

INSERT INTO auth.users (
  instance_id, id, aud, role, email,
  encrypted_password, email_confirmed_at,
  created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  'authenticated', 'authenticated', 'ahmet@filemarket.com',
  crypt('test123456', gen_salt('bf')), NOW(),
  NOW(), NOW(),
  '', '', '', ''
);

INSERT INTO public.users (
  id, tenant_id, branch_id,
  first_name, last_name, email, phone,
  employee_code, role, position, active
) VALUES (
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  '11111111-1111-1111-1111-111111111111',
  '476442db-abe8-475b-9cef-fccf1e852652',
  'Ahmet', 'Yılmaz', 'ahmet@filemarket.com', '5551234567',
  'FILE001', 'personel', 'Personel', true
);

-- 5. Test
SELECT * FROM get_user_email_by_sicil('FILE001');
SELECT * FROM get_user_data_by_id('e1392666-dcfb-497c-9361-7c735a6d9612');
