-- Fix current_tenant_id() function to properly get tenant_id from users table
-- instead of relying on JWT claim which may not be present

CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  -- First try JWT claim (for custom tokens)
  -- Then fallback to users table lookup
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (SELECT tenant_id FROM public.users WHERE id = auth.uid())
  );
$$;

COMMENT ON FUNCTION "public"."current_tenant_id"() IS 
'Returns the current user''s tenant_id. First checks JWT claim, then falls back to users table lookup.';
