-- =====================================================
-- CRON JOB: Send pending push notifications
-- =====================================================
-- Calls the Edge Function every minute to process pending notifications

-- First, make sure pg_net extension is enabled (for HTTP calls)
-- This is usually enabled by default on Supabase

-- Option 1: Using pg_cron to call the Edge Function
-- Note: This requires the Edge Function URL and service role key

-- Create a function to call the Edge Function
CREATE OR REPLACE FUNCTION public.trigger_send_push_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_url TEXT;
  v_service_key TEXT;
BEGIN
  -- Get the Supabase URL from environment or hardcode it
  v_url := 'https://tmfybgzurgztpmrwspgn.supabase.co/functions/v1/send-push-notifications';
  
  -- The service role key should be stored securely
  -- For now, we'll use pg_net to make the HTTP call
  
  -- Using pg_net extension to make HTTP request
  PERFORM net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true)
    ),
    body := '{}'::jsonb
  );
  
EXCEPTION WHEN OTHERS THEN
  -- Log error but don't fail
  RAISE WARNING 'Failed to trigger push notifications: %', SQLERRM;
END;
$$;

-- Schedule to run every minute
-- Note: Uncomment after confirming pg_cron is working
-- SELECT cron.schedule(
--   'send-push-notifications',
--   '* * * * *',  -- Every minute
--   $$SELECT trigger_send_push_notifications()$$
-- );

-- Alternative: Use Supabase Dashboard to set up a cron job
-- Go to: Database > Extensions > pg_cron
-- Or use: Edge Functions > Schedules
