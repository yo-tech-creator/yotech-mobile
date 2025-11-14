-- ================================================================
-- FINAL SOLUTION - ENUM CASTING FIXED
-- ================================================================

-- STEP 1: Drop and recreate RPC functions with proper enum handling
DROP FUNCTION IF EXISTS public.get_user_email_by_sicil(TEXT);
DROP FUNCTION IF EXISTS public.get_user_data_by_id(TEXT);

-- Email lookup RPC (for login)
CREATE FUNCTION public.get_user_email_by_sicil(p_sicil_no TEXT)
RETURNS TABLE (email TEXT, active BOOLEAN) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT email::TEXT, active
  FROM users
  WHERE employee_code = p_sicil_no
  LIMIT 1;
$$;

-- User data RPC (enum-safe)
CREATE FUNCTION public.get_user_data_by_id(p_user_id TEXT)
RETURNS TABLE (
  id TEXT, email TEXT, first_name TEXT, last_name TEXT,
  role TEXT, tenant_id TEXT, branch_id TEXT, employee_code TEXT
) 
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 
    id::TEXT,
    email::TEXT,
    first_name::TEXT,
    last_name::TEXT,
    role::TEXT,  -- Cast enum to text
    tenant_id::TEXT,
    branch_id::TEXT,
    employee_code::TEXT
  FROM users
  WHERE id = p_user_id::UUID
  LIMIT 1;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_user_email_by_sicil(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_user_data_by_id(TEXT) TO authenticated, anon;

-- STEP 2: Disable custom_access_token_hook (make it do nothing)
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

-- STEP 3: Clean up existing user
DELETE FROM auth.sessions WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'ahmet@filemarket.com');
DELETE FROM auth.refresh_tokens WHERE user_id IN (SELECT id FROM auth.users WHERE email = 'ahmet@filemarket.com');
DELETE FROM auth.users WHERE email = 'ahmet@filemarket.com';
DELETE FROM public.users WHERE employee_code = 'FILE001';

-- STEP 4: Create auth user
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  'authenticated', 'authenticated', 'ahmet@filemarket.com',
  crypt('test123456', gen_salt('bf')),
  NOW(), NOW(), NOW(),
  '', '', '', ''
);

-- STEP 5: Create public user WITH ENUM CAST
INSERT INTO public.users (
  id, tenant_id, branch_id,
  first_name, last_name, email, phone,
  employee_code, role, position, active
) VALUES (
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  '11111111-1111-1111-1111-111111111111',
  '476442db-abe8-475b-9cef-fccf1e852652',
  'Ahmet', 'Yılmaz', 'ahmet@filemarket.com', '5551234567',
  'FILE001', 
  'personel'::user_role,  -- ✅ ENUM CAST
  'Personel', 
  true
);

-- STEP 6: Verify
SELECT 'Email lookup test:' as test;
SELECT * FROM get_user_email_by_sicil('FILE001');

SELECT 'User data test:' as test;
SELECT * FROM get_user_data_by_id('e1392666-dcfb-497c-9361-7c735a6d9612');

SELECT 'Direct users table check:' as test;
SELECT id, employee_code, email, role::text, active FROM users WHERE employee_code = 'FILE001';

-- ================================================================
-- After running this SQL:
-- 1. Close the app completely
-- 2. Restart: flutter run
-- 3. Login: FILE001 / test123456
-- ================================================================
