-- ============================================
-- GRAND ADMIN OLUŞTURMA - DOĞRU VERSİYON
-- ============================================
-- Bu script hem auth.users hem de public.users'a ekler
-- tenant_id problemi çözülmüş

DO $$
DECLARE
  v_grand_tenant_id UUID := '00000000-0000-0000-0000-000000000001';
  v_admin_id UUID := gen_random_uuid();
BEGIN
  -- 1) Grand Admin için özel tenant oluştur
  INSERT INTO public.tenants (
    id,
    firma_adi,
    aktif
  )
  VALUES (
    v_grand_tenant_id,
    'Yotech Grand Admin',
    TRUE
  )
  ON CONFLICT (id) DO NOTHING;

  -- 2) auth.users'a gerçek Supabase kullanıcısı oluştur
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_admin_id,
    'authenticated',
    'authenticated',
    'yakup@grandadmin.com',
    crypt('kuru22', gen_salt('bf')),
    NOW(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password;

  -- 3) public.users'a profil oluştur (AYNI UUID)
  INSERT INTO public.users (
    id,
    tenant_id,
    rol,
    ad,
    soyad,
    email,
    telefon,
    sicil_no,
    bolum,
    pozisyon,
    dogum_tarihi,
    ise_giris_tarihi,
    aktif
  )
  VALUES (
    v_admin_id,  -- AYNI UUID!
    v_grand_tenant_id,
    'grand_admin',
    'Yakup',
    'Kuru',
    'yakup@grandadmin.com',
    '+90 555 999 9999',
    'yakup',
    'Sistem Yönetimi',
    'Grand Admin',
    '1980-01-01',
    '2024-01-01',
    TRUE
  )
  ON CONFLICT (email) DO UPDATE SET
    tenant_id = EXCLUDED.tenant_id,
    sicil_no = EXCLUDED.sicil_no,
    rol = EXCLUDED.rol;

  -- 4) Kontrol et
  RAISE NOTICE '✅ Grand Admin başarıyla oluşturuldu!';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'Login Bilgileri:';
  RAISE NOTICE '  ID: yakup';
  RAISE NOTICE '  PW: kuru22';
  RAISE NOTICE '  Email: yakup@grandadmin.com';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'UUID: %', v_admin_id;
  RAISE NOTICE 'Tenant: Yotech Grand Admin';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Artık Flutter uygulamasından giriş yapabilirsiniz!';

END $$;

-- Doğrulama sorgusu
SELECT 
  u.sicil_no,
  u.ad,
  u.soyad,
  u.rol,
  u.email,
  t.firma_adi as tenant,
  au.email as auth_email
FROM public.users u
LEFT JOIN public.tenants t ON t.id = u.tenant_id
LEFT JOIN auth.users au ON au.id = u.id
WHERE u.sicil_no = 'yakup';
