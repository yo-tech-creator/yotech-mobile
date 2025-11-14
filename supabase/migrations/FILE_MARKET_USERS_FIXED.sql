-- ================================================================
-- FILE MARKET USERS (FIXED) - 17 Personel
-- ================================================================
-- Bu script File Market için 17 kullanıcı oluşturur

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
  
  -- User ID
  user_id uuid;
  counter int := 1;
  
BEGIN
  -- ============================================================
  -- 0. ÖNCELİKLE ŞUBE ID'LERİNİ KONTROL ET
  -- ============================================================
  SELECT id INTO marmara_region_id FROM regions 
  WHERE tenant_id = file_tenant_id AND code = 'MAR';
  
  IF marmara_region_id IS NULL THEN
    RAISE EXCEPTION 'Marmara bölgesi bulunamadı! Önce FILE_MARKET_TEST_DATA_FIXED.sql çalıştırın.';
  END IF;
  
  SELECT id INTO istanbul_anadolu_id FROM branches 
  WHERE tenant_id = file_tenant_id AND code = 'IST-AN';
  
  SELECT id INTO istanbul_avrupa_id FROM branches 
  WHERE tenant_id = file_tenant_id AND code = 'IST-AV';
  
  SELECT id INTO bursa_id FROM branches 
  WHERE tenant_id = file_tenant_id AND code = 'BRS-MK';
  
  SELECT id INTO izmit_id FROM branches 
  WHERE tenant_id = file_tenant_id AND code = 'IZM-MK';
  
  SELECT id INTO sakarya_id FROM branches 
  WHERE tenant_id = file_tenant_id AND code = 'SAK-MK';
  
  IF istanbul_anadolu_id IS NULL OR istanbul_avrupa_id IS NULL THEN
    RAISE EXCEPTION 'Şubeler bulunamadı! Önce FILE_MARKET_TEST_DATA_FIXED.sql çalıştırın.';
  END IF;

  -- ============================================================
  -- 1. FIRMA ADMIN
  -- ============================================================
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
    '5551234501', 'FILEADM001', 'firma_admin', 'Genel Müdür', 
    '2020-01-15', true
  );
  
  RAISE NOTICE '✅ Firma Admin: fileadmin@filemarket.com (FILEADM001)';

  -- ============================================================
  -- 2. BÖLGE MÜDÜRÜ
  -- ============================================================
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
    '5551234502', 'FILEBM001', 'bolge_muduru', 'Marmara Bölge Müdürü',
    '2020-03-01', true
  );
  
  -- Bölge müdürünü region'a ata
  UPDATE regions SET manager_id = user_id 
  WHERE id = marmara_region_id;
  
  RAISE NOTICE '✅ Bölge Müdürü: bolgemuduru@filemarket.com (FILEBM001)';

  -- ============================================================
  -- 3. ŞUBE MÜDÜRLERİ (15 kişi - her şubede 3'er)
  -- ============================================================
  
  -- İstanbul Anadolu (3 müdür)
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', user_id,
      'authenticated', 'authenticated', 
      'istan' || i || '@filemarket.com',
      crypt('test123456', gen_salt('bf')),
      NOW(), NOW(), NOW(), '', '', '', ''
    );
    
    INSERT INTO public.users (
      id, tenant_id, branch_id, first_name, last_name, 
      email, phone, employee_code, role, position, hire_date, active
    ) VALUES (
      user_id, file_tenant_id, istanbul_anadolu_id,
      'Personel', 'İst Anadolu ' || i,
      'istan' || i || '@filemarket.com',
      '555123' || LPAD((4502 + counter)::text, 4, '0'),
      'ISTAN' || LPAD(i::text, 3, '0'),
      'sube_muduru', 'Mağaza Sorumlusu',
      '2021-06-01', true
    );
    
    counter := counter + 1;
  END LOOP;
  
  RAISE NOTICE '✅ İstanbul Anadolu: 3 şube müdürü (ISTAN001-003)';

  -- İstanbul Avrupa (3 müdür)
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', user_id,
      'authenticated', 'authenticated',
      'istav' || i || '@filemarket.com',
      crypt('test123456', gen_salt('bf')),
      NOW(), NOW(), NOW(), '', '', '', ''
    );
    
    INSERT INTO public.users (
      id, tenant_id, branch_id, first_name, last_name,
      email, phone, employee_code, role, position, hire_date, active
    ) VALUES (
      user_id, file_tenant_id, istanbul_avrupa_id,
      'Personel', 'İst Avrupa ' || i,
      'istav' || i || '@filemarket.com',
      '555123' || LPAD((4502 + counter)::text, 4, '0'),
      'ISTAV' || LPAD(i::text, 3, '0'),
      'sube_muduru', 'Mağaza Sorumlusu',
      '2021-06-01', true
    );
    
    counter := counter + 1;
  END LOOP;
  
  RAISE NOTICE '✅ İstanbul Avrupa: 3 şube müdürü (ISTAV001-003)';

  -- Bursa (3 müdür)
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', user_id,
      'authenticated', 'authenticated',
      'bursa' || i || '@filemarket.com',
      crypt('test123456', gen_salt('bf')),
      NOW(), NOW(), NOW(), '', '', '', ''
    );
    
    INSERT INTO public.users (
      id, tenant_id, branch_id, first_name, last_name,
      email, phone, employee_code, role, position, hire_date, active
    ) VALUES (
      user_id, file_tenant_id, bursa_id,
      'Personel', 'Bursa ' || i,
      'bursa' || i || '@filemarket.com',
      '555123' || LPAD((4502 + counter)::text, 4, '0'),
      'BURSA' || LPAD(i::text, 3, '0'),
      'sube_muduru', 'Mağaza Sorumlusu',
      '2021-06-01', true
    );
    
    counter := counter + 1;
  END LOOP;
  
  RAISE NOTICE '✅ Bursa: 3 şube müdürü (BURSA001-003)';

  -- İzmit (3 müdür)
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', user_id,
      'authenticated', 'authenticated',
      'izmit' || i || '@filemarket.com',
      crypt('test123456', gen_salt('bf')),
      NOW(), NOW(), NOW(), '', '', '', ''
    );
    
    INSERT INTO public.users (
      id, tenant_id, branch_id, first_name, last_name,
      email, phone, employee_code, role, position, hire_date, active
    ) VALUES (
      user_id, file_tenant_id, izmit_id,
      'Personel', 'İzmit ' || i,
      'izmit' || i || '@filemarket.com',
      '555123' || LPAD((4502 + counter)::text, 4, '0'),
      'IZMIT' || LPAD(i::text, 3, '0'),
      'sube_muduru', 'Mağaza Sorumlusu',
      '2021-06-01', true
    );
    
    counter := counter + 1;
  END LOOP;
  
  RAISE NOTICE '✅ İzmit: 3 şube müdürü (IZMIT001-003)';

  -- Sakarya (3 müdür)
  FOR i IN 1..3 LOOP
    user_id := gen_random_uuid();
    
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', user_id,
      'authenticated', 'authenticated',
      'sakarya' || i || '@filemarket.com',
      crypt('test123456', gen_salt('bf')),
      NOW(), NOW(), NOW(), '', '', '', ''
    );
    
    INSERT INTO public.users (
      id, tenant_id, branch_id, first_name, last_name,
      email, phone, employee_code, role, position, hire_date, active
    ) VALUES (
      user_id, file_tenant_id, sakarya_id,
      'Personel', 'Sakarya ' || i,
      'sakarya' || i || '@filemarket.com',
      '555123' || LPAD((4502 + counter)::text, 4, '0'),
      'SAKAR' || LPAD(i::text, 3, '0'),
      'sube_muduru', 'Mağaza Sorumlusu',
      '2021-06-01', true
    );
    
    counter := counter + 1;
  END LOOP;
  
  RAISE NOTICE '✅ Sakarya: 3 şube müdürü (SAKAR001-003)';

  RAISE NOTICE '';
  RAISE NOTICE '🎉 17 kullanıcı başarıyla oluşturuldu!';
  RAISE NOTICE '🔑 Tüm şifreler: test123456';
  RAISE NOTICE '';
  RAISE NOTICE '📌 SONRAKİ ADIM:';
  RAISE NOTICE 'Şimdi FILE_MARKET_SKT_RECORDS_FIXED.sql dosyasını çalıştırın';

END $$;
