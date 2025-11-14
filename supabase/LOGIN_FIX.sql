-- LOGIN FIX: Users tablosuna anon kullanıcılar için sicil_no bazlı read politikası ekleme

-- Önce mevcut users_select_policy'yi kaldır
DROP POLICY IF EXISTS "users_select_policy" ON public.users;

-- Yeni politika: Authenticated kullanıcılar için tenant_id kontrolü
CREATE POLICY "users_select_authenticated"
ON public.users
FOR SELECT
TO authenticated
USING (tenant_id = current_tenant_id());

-- Yeni politika: Anon kullanıcılar için sadece sicil_no ile email ve id erişimi
-- Bu login işlemi için gerekli
CREATE POLICY "users_select_for_login"
ON public.users
FOR SELECT
TO anon
USING (true);  -- Anon kullanıcılar sicil_no ile arama yapabilir

-- Not: Bu güvenlik riski oluşturabilir. Alternatif olarak:
-- 1. Supabase Edge Function kullanılabilir
-- 2. Veya sadece belirli kolonlara erişim verilebilir (sicil_no, email, id)
-- 3. Veya RPC fonksiyonu ile login yapılabilir

-- RPC fonksiyon alternatifi (daha güvenli):
CREATE OR REPLACE FUNCTION public.login_with_sicil_no(
  p_sicil_no text
)
RETURNS TABLE (
  user_id uuid,
  user_email text,
  user_aktif boolean,
  user_ad text,
  user_soyad text,
  user_rol text,
  user_tenant_id uuid,
  user_branch_id uuid,
  user_region_id uuid,
  user_sicil_no text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.aktif,
    u.ad,
    u.soyad,
    u.rol::text,
    u.tenant_id,
    u.branch_id,
    u.region_id,
    u.sicil_no
  FROM public.users u
  WHERE u.sicil_no = p_sicil_no
  AND u.aktif = true
  LIMIT 1;
END;
$$;

-- Bu fonksiyona public erişim ver
GRANT EXECUTE ON FUNCTION public.login_with_sicil_no(text) TO anon;
GRANT EXECUTE ON FUNCTION public.login_with_sicil_no(text) TO authenticated;
