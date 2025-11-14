-- ================================================================
-- LOGIN SORUNU TAM ÇÖZÜM - HEPSİNİ BİR ARADA ÇALIŞTIR
-- ================================================================
-- Bu SQL'i Supabase Dashboard -> SQL Editor'de çalıştır

-- ================================================================
-- ADIM 1: Önce RPC fonksiyonunu oluştur (zaten varsa üzerine yazar)
-- ================================================================
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

-- Fonksiyon izinlerini ayarla
GRANT EXECUTE ON FUNCTION public.get_user_email_by_sicil(TEXT) TO authenticated, anon;

-- ================================================================
-- ADIM 2: Kullanıcının Supabase Auth'da olduğundan emin ol
-- ================================================================
-- Önce kontrol et:
SELECT 
    id,
    email,
    email_confirmed_at,
    created_at
FROM auth.users
WHERE email = 'ahmet@filemarket.com';

-- Eğer yukarıdaki sorgu boş dönerse, kullanıcı oluştur:
-- NOT: Eğer kullanıcı varsa bu INSERT hata verecek, önemli değil, devam et

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
) 
SELECT 
  '00000000-0000-0000-0000-000000000000',
  'e1392666-dcfb-497c-9361-7c735a6d9612',  -- public.users'daki id ile aynı olmalı
  'authenticated',
  'authenticated',
  'ahmet@filemarket.com',
  crypt('test123456', gen_salt('bf')),  -- Şifre: test123456
  NOW(),
  NOW(),
  NOW(),
  '',
  '',
  '',
  ''
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users WHERE email = 'ahmet@filemarket.com'
);

-- ================================================================
-- ADIM 3: Public.users tablosunda kullanıcıyı kontrol et
-- ================================================================
-- Önce kontrol et:
SELECT 
    id,
    email,
    employee_code,
    active,
    first_name,
    last_name
FROM public.users
WHERE employee_code = 'FILE001';

-- Eğer yukarıdaki sorgu boş dönerse veya id farklıysa, kullanıcıyı düzelt:
-- Önce sil (eğer varsa):
DELETE FROM public.users WHERE employee_code = 'FILE001';

-- Sonra yeniden ekle (doğru verilerle):
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
  hire_date,
  annual_leave_days,
  used_leave_days,
  active
) VALUES (
  'e1392666-dcfb-497c-9361-7c735a6d9612',  -- auth.users'daki id ile AYNI olmalı
  '11111111-1111-1111-1111-111111111111',
  '476442db-abe8-475b-9cef-fccf1e852652',
  'Ahmet',
  'Yılmaz',
  'ahmet@filemarket.com',
  '5551234567',
  'FILE001',
  'sube_muduru'::user_role,
  'Şube Müdürü',
  CURRENT_DATE,
  14,
  0,
  true  -- Boolean olarak true
);

-- ================================================================
-- ADIM 4: TEST - RPC fonksiyonunu çalıştır
-- ================================================================
SELECT * FROM get_user_email_by_sicil('FILE001');
-- Bu sorgu şunu döndürmeli:
-- email: ahmet@filemarket.com
-- active: true

-- ================================================================
-- ADIM 5: Auth user'ın raw_app_meta_data'sını kontrol et
-- ================================================================
-- custom_access_token_hook'un çalışması için gerekli
SELECT 
    id,
    email,
    raw_app_meta_data,
    raw_user_meta_data
FROM auth.users
WHERE email = 'ahmet@filemarket.com';

-- ================================================================
-- SONUÇ: Yukarıdaki tüm SQL'leri çalıştırdıktan sonra
-- Login ekranında test et:
-- Sicil No: FILE001
-- Şifre: test123456
-- ================================================================
