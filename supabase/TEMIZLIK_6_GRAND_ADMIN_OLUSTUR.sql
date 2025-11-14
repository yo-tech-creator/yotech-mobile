-- ============================================
-- GRAND ADMIN OLUŞTUR (DÜZELTİLMİŞ)
-- ============================================

-- 1. Önce Grand Admin için özel tenant oluştur
INSERT INTO tenants (
  id,
  firma_adi,
  aktif,
  created_at
)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Yotech Grand Admin',
  TRUE,
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  firma_adi = EXCLUDED.firma_adi,
  aktif = EXCLUDED.aktif;

-- 2. Grand Admin kullanıcısı oluştur
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
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000001',
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
  rol = EXCLUDED.rol,
  aktif = EXCLUDED.aktif;

-- 3. Kontrol
SELECT 
  u.sicil_no,
  u.ad,
  u.soyad,
  u.rol,
  u.email,
  u.aktif,
  t.firma_adi as tenant
FROM users u
LEFT JOIN tenants t ON t.id = u.tenant_id
WHERE u.sicil_no = 'yakup';

-- Başarılı!
-- Login: yakup / kuru22
