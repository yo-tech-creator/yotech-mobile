-- ================================================================
-- FILE MARKET SKT KAYITLARI
-- ================================================================
-- Her şube için 10'ar adet SKT kaydı oluştur (Toplam 50 kayıt)

DO $$
DECLARE
  file_tenant_id uuid := '11111111-1111-1111-1111-111111111111';
  
  -- Arrays
  branch_ids uuid[];
  product_ids uuid[];
  user_ids_per_branch uuid[];
  
  branch_id uuid;
  product_id uuid;
  user_id uuid;
  
  -- Tarih değişkenleri
  base_date date := CURRENT_DATE;
  expiry_date date;
  
  -- Sayaçlar
  i int;
  j int;
  
BEGIN
  -- ============================================================
  -- Şube ID'lerini topla
  -- ============================================================
  SELECT ARRAY_AGG(id) INTO branch_ids
  FROM branches
  WHERE tenant_id = file_tenant_id;
  
  -- ============================================================
  -- Ürün ID'lerini topla
  -- ============================================================
  SELECT ARRAY_AGG(id) INTO product_ids
  FROM products
  WHERE tenant_id = file_tenant_id
  LIMIT 20;
  
  -- ============================================================
  -- Her şube için SKT kayıtları oluştur
  -- ============================================================
  FOREACH branch_id IN ARRAY branch_ids LOOP
    -- Bu şubedeki kullanıcıları al
    SELECT ARRAY_AGG(id) INTO user_ids_per_branch
    FROM users
    WHERE tenant_id = file_tenant_id 
    AND branch_id = branch_id
    LIMIT 3;
    
    -- Eğer şubede kullanıcı yoksa atla
    IF user_ids_per_branch IS NULL OR ARRAY_LENGTH(user_ids_per_branch, 1) = 0 THEN
      CONTINUE;
    END IF;
    
    -- 10 adet SKT kaydı oluştur
    FOR i IN 1..10 LOOP
      -- Random ürün seç
      product_id := product_ids[(i % 20) + 1];
      
      -- Random kullanıcı seç
      user_id := user_ids_per_branch[(i % ARRAY_LENGTH(user_ids_per_branch, 1)) + 1];
      
      -- Expiry date: Bazıları geçmiş, bazıları yaklaşan, bazıları normal
      CASE 
        WHEN i <= 2 THEN 
          -- Geçmiş (1-5 gün önce)
          expiry_date := base_date - ((i + 1) || ' days')::INTERVAL;
        WHEN i <= 5 THEN
          -- Yaklaşan (2-5 gün sonra)
          expiry_date := base_date + (i || ' days')::INTERVAL;
        ELSE
          -- Normal (20-60 gün sonra)
          expiry_date := base_date + ((i * 5) || ' days')::INTERVAL;
      END CASE;
      
      -- SKT kaydı oluştur
      INSERT INTO skt_records (
        tenant_id, branch_id, product_id, user_id,
        expiry_date, quantity, alarm_days_before, 
        product_status, notes
      ) VALUES (
        file_tenant_id, branch_id, product_id, user_id,
        expiry_date, 
        (RANDOM() * 50 + 1)::INT,  -- 1-50 arası miktar
        7,  -- 7 gün önce alarm
        CASE 
          WHEN i <= 2 THEN 'Fire Edildi'
          WHEN i <= 5 THEN 'Rafta'
          ELSE 'Stokta'
        END,
        CASE
          WHEN i <= 2 THEN 'Tarihi geçmiş, fire edilmiştir'
          WHEN i <= 5 THEN 'SKT yaklaşıyor, takip ediliyor'
          ELSE 'Normal stok'
        END
      );
      
    END LOOP;
    
    RAISE NOTICE 'Şube için 10 SKT kaydı oluşturuldu: %', branch_id;
  END LOOP;
  
  RAISE NOTICE '✅ Tüm şubeler için SKT kayıtları oluşturuldu!';
  
  -- Özet bilgi
  RAISE NOTICE '📊 Toplam SKT Kayıtları:';
  RAISE NOTICE 'Geçmiş (gecmis): %', (SELECT COUNT(*) FROM skt_records WHERE tenant_id = file_tenant_id AND status = 'gecmis');
  RAISE NOTICE 'Yaklaşan (yaklasan): %', (SELECT COUNT(*) FROM skt_records WHERE tenant_id = file_tenant_id AND status = 'yaklasan');
  RAISE NOTICE 'Normal: %', (SELECT COUNT(*) FROM skt_records WHERE tenant_id = file_tenant_id AND status = 'normal');
  
END $$;
