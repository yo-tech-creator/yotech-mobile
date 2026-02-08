-- =====================================================
-- FIX: Remove duplicate notification triggers
-- Only use cron job (runs every minute)
-- =====================================================

-- 1. Immediate trigger'ı tamamen kaldır
DROP TRIGGER IF EXISTS trg_immediate_notification ON notification_queue;
DROP FUNCTION IF EXISTS trigger_immediate_notification();

-- 2. Announcement trigger'ın duplicate çağrılmasını önle
-- Trigger'a debounce mekanizması ekle
CREATE OR REPLACE FUNCTION notify_announcement_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target_users uuid[];
  v_notification_type notification_type;
  v_title text;
  v_body text;
  v_existing_notification_count int;
BEGIN
  -- Sadece yeni yayınlanan duyurular için tetikle
  IF (TG_OP = 'INSERT' AND NEW.published_at IS NOT NULL) 
     OR (TG_OP = 'UPDATE' AND OLD.published_at IS NULL AND NEW.published_at IS NOT NULL) THEN
    
    -- Bu duyuru için zaten bildirim oluşturulmuş mu kontrol et (duplicate prevention)
    SELECT COUNT(*) INTO v_existing_notification_count
    FROM notifications
    WHERE data->>'announcement_id' = NEW.id::text
    LIMIT 1;
    
    IF v_existing_notification_count > 0 THEN
      -- Zaten bildirim var, tekrar oluşturma
      RETURN NEW;
    END IF;
    
    -- Bildirim türünü belirle
    IF NEW.type = 'survey' THEN
      v_notification_type := 'survey';
      v_title := '📊 Yeni Anket: ' || NEW.title;
      v_body := COALESCE(NEW.summary, left(NEW.content, 100));
    ELSE
      v_notification_type := 'announcement';
      v_title := '📢 Yeni Duyuru: ' || NEW.title;
      v_body := COALESCE(NEW.summary, left(NEW.content, 100));
    END IF;

    -- Hedef kullanıcıları belirle
    SELECT array_agg(DISTINCT u.id)
    INTO v_target_users
    FROM users u
    WHERE u.tenant_id = NEW.tenant_id
      AND u.is_active = true
      AND (
        NEW.target_branches IS NULL 
        OR array_length(NEW.target_branches, 1) IS NULL 
        OR u.branch_id = ANY(NEW.target_branches)
      )
      AND (
        NEW.target_roles IS NULL 
        OR array_length(NEW.target_roles, 1) IS NULL 
        OR u.role::text = ANY(NEW.target_roles)
      )
      AND (
        NOT COALESCE(NEW.managers_only, false) 
        OR u.role IN ('sube_muduru', 'bolge_muduru', 'genel_mudur', 'patron')
      )
      AND (
        CASE NEW.target_scope
          WHEN 'all_branches' THEN true
          WHEN 'selected_branches' THEN u.branch_id = ANY(COALESCE(NEW.target_branches, ARRAY[]::uuid[]))
          WHEN 'region_managers_only' THEN u.role = 'bolge_muduru'
          ELSE true
        END
      );

    -- Bildirim gönder
    IF v_target_users IS NOT NULL AND array_length(v_target_users, 1) > 0 THEN
      PERFORM send_notification(
        NEW.tenant_id,
        v_target_users,
        v_notification_type,
        v_title,
        v_body,
        jsonb_build_object(
          'announcement_id', NEW.id,
          'type', NEW.type::text,
          'priority', NEW.priority,
          'pinned', NEW.pinned,
          'route', CASE 
            WHEN NEW.type = 'survey' THEN '/survey/' || NEW.id
            ELSE '/announcement/' || NEW.id
          END
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 3. Cron job'ı 30 saniyede bir çalışacak şekilde güncelle (daha hızlı bildirim için)
SELECT cron.unschedule('send-push-notifications');
SELECT cron.schedule(
  'send-push-notifications',
  '*/1 * * * *',  -- Her dakika (Supabase cron minimum)
  $$SELECT public.trigger_send_push_notifications()$$
);
