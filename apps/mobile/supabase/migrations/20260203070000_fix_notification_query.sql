-- =====================================================
-- FIX: Notification Query - Corrected Version
-- =====================================================

-- send_notification fonksiyonunu düzelt
CREATE OR REPLACE FUNCTION send_notification(
  p_tenant_id uuid,
  p_user_ids uuid[],
  p_type notification_type,
  p_title text,
  p_body text DEFAULT NULL,
  p_data jsonb DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_notification_id uuid;
  v_device_token_id uuid;
  v_notifications_created int := 0;
  v_queue_items_created int := 0;
  v_notification_pref text;
  v_pref_key text;
BEGIN
  -- Map notification type to preference key
  v_pref_key := CASE p_type
    WHEN 'visual_audit_task' THEN 'gorevler'
    WHEN 'visual_audit_photo' THEN 'gorevler'
    WHEN 'visual_audit_comment' THEN 'gorevler'
    WHEN 'visual_audit_completed' THEN 'gorevler'
    WHEN 'task_assigned' THEN 'gorevler'
    WHEN 'task_completed' THEN 'gorevler'
    WHEN 'task_approved' THEN 'gorevler'
    WHEN 'announcement' THEN 'duyurular'
    WHEN 'survey' THEN 'duyurular'
    WHEN 'skt_warning' THEN 'skt'
    WHEN 'depot_transfer' THEN 'depo'
    ELSE 'general'
  END;

  -- Process each user
  FOREACH v_user_id IN ARRAY p_user_ids
  LOOP
    -- Check user notification preferences
    SELECT raw_user_meta_data->'notification_preferences'->>v_pref_key
    INTO v_notification_pref
    FROM auth.users
    WHERE id = v_user_id;

    -- Skip if user disabled this notification type
    IF v_notification_pref = 'false' THEN
      CONTINUE;
    END IF;

    -- Create notification record
    INSERT INTO notifications (tenant_id, user_id, type, title, body, data)
    VALUES (p_tenant_id, v_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO v_notification_id;
    
    v_notifications_created := v_notifications_created + 1;

    -- Get the latest device token for this user
    SELECT id INTO v_device_token_id
    FROM device_tokens
    WHERE user_id = v_user_id
      AND updated_at > now() - interval '30 days'
    ORDER BY updated_at DESC
    LIMIT 1;

    -- Queue FCM notification if device token exists
    IF v_device_token_id IS NOT NULL THEN
      INSERT INTO notification_queue (device_token_id, notification_id, title, body, data)
      VALUES (
        v_device_token_id,
        v_notification_id,
        p_title,
        p_body,
        jsonb_build_object(
          'type', p_type::text,
          'notification_id', v_notification_id
        ) || p_data
      )
      ON CONFLICT (notification_id, device_token_id) DO NOTHING;
      
      v_queue_items_created := v_queue_items_created + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_created', v_notifications_created,
    'queue_items_created', v_queue_items_created
  );
END;
$$;

-- Immediate trigger'ı geri ekle (hızlı bildirim için)
CREATE OR REPLACE FUNCTION trigger_immediate_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
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
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_immediate_notification ON notification_queue;
CREATE TRIGGER trg_immediate_notification
  AFTER INSERT ON notification_queue
  FOR EACH STATEMENT
  EXECUTE FUNCTION trigger_immediate_notification();
