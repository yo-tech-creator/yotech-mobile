-- ================================================================
-- TEST USER: "yakup" sicil no'lu kullanıcı oluştur
-- ================================================================

-- 1. ÖNCE Supabase Auth'a kullanıcı ekle
-- Dashboard -> Authentication -> Add User:
-- Email: yakup@test.com
-- Password: test123456
-- Email Confirm: YES (hemen onaylı)

-- 2. Auth'dan dönen user_id'yi al ve aşağıda kullan
-- Örnek user_id: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

-- 3. Public.users tablosuna ekle:
INSERT INTO public.users (
  id,  -- Supabase Auth'dan dönen user_id buraya
  tenant_id,
  branch_id,
  first_name,
  last_name,
  email,
  phone,
  employee_code,
  role,
  position,
  hire_date,
  annual_leave_days,
  used_leave_days,
  active
) VALUES (
  'AUTH_USER_ID_BURAYA',  -- ⚠️ Supabase Auth'dan dönen ID'yi buraya yapıştır
  '11111111-1111-1111-1111-111111111111',  -- Tenant ID (FILE Market)
  '476442db-abe8-475b-9cef-fccf1e852652',  -- Branch ID (mevcut şube)
  'Yakup',
  'Test',
  'yakup@test.com',
  '5551234567',
  'yakup',  -- employee_code (sicil no)
  'personel'::user_role,
  'Personel',
  CURRENT_DATE,
  14,
  0,
  true
);

-- ================================================================
-- ALTERNATIF: Eğer auth.users tablosuna direkt eklemek istersen
-- (Bu yöntem daha hızlı ama email confirmation yok)
-- ================================================================

-- ADIM 1: Auth kullanıcısı oluştur
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
  gen_random_uuid(),  -- Bu ID'yi sonraki adımda kullan
  'authenticated',
  'authenticated',
  'yakup@test.com',
  crypt('test123456', gen_salt('bf')),  -- Şifre: test123456
  NOW(),
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
);

-- ADIM 2: Auth'dan oluşan ID'yi kopyala
-- SELECT id FROM auth.users WHERE email = 'yakup@test.com';

-- ADIM 3: Public.users tablosuna ekle (yukarıdaki INSERT ile aynı)
-- AUTH_USER_ID_BURAYA yerine kopyaladığın ID'yi yapıştır


-- ================================================================
-- KOLAY YOL: Mevcut FILE001 kullanıcısıyla test et
-- ================================================================
-- Login ekranında:
-- Sicil No: FILE001
-- Şifre: ahmet@filemarket.com için Supabase Auth'da tanımlı şifre
