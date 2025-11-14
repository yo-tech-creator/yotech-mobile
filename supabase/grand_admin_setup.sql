-- ============================================
-- GRAND ADMIN KULLANICI OLUŞTURMA
-- ============================================
-- Test amaçlı Grand Admin hesabı
-- ID: yakup
-- PW: kuru22

DO $$
DECLARE
  v_admin_id UUID := gen_random_uuid();
BEGIN
  -- Grand Admin kullanıcısı oluştur
  -- NOT: Supabase auth.users tablosunda oluşturulmalı
  -- Bu SQL sadece public.users tablosuna kayıt ekler
  
  INSERT INTO users (
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
    v_admin_id,
    NULL, -- Grand admin tenant'a bağlı değil
    'grand_admin',
    'Yakup',
    'Kuru',
    'yakup@grandadmin.com',
    '+90 555 999 9999',
    'GRAND-001',
    'Sistem Yönetimi',
    'Grand Admin',
    '1980-01-01',
    '2024-01-01',
    TRUE
  );

  RAISE NOTICE '✅ Grand Admin oluşturuldu!';
  RAISE NOTICE 'ID: yakup';
  RAISE NOTICE 'PW: kuru22';
  RAISE NOTICE 'Email: yakup@grandadmin.com';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  NOT: Supabase Auth''ta bu kullanıcıyı manuel oluşturmalısınız:';
  RAISE NOTICE '1. Supabase Dashboard > Authentication > Users';
  RAISE NOTICE '2. "Add user" tıklayın';
  RAISE NOTICE '3. Email: yakup@grandadmin.com';
  RAISE NOTICE '4. Password: kuru22';
  RAISE NOTICE '5. User ID: %', v_admin_id;
  RAISE NOTICE '';
  RAISE NOTICE 'Alternatif: Uygulama içi login mantığı sicil_no + şifre ile yapılabilir';
END $$;
