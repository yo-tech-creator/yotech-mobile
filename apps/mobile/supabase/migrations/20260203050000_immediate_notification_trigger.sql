-- =====================================================
-- IMMEDIATE NOTIFICATION TRIGGER
-- Bildirim oluşturulduğunda hemen Edge Function'ı çağır
-- =====================================================

-- Bildirim queue'ya eklendiğinde hemen Edge Function'ı tetikle
CREATE OR REPLACE FUNCTION trigger_immediate_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Edge Function'ı asenkron olarak çağır (pg_net ile)
  -- Bu sayede trigger bloke olmaz
  PERFORM net.http_post(
    url := 'https://tmfybgzurgztpmrwspgn.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtZnliZ3p1cmd6dHBtcndzcGduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTY4NDk0MCwiZXhwIjoyMDQ1MjYwOTQwfQ.hZxIpOu1dNKSfpbWKJmBwDKw1-ksC1AzKoMsJa9HQPE'
    ),
    body := '{}'::jsonb
  );
  
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Hata olursa sessizce devam et (cron job yedek olarak çalışır)
  RETURN NEW;
END;
$$;

-- notification_queue'ya yeni kayıt eklendiğinde tetikle
DROP TRIGGER IF EXISTS trg_immediate_notification ON notification_queue;
CREATE TRIGGER trg_immediate_notification
  AFTER INSERT ON notification_queue
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_immediate_notification();

-- Not: FOR EACH STATEMENT kullanıyoruz çünkü birden fazla kayıt
-- aynı anda eklenebilir ve her biri için ayrı HTTP call yapmak istemiyoruz
