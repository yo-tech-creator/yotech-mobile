-- ============================================
-- GRAND ADMIN KULLANICI OLUŞTURMA (DÜZELTİLMİŞ)
-- ============================================
-- Test amaçlı Grand Admin hesabı
-- Login ID: yakup
-- Password: kuru22

DO $$
DECLARE
  v_admin_id UUID := gen_random_uuid();
BEGIN
  -- Önce mevcut Grand Admin varsa sil
  DELETE FROM users WHERE sicil_no = 'yakup' OR email = 'yakup@grandadmin.com';
  
  -- Grand Admin kullanıcısı oluştur
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
    'yakup', -- ✅ DÜZELTME: 'GRAND-001' yerine 'yakup'
    'Sistem Yönetimi',
    'Grand Admin',
    '1980-01-01',
    '2024-01-01',
    TRUE
  );

  RAISE NOTICE '✅ Grand Admin oluşturuldu!';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'Login Bilgileri:';
  RAISE NOTICE '  ID: yakup';
  RAISE NOTICE '  PW: kuru22';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'Email: yakup@grandadmin.com';
  RAISE NOTICE 'Rol: grand_admin';
  RAISE NOTICE 'User ID: %', v_admin_id;
  RAISE NOTICE '';
  RAISE NOTICE '✅ Artık uygulamadan giriş yapabilirsiniz!';
END $$;
