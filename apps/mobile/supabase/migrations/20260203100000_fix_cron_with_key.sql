-- =====================================================
-- FIX: Cron job with hardcoded service role key
-- =====================================================

-- Eski cron job'ı kaldır
SELECT cron.unschedule('send-push-notifications');

-- Fonksiyonu güncelle - service role key hardcoded
CREATE OR REPLACE FUNCTION public.trigger_send_push_notifications()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- pg_net ile Edge Function'ı çağır
  PERFORM net.http_post(
    url := 'https://tmfybgzurgztpmrwspgn.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtZnliZ3p1cmd6dHBtcndzcGduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTY4NDk0MCwiZXhwIjoyMDQ1MjYwOTQwfQ.hZxIpOu1dNKSfpbWKJmBwDKw1-ksC1AzKoMsJa9HQPE'
    ),
    body := '{}'::jsonb
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Push notification trigger failed: %', SQLERRM;
END;
$$;

-- Cron job'ı yeniden oluştur - her dakika çalışsın
SELECT cron.schedule(
  'send-push-notifications',
  '* * * * *',
  $$SELECT public.trigger_send_push_notifications()$$
);

-- Cron job'ın oluşturulduğunu doğrula
-- SELECT * FROM cron.job WHERE jobname = 'send-push-notifications';
