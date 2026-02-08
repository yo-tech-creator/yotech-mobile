-- =====================================================
-- FIX: Immediate notification with proper duplicate prevention
-- =====================================================

-- 1. Cron job'ı 5 dakikada bir çalışacak şekilde değiştir (sadece yedek olarak)
SELECT cron.unschedule('send-push-notifications');
SELECT cron.schedule(
  'send-push-notifications',
  '*/5 * * * *',  -- 5 dakikada bir (yedek)
  $$SELECT public.trigger_send_push_notifications()$$
);

-- 2. Device tokens tablosunda user başına tek token olmasını garanti et
-- Önce mevcut duplicate'ları temizle
DELETE FROM device_tokens dt1
WHERE EXISTS (
  SELECT 1 FROM device_tokens dt2
  WHERE dt2.user_id = dt1.user_id
    AND dt2.id != dt1.id
    AND dt2.updated_at > dt1.updated_at
);

-- 3. User başına tek device token constraint'i ekle
ALTER TABLE device_tokens 
DROP CONSTRAINT IF EXISTS device_tokens_user_unique;

ALTER TABLE device_tokens 
ADD CONSTRAINT device_tokens_user_unique UNIQUE (user_id);

-- 4. register_device_token fonksiyonunu güncelle - UPSERT kullan
CREATE OR REPLACE FUNCTION register_device_token(
  p_user_id uuid,
  p_tenant_id uuid,
  p_token text,
  p_platform text DEFAULT 'android'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Aynı user için token varsa güncelle, yoksa ekle
  INSERT INTO device_tokens (user_id, tenant_id, token, platform, updated_at)
  VALUES (p_user_id, p_tenant_id, p_token, p_platform, now())
  ON CONFLICT (user_id) 
  DO UPDATE SET 
    token = EXCLUDED.token,
    platform = EXCLUDED.platform,
    tenant_id = EXCLUDED.tenant_id,
    updated_at = now();
  
  RETURN jsonb_build_object('success', true, 'action', 'upserted');
END;
$$;

-- 5. Immediate trigger'ı geri ekle
CREATE OR REPLACE FUNCTION trigger_immediate_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  -- Edge Function'ı çağır
  PERFORM net.http_post(
    url := 'https://tmfybgzurgztpmrwspgn.supabase.co/functions/v1/send-push-notifications',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtZnliZ3p1cmd6dHBtcndzcGduIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTY4NDk0MCwiZXhwIjoyMDQ1MjYwOTQwfQ.hZxIpOu1dNKSfpbWKJmBwDKw1-ksC1AzKoMsJa9HQPE'
    ),
    body := '{}'::jsonb
  );
  RETURN NULL;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$;

-- FOR EACH STATEMENT - tüm insert'ler için TEK SEFER çağrılır
DROP TRIGGER IF EXISTS trg_immediate_notification ON notification_queue;
CREATE TRIGGER trg_immediate_notification
  AFTER INSERT ON notification_queue
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_immediate_notification();
