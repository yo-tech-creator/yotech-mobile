-- =====================================================
-- SECURITY FIX: Move service role key to Vault
-- =====================================================

-- 1. Vault'a service role key ekle (Dashboard'dan yapılmalı)
-- Supabase Dashboard > Settings > Vault > Add new secret
-- Name: supabase_service_role_key
-- Value: (service role key)

-- 2. Fonksiyonları Vault kullanacak şekilde güncelle
CREATE OR REPLACE FUNCTION public.trigger_send_push_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_service_key text;
BEGIN
  -- Vault'tan key'i al
  SELECT decrypted_secret INTO v_service_key
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_role_key'
  LIMIT 1;
  
  IF v_service_key IS NULL THEN
    RAISE WARNING 'Service role key not found in vault';
    RETURN;
  END IF;
  
  PERFORM net.http_post(
    url := 'https://tmfybgzurgztpmrwspgn.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body := '{}'::jsonb
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Push notification trigger failed: %', SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION trigger_immediate_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_service_key text;
BEGIN
  -- Vault'tan key'i al
  SELECT decrypted_secret INTO v_service_key
  FROM vault.decrypted_secrets
  WHERE name = 'supabase_service_role_key'
  LIMIT 1;
  
  IF v_service_key IS NOT NULL THEN
    PERFORM net.http_post(
      url := 'https://tmfybgzurgztpmrwspgn.supabase.co/functions/v1/send-push-notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_key
      ),
      body := '{}'::jsonb
    );
  END IF;
  
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;
