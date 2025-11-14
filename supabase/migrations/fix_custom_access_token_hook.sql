-- ================================================================
-- CUSTOM ACCESS TOKEN HOOK FIX
-- ================================================================
-- Enum cast problemini düzelt

DROP FUNCTION IF EXISTS public.custom_access_token_hook(jsonb);

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  user_role text;
  user_tenant_id uuid;
BEGIN
  -- users tablosundan bilgileri al
  -- role enum'ını text'e cast et
  SELECT 
    role::text, 
    tenant_id 
  INTO user_role, user_tenant_id
  FROM public.users
  WHERE id = (event->>'user_id')::uuid;

  -- Eğer user bulunamazsa, default değerler
  IF user_role IS NULL THEN
    user_role := 'personel';
  END IF;

  -- JWT claims'e ekle
  event := jsonb_set(event, '{claims,tenant_id}', to_jsonb(user_tenant_id::text));
  event := jsonb_set(event, '{claims,role}', to_jsonb(user_role));

  RETURN event;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;
REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) FROM authenticated, anon, public;

COMMENT ON FUNCTION public.custom_access_token_hook IS 
'Custom access token hook - JWT''ye tenant_id ve role ekler';

-- ================================================================
-- Hook'u Supabase Auth'a bağla (sadece bilgi, elle yapılacak)
-- ================================================================
-- Supabase Dashboard -> Authentication -> Hooks
-- Custom Access Token Hook -> Enable
-- Function name: public.custom_access_token_hook
