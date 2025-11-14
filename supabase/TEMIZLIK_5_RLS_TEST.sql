-- ============================================
-- RLS TESTİ - ŞUBELER BİRBİRİNİ GÖRMEMELİ!
-- ============================================

-- Bu script çalıştırılmadan önce:
-- 1-4 arası tüm temizlik script'leri çalıştırılmış olmalı

DO $$
DECLARE
  v_tenant_id UUID;
  v_branch_ids UUID[];
  v_test_user_id UUID;
  v_test_results JSON;
BEGIN
  -- Yakup Market tenant_id
  SELECT id INTO v_tenant_id 
  FROM tenants 
  WHERE firma_adi ILIKE '%yakup%market%'
  LIMIT 1;
  
  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Yakup Market tenant bulunamadı!';
  END IF;
  
  -- Tüm şubeleri al
  SELECT array_agg(id ORDER BY ad) INTO v_branch_ids
  FROM branches
  WHERE tenant_id = v_tenant_id;
  
  RAISE NOTICE 'Tenant ID: %', v_tenant_id;
  RAISE NOTICE 'Şube Sayısı: %', array_length(v_branch_ids, 1);
  RAISE NOTICE '';
  
  -- Her şube için test et
  FOR i IN 1..array_length(v_branch_ids, 1) LOOP
    -- Bu şubenin bir personelini bul
    SELECT id INTO v_test_user_id
    FROM users
    WHERE branch_id = v_branch_ids[i]
      AND rol = 'personel'
      AND aktif = true
    LIMIT 1;
    
    IF v_test_user_id IS NOT NULL THEN
      -- Bu kullanıcı olarak diğer şubeleri görebiliyor mu?
      FOR j IN 1..array_length(v_branch_ids, 1) LOOP
        IF i != j THEN
          -- SET LOCAL rol ile test
          EXECUTE format('SET LOCAL "request.jwt.claims" = ''{"sub":"%s"}''', v_test_user_id);
          
          -- Diğer şubenin SKT kayıtlarını görüyor mu?
          SELECT INTO v_test_results
            json_build_object(
              'kendi_sube', v_branch_ids[i],
              'kendi_sube_ad', (SELECT ad FROM branches WHERE id = v_branch_ids[i]),
              'diger_sube', v_branch_ids[j],
              'diger_sube_ad', (SELECT ad FROM branches WHERE id = v_branch_ids[j]),
              'gorunur_skt_kayit', (
                SELECT COUNT(*)
                FROM skt_records
                WHERE branch_id = v_branch_ids[j]
              ),
              'gorunur_personel', (
                SELECT COUNT(*)
                FROM users
                WHERE branch_id = v_branch_ids[j]
              )
            );
          
          -- Sonuçları göster
          RAISE NOTICE '%;', v_test_results::text;
          
          -- Eğer görüyorsa HATA!
          IF (v_test_results->>'gorunur_skt_kayit')::int > 0 
             OR (v_test_results->>'gorunur_personel')::int > 0 THEN
            RAISE WARNING '❌ GÜVENLİK SORUNU! % şubesi % şubesini görüyor!', 
              v_test_results->>'kendi_sube_ad',
              v_test_results->>'diger_sube_ad';
          ELSE
            RAISE NOTICE '✅ OK: % şubesi % şubesini görmüyor', 
              v_test_results->>'kendi_sube_ad',
              v_test_results->>'diger_sube_ad';
          END IF;
          
          RESET "request.jwt.claims";
        END IF;
      END LOOP;
    END IF;
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '=== TEST TAMAMLANDI ===';
  RAISE NOTICE 'Eğer hiç WARNING görünmediyse: ✅ RLS DOĞRU ÇALIŞIYOR';
  RAISE NOTICE 'Eğer WARNING gördüysen: ❌ RLS SORUNU VAR!';
END $$;
