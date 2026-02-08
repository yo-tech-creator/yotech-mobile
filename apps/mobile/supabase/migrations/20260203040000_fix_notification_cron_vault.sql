-- =====================================================
-- FIX: Push Notification Cron - Use Vault for Service Key
-- =====================================================

-- Drop old cron job if exists
SELECT cron.unschedule('send-push-notifications');

-- Store the service role key in vault (you need to set this manually in Supabase Dashboard)
-- Go to: Database > Secrets (Vault) > Add new secret
-- Name: service_role_key
-- Value: your-service-role-key

-- Alternative approach: Use Edge Function scheduling from Dashboard
-- Supabase Dashboard > Edge Functions > send-push-notifications > Schedules

-- For now, let's use a simpler approach - process notifications directly in the trigger
-- This way we don't need a cron job at all

-- Enhanced send_notification function that queues for Edge Function
-- The Edge Function will be called manually or via webhook

-- Update the cron function to use supabase_url from vault
CREATE OR REPLACE FUNCTION public.trigger_send_push_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_url TEXT := 'https://tmfybgzurgztpmrwspgn.supabase.co/functions/v1/send-push-notifications';
  v_service_key TEXT;
BEGIN
  -- Try to get service key from vault
  SELECT decrypted_secret INTO v_service_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;
  
  -- If no vault secret, try database setting
  IF v_service_key IS NULL THEN
    v_service_key := current_setting('app.settings.service_role_key', true);
  END IF;
  
  -- If still no key, skip silently
  IF v_service_key IS NULL OR v_service_key = '' THEN
    RAISE NOTICE 'Service role key not configured. Skipping push notification trigger.';
    RETURN;
  END IF;
  
  -- Make HTTP request to Edge Function
  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    body := '{}'::jsonb
  );
  
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Failed to trigger push notifications: %', SQLERRM;
END;
$$;

-- Re-schedule the cron job
SELECT cron.schedule(
  'send-push-notifications',
  '* * * * *',
  $$SELECT public.trigger_send_push_notifications()$$
);

-- IMPORTANT: You need to add the service_role_key to Supabase Vault
-- 1. Go to Supabase Dashboard > Database > Secrets
-- 2. Add new secret: name = "service_role_key", value = your actual service role key
-- 3. The service role key can be found in: Project Settings > API > service_role (secret)
