-- ============================================
-- ESKİ RLS POLİCY'LERİ TEMİZLE
-- ============================================

-- 1. Tüm tablolar için eski policy'leri sil
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT schemaname, tablename, policyname 
    FROM pg_policies 
    WHERE schemaname = 'public'
      AND policyname NOT LIKE 'rls_%yotech'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', 
      r.policyname, r.schemaname, r.tablename);
    RAISE NOTICE 'Silindi: %.%.%', r.schemaname, r.tablename, r.policyname;
  END LOOP;
END $$;

-- 2. Kontrol et - sadece yeni policy'ler kalmalı
SELECT tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
