-- HIZLI SUPABASE ŞEMA EXPORT
-- Her sorguyu TEK TEK çalıştırın, hepsi birden değil!

-- ============================================
-- 1. TABLO LİSTESİ (Çok Hızlı)
-- ============================================
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;

-- ============================================
-- 2. USERS TABLOSU YAPISI
-- ============================================
SELECT 
  column_name,
  data_type,
  character_maximum_length,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'users'
ORDER BY ordinal_position;

-- ============================================
-- 3. FOREIGN KEYS (Sadece users tablosu için)
-- ============================================
SELECT
  tc.table_name,
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'users';

-- ============================================
-- 4. ENUM TİPLERİ
-- ============================================
SELECT 
  t.typname as enum_name,
  e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
ORDER BY t.typname, e.enumsortorder;

-- ============================================
-- 5. BASIT TABLO SAYIMLARI
-- ============================================
SELECT 
  'users' as table_name,
  COUNT(*) as row_count
FROM users

UNION ALL

SELECT 
  'tenants' as table_name,
  COUNT(*) as row_count
FROM tenants;

-- Not: Her bir sorguyu AYRI AYRI çalıştırın!
-- Hepsini birden çalıştırırsanız timeout olabilir.
