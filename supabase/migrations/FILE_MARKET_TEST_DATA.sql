-- ================================================================
-- FILE MARKET TEST DATA
-- ================================================================
-- Bu script File Market firması için test verileri oluşturur:
-- 1 Bölge, 5 Şube, 17 Personel, 20 Ürün, SKT Kayıtları

DO $$
DECLARE
  file_tenant_id uuid := '11111111-1111-1111-1111-111111111111';
  marmara_region_id uuid := gen_random_uuid();
  
  -- Branch IDs
  istanbul_anadolu_id uuid := gen_random_uuid();
  istanbul_avrupa_id uuid := gen_random_uuid();
  bursa_id uuid := gen_random_uuid();
  izmit_id uuid := gen_random_uuid();
  sakarya_id uuid := gen_random_uuid();
  
  -- User IDs (auth.users'dan manuel oluşturulacak)
  firma_admin_id uuid;
  bolge_muduru_id uuid;
BEGIN

  -- ============================================================
  -- 1. REGION (Bölge Sorumlusu)
  -- ============================================================
  INSERT INTO public.regions (id, tenant_id, name, code, active)
  VALUES (marmara_region_id, file_tenant_id, 'Marmara Bölgesi', 'MAR', true);

  -- ============================================================
  -- 2. BRANCHES (5 Şube)
  -- ============================================================
  INSERT INTO public.branches (
    id, tenant_id, region_id, name, code, address, 
    latitude, longitude, active
  ) VALUES
    (istanbul_anadolu_id, file_tenant_id, marmara_region_id, 
     'İstanbul Anadolu', 'IST-AN', 'Kadıköy, İstanbul', 
     40.9905, 29.0265, true),
    
    (istanbul_avrupa_id, file_tenant_id, marmara_region_id,
     'İstanbul Avrupa', 'IST-AV', 'Beşiktaş, İstanbul',
     41.0422, 29.0089, true),
    
    (bursa_id, file_tenant_id, marmara_region_id,
     'Bursa Merkez', 'BRS-MK', 'Osmangazi, Bursa',
     40.1826, 29.0665, true),
    
    (izmit_id, file_tenant_id, marmara_region_id,
     'İzmit', 'IZM-MK', 'İzmit Merkez, Kocaeli',
     40.7658, 29.9400, true),
    
    (sakarya_id, file_tenant_id, marmara_region_id,
     'Sakarya', 'SAK-MK', 'Adapazarı, Sakarya',
     40.7833, 30.4000, true);

  -- ============================================================
  -- 3. PRODUCTS (20 Ürün)
  -- ============================================================
  INSERT INTO public.products (
    tenant_id, barcode, name, category, brand, 
    supplier, unit_price, active
  ) VALUES
    -- Süt Ürünleri
    (file_tenant_id, '8690504001011', 'Süt 1L', 'Süt Ürünleri', 'Pınar', 'Pınar Süt', 25.50, true),
    (file_tenant_id, '8690504002012', 'Beyaz Peynir 500g', 'Süt Ürünleri', 'Pınar', 'Pınar Süt', 85.00, true),
    (file_tenant_id, '8690504003013', 'Kaşar Peynir 350g', 'Süt Ürünleri', 'Pınar', 'Pınar Süt', 95.00, true),
    (file_tenant_id, '8690504004014', 'Yoğurt 500g', 'Süt Ürünleri', 'Danone', 'Danone Türkiye', 18.50, true),
    
    -- Et Ürünleri
    (file_tenant_id, '8690601001015', 'Tavuk Göğüs 1kg', 'Et Ürünleri', 'Banvit', 'Banvit A.Ş.', 120.00, true),
    (file_tenant_id, '8690601002016', 'Dana Kıyma 500g', 'Et Ürünleri', 'Namet', 'Namet Gıda', 180.00, true),
    (file_tenant_id, '8690601003017', 'Sosis 250g', 'Et Ürünleri', 'Pınar', 'Pınar Et', 45.00, true),
    
    -- Sebze/Meyve
    (file_tenant_id, '2000000001018', 'Domates 1kg', 'Sebze', 'Taze', 'Yerel Üretici', 15.00, true),
    (file_tenant_id, '2000000002019', 'Salatalık 1kg', 'Sebze', 'Taze', 'Yerel Üretici', 12.00, true),
    (file_tenant_id, '2000000003020', 'Elma 1kg', 'Meyve', 'Taze', 'Yerel Üretici', 25.00, true),
    
    -- Temel Gıda
    (file_tenant_id, '8690635001021', 'Ekmek 400g', 'Fırın', 'Uno', 'Uno Ekmek', 8.00, true),
    (file_tenant_id, '8690635002022', 'Makarna 500g', 'Temel Gıda', 'Tat', 'Tat Gıda', 12.50, true),
    (file_tenant_id, '8690635003023', 'Pirinç 1kg', 'Temel Gıda', 'Baldo', 'Trakya Birlik', 28.00, true),
    (file_tenant_id, '8690635004024', 'Şeker 1kg', 'Temel Gıda', 'Türk Şeker', 'Türkşeker', 22.00, true),
    
    -- İçecekler
    (file_tenant_id, '8690500001025', 'Kola 1L', 'İçecek', 'Coca Cola', 'Coca Cola İçecek', 18.00, true),
    (file_tenant_id, '8690500002026', 'Ayran 1L', 'İçecek', 'Pınar', 'Pınar Süt', 15.00, true),
    (file_tenant_id, '8690500003027', 'Su 1.5L', 'İçecek', 'Hayat', 'Hayat Su', 5.00, true),
    
    -- Temizlik
    (file_tenant_id, '8690700001028', 'Deterjan 3kg', 'Temizlik', 'Ariel', 'P&G', 120.00, true),
    (file_tenant_id, '8690700002029', 'Sabun 4lü', 'Temizlik', 'Duru', 'Evyap', 35.00, true),
    (file_tenant_id, '8690700003030', 'Kağıt Havlu 12li', 'Temizlik', 'Solo', 'Olin', 85.00, true);

  RAISE NOTICE 'Bölge, şubeler ve ürünler oluşturuldu!';
  RAISE NOTICE 'Şimdi kullanıcıları Supabase Dashboard''dan oluştur:';
  RAISE NOTICE '1. Firma Admin: fileadmin@filemarket.com / test123456';
  RAISE NOTICE '2. Bölge Müdürü: bolgemuduru@filemarket.com / test123456';
  RAISE NOTICE '3-17. Şube Müdürleri için toplu oluşturma gerekli';
  RAISE NOTICE 'User ID''leri kopyalayıp sonraki script''te kullan!';

END $$;

-- ================================================================
-- NOT: Auth kullanıcıları Dashboard''dan oluştur, sonra aşağıdaki
-- script ile public.users tablosuna ekle
-- ================================================================
