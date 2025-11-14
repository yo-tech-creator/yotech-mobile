-- ================================================================
-- FILE MARKET VERİLERİNİ TEMİZLE
-- ================================================================
-- Bu script File Market'e ait tüm verileri siler

DO $$
DECLARE
  file_tenant_id uuid := '11111111-1111-1111-1111-111111111111';
BEGIN
  -- 1. SKT kayıtlarını sil
  DELETE FROM skt_records WHERE tenant_id = file_tenant_id;
  RAISE NOTICE '✅ SKT kayıtları silindi';
  
  -- 2. Kullanıcıları sil
  DELETE FROM users WHERE tenant_id = file_tenant_id;
  RAISE NOTICE '✅ Users silindi';
  
  -- 3. Auth users'ları sil (File Market emailli)
  DELETE FROM auth.users WHERE email LIKE '%@filemarket.com';
  RAISE NOTICE '✅ Auth users silindi';
  
  -- 4. Ürünleri sil
  DELETE FROM products WHERE tenant_id = file_tenant_id;
  RAISE NOTICE '✅ Ürünler silindi';
  
  -- 5. Şubeleri sil
  DELETE FROM branches WHERE tenant_id = file_tenant_id;
  RAISE NOTICE '✅ Şubeler silindi';
  
  -- 6. Bölgeyi sil
  DELETE FROM regions WHERE tenant_id = file_tenant_id;
  RAISE NOTICE '✅ Bölge silindi';
  
  RAISE NOTICE '🎉 File Market verileri tamamen temizlendi!';
END $$;
