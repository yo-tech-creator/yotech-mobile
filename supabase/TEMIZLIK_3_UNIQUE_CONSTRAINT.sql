-- ============================================
-- BRANCHES UNIQUE CONSTRAINT EKLE
-- ============================================

-- 1. Mevcut duplicate kod'ları kontrol et
SELECT kod, COUNT(*) as adet
FROM branches
GROUP BY kod
HAVING COUNT(*) > 1;

-- 2. Eğer duplicate varsa temizle (önce duplikeleri elle düzelt!)
-- Burada duplicate yoksa direkt unique constraint ekleyebiliriz

-- 3. UNIQUE constraint ekle
ALTER TABLE branches
ADD CONSTRAINT branches_kod_unique UNIQUE (kod);

-- 4. Kontrol et
SELECT constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'branches'
  AND constraint_type = 'UNIQUE';
