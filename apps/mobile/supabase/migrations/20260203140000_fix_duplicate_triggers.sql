-- =====================================================
-- FIX: Remove duplicate announcement triggers
-- Sorun: İki trigger aynı anda çalışıyor ve çift bildirim oluşturuyor
-- =====================================================

-- 1. Duplicate trigger'ı kaldır - sadece birini tut
DROP TRIGGER IF EXISTS trigger_notify_announcement_published ON announcements;

-- 2. Var olan trigger'ı düzelt - sadece published_at değiştiğinde çalışsın
DROP TRIGGER IF EXISTS trg_notify_announcement_published ON announcements;

CREATE TRIGGER trg_notify_announcement_published
  AFTER INSERT OR UPDATE OF published_at ON announcements
  FOR EACH ROW
  EXECUTE FUNCTION notify_announcement_published();

-- 3. Fonksiyonu düzelt - daha güvenli kontrol ekle
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
  v_already_notified boolean;
BEGIN
  -- Sadece yeni yayınlanan duyurular için tetikle
  -- INSERT: published_at NOT NULL ise
  -- UPDATE: published_at NULL'dan NOT NULL'a değiştiyse
  IF NOT (
    (TG_OP = 'INSERT' AND NEW.published_at IS NOT NULL) 
    OR (TG_OP = 'UPDATE' AND OLD.published_at IS NULL AND NEW.published_at IS NOT NULL)
  ) THEN
    RETURN NEW;
  END IF;

  -- Bu duyuru için daha önce bildirim gönderilmiş mi kontrol et
  SELECT EXISTS(
    SELECT 1 FROM notifications 
    WHERE data->>'announcement_id' = NEW.id::text
    LIMIT 1
  ) INTO v_already_notified;

  IF v_already_notified THEN
    RAISE NOTICE 'Announcement %: Already notified, skipping', NEW.id;
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
      OR u.role IN ('sube_muduru', 'bolge_muduru', 'firma_admin', 'grand_admin')
    )
    AND (
      CASE NEW.target_scope
        WHEN 'all_branches' THEN true
        WHEN 'selected_branches' THEN u.branch_id = ANY(COALESCE(NEW.target_branches, ARRAY[]::uuid[]))
        WHEN 'region_managers_only' THEN u.role = 'bolge_muduru'
        ELSE true
      END
    );

  -- Debug log
  RAISE NOTICE 'Announcement %: Found % target users', NEW.id, COALESCE(array_length(v_target_users, 1), 0);

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

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notify_announcement_published() IS 
'Duyuru veya anket yayınlandığında hedef kitleye push bildirim gönderir. 
Duplicate önleme: notifications tablosunda aynı announcement_id ile kayıt varsa atlar.';
