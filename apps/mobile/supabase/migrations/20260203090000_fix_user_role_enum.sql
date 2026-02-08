-- =====================================================
-- FIX: Update trigger to use correct user_role enum values
-- =====================================================

-- Mevcut enum değerleri:
-- 'grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru', 'personel'

-- notify_announcement_published fonksiyonunu düzelt
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
    
    -- Bu duyuru için zaten bildirim oluşturulmuş mu kontrol et
    SELECT COUNT(*) INTO v_existing_notification_count
    FROM notifications
    WHERE data->>'announcement_id' = NEW.id::text
    LIMIT 1;
    
    IF v_existing_notification_count > 0 THEN
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
      -- managers_only: sadece yöneticiler (sube_muduru, bolge_muduru, firma_admin, grand_admin)
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
