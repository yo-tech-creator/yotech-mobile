-- ================================================================
-- FILE MARKET - TEK SEFERDE TÜM VERİLER
-- ================================================================
-- Bu tek script ile tüm test verileri oluşturulur
-- Bölge, Şube, Ürün, Kullanıcı, SKT Kayıtları

DO $$
DECLARE
  file_tenant_id uuid := '11111111-1111-1111-1111-111111111111';
  marmara_region_id uuid;
  
  -- Branch IDs
  istanbul_anadolu_id uuid;
  istanbul_avrupa_id uuid;
  bursa_id uuid;
  izmit_id uuid;
  sakarya_id uuid;
  
  -- User IDs
  user_id uuid;
  counter int := 1;
  
  -- SKT için
  branch_ids uuid[];
  product_ids uuid[];
  user_ids_per_branch uuid[];
  v_branch_id uuid;
  v_product_id uuid;
  v_user_id uuid;
  base_date date := CURRENT_DATE;
  expiry_date date;
  i int;
  
BEGIN
  -- ============================================================
  -- ADIM 0: TEMİZLİK
  -- ============================================================
  DELETE FROM skt_records WHERE tenant_id = file_tenant_id;
  DELETE FROM users WHERE tenant_id = file_tenant_id;
  DELETE FROM auth.users WHERE email LIKE '%@filemarket.com';
  DELETE FROM products WHERE tenant_id = file_tenant_id;
  DELETE FROM branches WHERE tenant_id = file_tenant_id;
  DELETE FROM regions WHERE tenant_id = file_tenant_id;
  
  RAISE NOTICE '🧹 Eski veriler temizlendi';

  -- ============================================================
  -- ADIM 1: BÖLGE
  -- ============================================================
  marmara_region_id := gen_random_uuid();
  
  INSERT INTO public.regions (id, tenant_id, name, code, active)
  VALUES (marmara_region_id, file_tenant_id, 'Marmara Bölgesi', 'MAR', true);
  
  RAISE NOTICE '✅ Bölge oluşturuldu';

  -- ============================================================
  -- ADIM 2: ŞUBELER
  -- ============================================================
  istanbul_anadolu_id := gen_random_uuid();
  istanbul_avrupa_id := gen_random_uuid();
  bursa_id := gen_random_uuid();
  izmit_id := gen_random_uuid();
  sakarya_id := gen_random_uuid();
  
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
  
  RAISE NOTICE '✅ 5 Şube oluşturuldu';

  -- ============================================================
  -- ADIM 3: ÜRÜNLER
  -- ============================================================
  INSERT INTO public.products (
    tenant_id, barcode, name, category, brand, 
    supplier, price, active
  ) VALUES
    (file_tenant_id, '8690504001011', 'Süt 1L', 'Süt Ürünleri', 'Pınar', 'Pınar Süt', 25.50, true),
    (file_tenant_id, '8690504002012', 'Beyaz Peynir 500g', 'Süt Ürünleri', 'Pınar', 'Pınar Süt', 85.00, true),
    (file_tenant_id, '8690504003013', 'Kaşar Peynir 350g', 'Süt Ürünleri', 'Pınar', 'Pınar Süt', 95.00, true),
    (file_tenant_id, '8690504004014', 'Yoğurt 500g', 'Süt Ürünleri', 'Danone', 'Danone Türkiye', 18.50, true),
    (file_tenant_id, '8690601001015', 'Tavuk Göğüs 1kg', 'Et Ürünleri', 'Banvit', 'Banvit A.Ş.', 120.00, true),
    (file_tenant_id, '8690601002016', 'Dana Kıyma 500g', 'Et Ürünleri', 'Namet', 'Namet Gıda', 180.00, true),
    (file_tenant_id, '8690601003017', 'Sosis 250g', 'Et Ürünleri', 'Pınar', 'Pınar Et', 45.00, true),
    (file_tenant_id, '2000000001018', 'Domates 1kg', 'Sebze', 'Taze', 'Yerel Üretici', 15.00, true),
    (file_tenant_id, '2000000002019', 'Salatalık 1kg', 'Sebze', 'Taze', 'Yerel Üretici', 12.00, true),
    (file_tenant_id, '2000000003020', 'Elma 1kg', 'Meyve', 'Taze', 'Yerel Üretici', 25.00, true),
    (file_tenant_id, '8690635001021', 'Ekmek 400g', 'Fırın', 'Uno', 'Uno Ekmek', 8.00, true),
    (file_tenant_id, '8690635002022', 'Makarna 500g', 'Temel Gıda', 'Tat', 'Tat Gıda', 12.50, true),
    (file_tenant_id, '8690635003023', 'Pirinç 1kg', 'Temel Gıda', 'Baldo', 'Trakya Birlik', 28.00, true),
    (file_tenant_id, '8690635004024', 'Şeker 1kg', 'Temel Gıda', 'Türk Şeker', 'Türkşeker', 22.00, true),
    (file_tenant_id, '8690500001025', 'Kola 1L', 'İçecek', 'Coca Cola', 'Coca Cola İçecek', 18.00, true),
    (file_tenant_id, '8690500002026', 'Ayran 1L', 'İçecek', 'Pınar', 'Pınar Süt', 15.00, true),
    (file_tenant_id, '8690500003027', 'Su 1.5L', 'İçecek', 'Hayat', 'Hayat Su', 5.00, true),
    (file_tenant_id, '8690700001028', 'Deterjan 3kg', 'Temizlik', 'Ariel', 'P&G', 120.00, true),
    (file_tenant_id, '8690700002029', 'Sabun 4lü', 'Temizlik', 'Duru', 'Evyap', 35.00, true),
    (file_tenant_id, '8690700003030', 'Kağıt Havlu 12li', 'Temizlik', 'Solo', 'Olin', 85.00, true);

  RAISE NOTICE '✅ 20 Ürün oluşturuldu';

  -- ============================================================
  -- ADIM 4: KULLANICILAR
  -- ============================================================
  
  -- Firma Admin
  user_id := gen_random_uuid();
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', user_id,
    'authenticated', 'authenticated', 'fileadmin@filemarket.com',
    crypt('test123456', gen_salt('bf')),
    NOW(), NOW(), NOW(), '', '', '', ''
  );
  
  INSERT INTO public.users (
    id, tenant_id, first_name, last_name, email, phone,
    employee_code, role, position, hire_date, active
  ) VALUES (
    user_id, file_tenant_id, 'Ahmet', 'Yıldırım', 'fileadmin@filemarket.com', 
    '5551234501', 'FILEADM001', 'firma_admin', 'Genel Müdür', '2020-01-15', true
  );
  
  -- Bölge Müdürü
  user_id := gen_random_uuid();
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000', user_id,
    'authenticated', 'authenticated', 'bolgemuduru@filemarket.com',
    crypt('test123456', gen_salt('bf')),
    NOW(), NOW(), NOW(), '', '', '', ''
  );
  
  INSERT INTO public.users (
    id, tenant_id, first_name, last_name, email, phone,
    employee_code, role, position, hire_date, active
  ) VALUES (
    user_id, file_tenant_id, 'Mehmet', 'Kara', 'bolgemuduru@filemarket.com',
    '5551234502', 'FILEBM001', 'bolge_muduru', 'Marmara Bölge Müdürü', '2020-03-01', true
  );
  
  UPDATE regions SET manager_id = user_id WHERE id = marmara_region_id;
  
  -- Şube Müdürleri (15 kişi)
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
    VALUES ('00000000-0000-0000-0000-000000000000', user_id, 'authenticated', 'authenticated', 'istan' || i || '@filemarket.com', crypt('test123456', gen_salt('bf')), NOW(), NOW(), NOW(), '', '', '', '');
    INSERT INTO public.users (id, tenant_id, branch_id, first_name, last_name, email, phone, employee_code, role, position, hire_date, active)
    VALUES (user_id, file_tenant_id, istanbul_anadolu_id, 'Personel', 'İst Anadolu ' || i, 'istan' || i || '@filemarket.com', '555123' || LPAD((4502 + counter)::text, 4, '0'), 'ISTAN' || LPAD(i::text, 3, '0'), 'sube_muduru', 'Mağaza Sorumlusu', '2021-06-01', true);
    counter := counter + 1;
  END LOOP;
  
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
    VALUES ('00000000-0000-0000-0000-000000000000', user_id, 'authenticated', 'authenticated', 'istav' || i || '@filemarket.com', crypt('test123456', gen_salt('bf')), NOW(), NOW(), NOW(), '', '', '', '');
    INSERT INTO public.users (id, tenant_id, branch_id, first_name, last_name, email, phone, employee_code, role, position, hire_date, active)
    VALUES (user_id, file_tenant_id, istanbul_avrupa_id, 'Personel', 'İst Avrupa ' || i, 'istav' || i || '@filemarket.com', '555123' || LPAD((4502 + counter)::text, 4, '0'), 'ISTAV' || LPAD(i::text, 3, '0'), 'sube_muduru', 'Mağaza Sorumlusu', '2021-06-01', true);
    counter := counter + 1;
  END LOOP;
  
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
    VALUES ('00000000-0000-0000-0000-000000000000', user_id, 'authenticated', 'authenticated', 'bursa' || i || '@filemarket.com', crypt('test123456', gen_salt('bf')), NOW(), NOW(), NOW(), '', '', '', '');
    INSERT INTO public.users (id, tenant_id, branch_id, first_name, last_name, email, phone, employee_code, role, position, hire_date, active)
    VALUES (user_id, file_tenant_id, bursa_id, 'Personel', 'Bursa ' || i, 'bursa' || i || '@filemarket.com', '555123' || LPAD((4502 + counter)::text, 4, '0'), 'BURSA' || LPAD(i::text, 3, '0'), 'sube_muduru', 'Mağaza Sorumlusu', '2021-06-01', true);
    counter := counter + 1;
  END LOOP;
  
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
    VALUES ('00000000-0000-0000-0000-000000000000', user_id, 'authenticated', 'authenticated', 'izmit' || i || '@filemarket.com', crypt('test123456', gen_salt('bf')), NOW(), NOW(), NOW(), '', '', '', '');
    INSERT INTO public.users (id, tenant_id, branch_id, first_name, last_name, email, phone, employee_code, role, position, hire_date, active)
    VALUES (user_id, file_tenant_id, izmit_id, 'Personel', 'İzmit ' || i, 'izmit' || i || '@filemarket.com', '555123' || LPAD((4502 + counter)::text, 4, '0'), 'IZMIT' || LPAD(i::text, 3, '0'), 'sube_muduru', 'Mağaza Sorumlusu', '2021-06-01', true);
    counter := counter + 1;
  END LOOP;
  
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, email_change, email_change_token_new, recovery_token)
    VALUES ('00000000-0000-0000-0000-000000000000', user_id, 'authenticated', 'authenticated', 'sakarya' || i || '@filemarket.com', crypt('test123456', gen_salt('bf')), NOW(), NOW(), NOW(), '', '', '', '');
    INSERT INTO public.users (id, tenant_id, branch_id, first_name, last_name, email, phone, employee_code, role, position, hire_date, active)
    VALUES (user_id, file_tenant_id, sakarya_id, 'Personel', 'Sakarya ' || i, 'sakarya' || i || '@filemarket.com', '555123' || LPAD((4502 + counter)::text, 4, '0'), 'SAKAR' || LPAD(i::text, 3, '0'), 'sube_muduru', 'Mağaza Sorumlusu', '2021-06-01', true);
    counter := counter + 1;
  END LOOP;

  RAISE NOTICE '✅ 17 Kullanıcı oluşturuldu';

  -- ============================================================
  -- ADIM 5: SKT KAYITLARI
  -- ============================================================
  SELECT ARRAY_AGG(id) INTO branch_ids FROM branches WHERE tenant_id = file_tenant_id;
  SELECT ARRAY_AGG(id) INTO product_ids FROM products WHERE tenant_id = file_tenant_id LIMIT 20;
  
  FOREACH v_branch_id IN ARRAY branch_ids LOOP
    SELECT ARRAY_AGG(u.id) INTO user_ids_per_branch
    FROM users u WHERE u.tenant_id = file_tenant_id AND u.branch_id = v_branch_id LIMIT 3;
    
    IF user_ids_per_branch IS NULL OR ARRAY_LENGTH(user_ids_per_branch, 1) = 0 THEN
      CONTINUE;
    END IF;
    
    FOR i IN 1..10 LOOP
      v_product_id := product_ids[(i % ARRAY_LENGTH(product_ids, 1)) + 1];
      v_user_id := user_ids_per_branch[(i % ARRAY_LENGTH(user_ids_per_branch, 1)) + 1];
      
      CASE 
        WHEN i <= 2 THEN expiry_date := base_date - ((i + 1) || ' days')::INTERVAL;
        WHEN i <= 5 THEN expiry_date := base_date + (i || ' days')::INTERVAL;
        ELSE expiry_date := base_date + ((i * 5) || ' days')::INTERVAL;
      END CASE;
      
      INSERT INTO skt_records (tenant_id, branch_id, product_id, user_id, expiry_date, quantity, alarm_days_before, product_status, notes)
      VALUES (
        file_tenant_id, v_branch_id, v_product_id, v_user_id, expiry_date, 
        (RANDOM() * 50 + 1)::INT, 7,
        CASE WHEN i <= 2 THEN 'Fire Edildi' WHEN i <= 5 THEN 'Rafta' ELSE 'Stokta' END,
        CASE WHEN i <= 2 THEN 'Tarihi geçmiş, fire edilmiştir' WHEN i <= 5 THEN 'SKT yaklaşıyor, takip ediliyor' ELSE 'Normal stok' END
      );
    END LOOP;
  END LOOP;

  RAISE NOTICE '✅ 50 SKT kaydı oluşturuldu';
  
  -- ============================================================
  -- ÖZET
  -- ============================================================
  RAISE NOTICE '';
  RAISE NOTICE '🎉 TÜM VERİLER OLUŞTURULDU!';
  RAISE NOTICE '';
  RAISE NOTICE '📊 ÖZET:';
  RAISE NOTICE 'Bölge: 1, Şube: 5, Ürün: 20, Kullanıcı: 17, SKT: 50';
  RAISE NOTICE '';
  RAISE NOTICE '🔑 Test Kullanıcıları (Şifre: test123456):';
  RAISE NOTICE 'FILEADM001 - Firma Admin';
  RAISE NOTICE 'FILEBM001 - Bölge Müdürü';
  RAISE NOTICE 'ISTAN001-003, ISTAV001-003, BURSA001-003, IZMIT001-003, SAKAR001-003';
  RAISE NOTICE '';
  RAISE NOTICE '📱 Flutter: flutter run';
  RAISE NOTICE '🔐 Login: FILEADM001 / test123456';
  
END $$;
