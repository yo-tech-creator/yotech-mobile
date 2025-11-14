-- ================================================================
-- DEBUG: RPC Fonksiyonu ve Kullanıcı Kontrolü
-- ================================================================

-- 1. RPC fonksiyonu var mı kontrol et
SELECT 
    proname as function_name,
    pg_get_function_identity_arguments(oid) as arguments
FROM pg_proc 
WHERE proname = 'get_user_email_by_sicil';

-- 2. Users tablosunda FILE001 var mı kontrol et
SELECT 
    id,
    email,
    employee_code,
    active,
    first_name,
    last_name
FROM public.users
WHERE employee_code = 'FILE001';

-- 3. Manuel RPC test et
SELECT * FROM get_user_email_by_sicil('FILE001');

-- ================================================================
-- SONUÇLAR:
-- Eğer 1. sorgu boş dönerse: RPC fonksiyonu yok, oluştur
-- Eğer 2. sorgu boş dönerse: Kullanıcı yok, ekle  
-- Eğer 3. sorgu boş dönerse: RLS problemi var
-- ================================================================
