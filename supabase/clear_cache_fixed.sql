-- ================================================================
-- CACHE TEMİZLEME (Düzeltilmiş)
-- ================================================================

-- Auth user ID'sini al
DO $$
DECLARE
    user_uuid uuid;
BEGIN
    SELECT id INTO user_uuid 
    FROM auth.users 
    WHERE email = 'ahmet@filemarket.com';
    
    -- Sessions sil
    DELETE FROM auth.sessions 
    WHERE user_id = user_uuid;
    
    -- Refresh tokens sil
    DELETE FROM auth.refresh_tokens 
    WHERE user_id = user_uuid;
    
    RAISE NOTICE 'Cache cleared for user: %', user_uuid;
END $$;

-- Role kontrol et
SELECT 
    id,
    employee_code,
    email,
    role::text as role,
    tenant_id
FROM public.users
WHERE employee_code = 'FILE001';
