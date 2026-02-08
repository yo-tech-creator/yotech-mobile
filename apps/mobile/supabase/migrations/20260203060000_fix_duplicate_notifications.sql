-- =====================================================
-- FIX: Duplicate Notification Prevention
-- =====================================================

-- 1. Eski/duplicate device token'ları temizle
-- Aynı kullanıcı için sadece en son token'ı tut
DELETE FROM device_tokens dt1
WHERE EXISTS (
  SELECT 1 FROM device_tokens dt2
  WHERE dt2.user_id = dt1.user_id
    AND dt2.updated_at > dt1.updated_at
);

-- 2. Aynı token'ın birden fazla kaydını sil
DELETE FROM device_tokens dt1
WHERE id NOT IN (
  SELECT DISTINCT ON (token) id
  FROM device_tokens
  ORDER BY token, updated_at DESC
);

-- 3. notification_queue'ya unique constraint ekle
-- Aynı notification_id + device_token_id kombinasyonu tekrar eklenmesin
ALTER TABLE notification_queue 
DROP CONSTRAINT IF EXISTS notification_queue_unique_per_device;

ALTER TABLE notification_queue 
ADD CONSTRAINT notification_queue_unique_per_device 
UNIQUE (notification_id, device_token_id);

-- 4. send_notification fonksiyonunu güncelle - duplicate kontrolü ekle
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
  v_device_token record;
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

    -- Queue FCM notification for the LATEST device only (not all devices)
    FOR v_device_token IN
      SELECT DISTINCT ON (user_id) id, token, platform
      FROM device_tokens
      WHERE user_id = v_user_id
        AND updated_at > now() - interval '30 days'
      ORDER BY user_id, updated_at DESC
      LIMIT 1  -- Sadece en son cihaz
    LOOP
      -- Use ON CONFLICT to prevent duplicates
      INSERT INTO notification_queue (device_token_id, notification_id, title, body, data)
      VALUES (
        v_device_token.id,
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
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_created', v_notifications_created,
    'queue_items_created', v_queue_items_created
  );
END;
$$;

-- 5. Immediate trigger'ı devre dışı bırak (cron yeterli)
-- Çünkü hem cron hem immediate trigger çalışınca duplicate olabilir
DROP TRIGGER IF EXISTS trg_immediate_notification ON notification_queue;
