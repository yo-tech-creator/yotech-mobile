-- ================================================================
-- STEP BY STEP FIX - Her satır ayrı çalıştırılabilir
-- ================================================================

-- ============================================================
-- PART 1: RPC Functions (Bu bloğu çalıştır)
-- ============================================================

DROP FUNCTION IF EXISTS public.get_user_email_by_sicil(TEXT);
DROP FUNCTION IF EXISTS public.get_user_data_by_id(TEXT);

CREATE FUNCTION public.get_user_email_by_sicil(p_sicil_no TEXT)
RETURNS TABLE (email TEXT, active BOOLEAN) 
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT email::TEXT, active FROM users WHERE employee_code = p_sicil_no LIMIT 1;
$$;

CREATE FUNCTION public.get_user_data_by_id(p_user_id TEXT)
RETURNS TABLE (
  id TEXT, email TEXT, first_name TEXT, last_name TEXT,
  role TEXT, tenant_id TEXT, branch_id TEXT, employee_code TEXT
) 
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  SELECT 
    id::TEXT, email::TEXT, first_name::TEXT, last_name::TEXT,
    role::TEXT, tenant_id::TEXT, branch_id::TEXT, employee_code::TEXT
  FROM users WHERE id = p_user_id::UUID LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_email_by_sicil(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_user_data_by_id(TEXT) TO authenticated, anon;

-- ============================================================
-- PART 2: Disable Hook (Bu bloğu çalıştır)
-- ============================================================

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
AS $$ BEGIN RETURN event; END; $$;

GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated, anon, public;

-- ============================================================
-- PART 3: Clean existing user (Her satırı TEK TEK çalıştır!)
-- ============================================================

-- 1. Sessions sil
DELETE FROM auth.sessions 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'ahmet@filemarket.com');

-- 2. Refresh tokens sil
DELETE FROM auth.refresh_tokens 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'ahmet@filemarket.com');

-- 3. Auth user sil
DELETE FROM auth.users WHERE email = 'ahmet@filemarket.com';

-- 4. Public user sil
DELETE FROM public.users WHERE employee_code = 'FILE001';

-- ============================================================
-- PART 4: Create new user (Bu bloğu çalıştır)
-- ============================================================

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  'authenticated', 'authenticated', 'ahmet@filemarket.com',
  crypt('test123456', gen_salt('bf')),
  NOW(), NOW(), NOW(), '', '', '', ''
);

INSERT INTO public.users (
  id, tenant_id, branch_id, first_name, last_name, email, phone,
  employee_code, role, position, active
) VALUES (
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  '11111111-1111-1111-1111-111111111111',
  '476442db-abe8-475b-9cef-fccf1e852652',
  'Ahmet', 'Yılmaz', 'ahmet@filemarket.com', '5551234567',
  'FILE001', 'personel'::user_role, 'Personel', true
);

-- ============================================================
-- PART 5: Test (Bu bloğu çalıştır)
-- ============================================================

SELECT * FROM get_user_email_by_sicil('FILE001');
SELECT * FROM get_user_data_by_id('e1392666-dcfb-497c-9361-7c735a6d9612');
SELECT id, employee_code, email, role::text, active FROM users WHERE employee_code = 'FILE001';
