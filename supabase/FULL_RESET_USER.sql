-- ================================================================
-- TAM TEMİZLİK: Auth User'ı Yeniden Oluştur
-- ================================================================

-- ADIM 1: Auth user'ı tamamen sil
DELETE FROM auth.users WHERE email = 'ahmet@filemarket.com';

-- ADIM 2: Public user'ı da sil
DELETE FROM public.users WHERE employee_code = 'FILE001';

-- ADIM 3: Yeni auth user oluştur
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  'authenticated',
  'authenticated',
  'ahmet@filemarket.com',
  crypt('test123456', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
);

-- ADIM 4: Public user'ı oluştur (aynı ID ile)
INSERT INTO public.users (
  id,
  tenant_id,
  branch_id,
  first_name,
  last_name,
  email,
  phone,
  employee_code,
  role,
  position,
  active
) VALUES (
  'e1392666-dcfb-497c-9361-7c735a6d9612',
  '11111111-1111-1111-1111-111111111111',
  '476442db-abe8-475b-9cef-fccf1e852652',
  'Ahmet',
  'Yılmaz',
  'ahmet@filemarket.com',
  '5551234567',
  'FILE001',
  'personel',  -- String olarak personel
  'Personel',
  true
);

-- ADIM 5: Kontrol
SELECT 
    id,
    employee_code,
    email,
    role::text,
    tenant_id
FROM public.users
WHERE employee_code = 'FILE001';

-- ================================================================
-- SONUÇ:
-- Bu SQL'i çalıştırdıktan sonra app'i tamamen kapat ve yeniden aç
-- Login: FILE001 / test123456
-- ================================================================
