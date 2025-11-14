-- ================================================================
-- ALTERNATİF ÇÖZÜM: Hook'suz Login (Basit Test)
-- ================================================================
-- Eğer hook problemi devam ederse, geçici olarak JWT'yi manuel set et

-- ADIM 1: Kullanıcıyı personel rolüne düşür (test için)
UPDATE public.users 
SET role = 'personel'::user_role
WHERE employee_code = 'FILE001';

-- ADIM 2: Test et
-- Login: FILE001 / test123456
-- Personel rolü ile giriş yapmalı

-- ================================================================
-- EĞER ÇALIŞIRSA:
-- Hook problemi var demektir. Hook'u düzelt ve sube_muduru'ye geri al
-- ================================================================

-- Hook düzeltildikten sonra rolü geri al:
-- UPDATE public.users 
-- SET role = 'sube_muduru'::user_role
-- WHERE employee_code = 'FILE001';
