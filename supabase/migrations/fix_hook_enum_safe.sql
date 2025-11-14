-- ================================================================
-- CUSTOM ACCESS TOKEN HOOK - FULL REWRITE
-- ================================================================

-- Önce eski hook'u temizle
DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb);

-- Yeni hook'u oluştur (enum handling ile)
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  user_role text;
  user_tenant_id text;
BEGIN
  -- users tablosundan bilgileri al
  -- ENUM'ı direkt text olarak al
  SELECT 
    CAST(role AS text), 
    CAST(tenant_id AS text)
  INTO STRICT user_role, user_tenant_id
  FROM public.users
  WHERE id = CAST(event->>'user_id' AS uuid);

  -- JWT claims'e ekle (text olarak)
  event := jsonb_set(event, '{claims,tenant_id}', to_jsonb(user_tenant_id));
  event := jsonb_set(event, '{claims,role}', to_jsonb(user_role));

  RETURN event;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- Kullanıcı bulunamazsa default değerler
    event := jsonb_set(event, '{claims,role}', to_jsonb('personel'));
    RETURN event;
  WHEN OTHERS THEN
    -- Diğer hatalar için de default
    event := jsonb_set(event, '{claims,role}', to_jsonb('personel'));
    RETURN event;
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;
GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated, anon, public;

COMMENT ON FUNCTION public.custom_access_token_hook IS 
'Custom access token hook - JWT''ye tenant_id ve role ekler (enum safe)';

-- ================================================================
-- Test et
-- ================================================================
-- Test için user_id gerekli, onu al:
SELECT id FROM public.users WHERE employee_code = 'FILE001';

-- Sonra test:
-- SELECT public.custom_access_token_hook('{"user_id": "USER_ID_BURAYA"}'::jsonb);
