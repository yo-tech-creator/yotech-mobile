-- ============================================================================
-- NOTIFICATION SYSTEM - Complete Push Notification Infrastructure
-- ============================================================================

-- 1. ENUM: Bildirim türleri
DO $$ BEGIN
  CREATE TYPE notification_type AS ENUM (
    'visual_audit_task',      -- Yeni görsel denetim görevi
    'visual_audit_photo',     -- Görsel denetime fotoğraf yüklendi
    'visual_audit_comment',   -- Görsel denetime yorum yapıldı
    'visual_audit_completed', -- Görsel denetim tamamlandı
    'task_assigned',          -- Yeni görev atandı
    'task_completed',         -- Görev tamamlandı
    'task_approved',          -- Görev onaylandı
    'announcement',           -- Yeni duyuru
    'survey',                 -- Yeni anket
    'skt_warning',            -- SKT uyarısı
    'depot_transfer',         -- Depo transfer bildirimi
    'general'                 -- Genel bildirim
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. TABLE: Bildirim geçmişi
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type notification_type NOT NULL DEFAULT 'general',
  title text NOT NULL,
  body text,
  data jsonb DEFAULT '{}',  -- Deep link, referans ID'leri vb.
  read_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_id ON notifications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id) WHERE read_at IS NULL;

-- 3. TABLE: Bildirim kuyrugu (FCM'e gönderilecek bildirimler)
CREATE TABLE IF NOT EXISTS notification_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_token_id uuid NOT NULL REFERENCES device_tokens(id) ON DELETE CASCADE,
  notification_id uuid REFERENCES notifications(id) ON DELETE SET NULL,
  title text NOT NULL,
  body text,
  data jsonb DEFAULT '{}',
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  error_message text,
  created_at timestamptz DEFAULT now(),
  sent_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON notification_queue(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_notification_queue_device ON notification_queue(device_token_id);

-- 4. RLS Policies
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
DROP POLICY IF EXISTS notifications_select_policy ON notifications;
CREATE POLICY notifications_select_policy ON notifications
  FOR SELECT USING (user_id = auth.uid());

-- Users can mark their own notifications as read
DROP POLICY IF EXISTS notifications_update_policy ON notifications;
CREATE POLICY notifications_update_policy ON notifications
  FOR UPDATE USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Service role can insert notifications
DROP POLICY IF EXISTS notifications_insert_policy ON notifications;
CREATE POLICY notifications_insert_policy ON notifications
  FOR INSERT WITH CHECK (true);

-- Queue is managed by service role only (via SECURITY DEFINER functions)
DROP POLICY IF EXISTS notification_queue_policy ON notification_queue;
CREATE POLICY notification_queue_policy ON notification_queue
  FOR ALL USING (false);

-- 5. FUNCTION: Send notification to user(s)
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

    -- Skip if user disabled this notification type (null = enabled by default)
    IF v_notification_pref = 'false' THEN
      CONTINUE;
    END IF;

    -- Create notification record
    INSERT INTO notifications (tenant_id, user_id, type, title, body, data)
    VALUES (p_tenant_id, v_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO v_notification_id;
    
    v_notifications_created := v_notifications_created + 1;

    -- Queue FCM notification for each device
    FOR v_device_token IN
      SELECT id, token, platform
      FROM device_tokens
      WHERE user_id = v_user_id
        AND updated_at > now() - interval '30 days'  -- Only active devices
    LOOP
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
      );
      
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

-- 6. FUNCTION: Send notification to branch users
CREATE OR REPLACE FUNCTION send_notification_to_branch(
  p_tenant_id uuid,
  p_branch_id uuid,
  p_type notification_type,
  p_title text,
  p_body text DEFAULT NULL,
  p_data jsonb DEFAULT '{}',
  p_roles text[] DEFAULT ARRAY['sube_muduru', 'personel']
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_ids uuid[];
BEGIN
  -- Get users in this branch with specified roles
  SELECT array_agg(id)
  INTO v_user_ids
  FROM users
  WHERE branch_id = p_branch_id
    AND role = ANY(p_roles)
    AND is_active = true;

  IF v_user_ids IS NULL OR array_length(v_user_ids, 1) = 0 THEN
    RETURN jsonb_build_object('success', true, 'message', 'No users found in branch');
  END IF;

  RETURN send_notification(p_tenant_id, v_user_ids, p_type, p_title, p_body, p_data);
END;
$$;

-- 7. FUNCTION: Mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE notifications
  SET read_at = now()
  WHERE id = p_notification_id
    AND user_id = auth.uid()
    AND read_at IS NULL;
  
  RETURN FOUND;
END;
$$;

-- 8. FUNCTION: Mark all notifications as read
CREATE OR REPLACE FUNCTION mark_all_notifications_read()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE notifications
  SET read_at = now()
  WHERE user_id = auth.uid()
    AND read_at IS NULL;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- 9. FUNCTION: Get unread notification count
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS int
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT count(*)::int
  FROM notifications
  WHERE user_id = auth.uid()
    AND read_at IS NULL;
$$;

-- 10. TRIGGER: Visual Audit Task Created - Notify branch
CREATE OR REPLACE FUNCTION notify_visual_audit_task_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_name text;
  v_section_name text;
  v_tenant_id uuid;
BEGIN
  -- Get branch and section names
  SELECT b.name, b.tenant_id INTO v_branch_name, v_tenant_id
  FROM branches b WHERE b.id = NEW.branch_id;

  SELECT s.name INTO v_section_name
  FROM visual_audit_sections s WHERE s.id = NEW.section_id;

  -- Notify branch users
  PERFORM send_notification_to_branch(
    v_tenant_id,
    NEW.branch_id,
    'visual_audit_task',
    '📸 Yeni Görsel Denetim Görevi',
    format('%s bölümü için fotoğraf çekmeniz isteniyor. Deadline: %s',
      v_section_name,
      to_char(NEW.deadline_at, 'HH24:MI')
    ),
    jsonb_build_object(
      'task_id', NEW.id,
      'section_id', NEW.section_id,
      'branch_id', NEW.branch_id,
      'route', '/visual-audit/' || NEW.id
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_visual_audit_task_created ON visual_audit_tasks;
CREATE TRIGGER trg_notify_visual_audit_task_created
  AFTER INSERT ON visual_audit_tasks
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_task_created();

-- 11. TRIGGER: Visual Audit Photo Uploaded - Notify task creator
CREATE OR REPLACE FUNCTION notify_visual_audit_photo_uploaded()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_branch_name text;
  v_uploader_name text;
  v_creator_ids uuid[];
BEGIN
  -- Get task details
  SELECT t.*, b.name as branch_name, b.tenant_id
  INTO v_task
  FROM visual_audit_tasks t
  JOIN branches b ON b.id = t.branch_id
  WHERE t.id = NEW.task_id;

  -- Get uploader name
  SELECT full_name INTO v_uploader_name
  FROM users WHERE id = NEW.uploaded_by;

  -- Get users who should be notified (bölge müdürleri, genel müdürler)
  SELECT array_agg(id)
  INTO v_creator_ids
  FROM users
  WHERE tenant_id = v_task.tenant_id
    AND role IN ('bolge_muduru', 'genel_mudur', 'patron')
    AND is_active = true;

  IF v_creator_ids IS NOT NULL AND array_length(v_creator_ids, 1) > 0 THEN
    PERFORM send_notification(
      v_task.tenant_id,
      v_creator_ids,
      'visual_audit_photo',
      '📷 Görsel Denetim Fotoğrafı Yüklendi',
      format('%s şubesinden %s fotoğraf yükledi',
        v_task.branch_name,
        COALESCE(v_uploader_name, 'Personel')
      ),
      jsonb_build_object(
        'task_id', NEW.task_id,
        'photo_id', NEW.id,
        'branch_id', v_task.branch_id,
        'route', '/visual-audit/' || NEW.task_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_visual_audit_photo_uploaded ON visual_audit_photos;
CREATE TRIGGER trg_notify_visual_audit_photo_uploaded
  AFTER INSERT ON visual_audit_photos
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_photo_uploaded();

-- 12. TRIGGER: Visual Audit Comment Added - Notify relevant users
CREATE OR REPLACE FUNCTION notify_visual_audit_comment_added()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_commenter_name text;
  v_notify_ids uuid[];
BEGIN
  -- Get task details
  SELECT t.*, b.name as branch_name, b.tenant_id
  INTO v_task
  FROM visual_audit_tasks t
  JOIN branches b ON b.id = t.branch_id
  WHERE t.id = NEW.task_id;

  -- Get commenter name
  SELECT full_name INTO v_commenter_name
  FROM users WHERE id = NEW.user_id;

  -- Get all users involved in this task (except commenter)
  SELECT array_agg(DISTINCT user_id)
  INTO v_notify_ids
  FROM (
    -- Photo uploaders
    SELECT uploaded_by as user_id FROM visual_audit_photos WHERE task_id = NEW.task_id
    UNION
    -- Previous commenters
    SELECT user_id FROM visual_audit_comments WHERE task_id = NEW.task_id
    UNION
    -- Branch managers
    SELECT id as user_id FROM users WHERE branch_id = v_task.branch_id AND role = 'sube_muduru'
  ) involved
  WHERE user_id != NEW.user_id;

  IF v_notify_ids IS NOT NULL AND array_length(v_notify_ids, 1) > 0 THEN
    PERFORM send_notification(
      v_task.tenant_id,
      v_notify_ids,
      'visual_audit_comment',
      '💬 Yeni Yorum',
      format('%s görsel denetiminize yorum yaptı: "%s"',
        COALESCE(v_commenter_name, 'Kullanıcı'),
        left(NEW.comment, 50) || CASE WHEN length(NEW.comment) > 50 THEN '...' ELSE '' END
      ),
      jsonb_build_object(
        'task_id', NEW.task_id,
        'comment_id', NEW.id,
        'branch_id', v_task.branch_id,
        'route', '/visual-audit/' || NEW.task_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_visual_audit_comment_added ON visual_audit_comments;
CREATE TRIGGER trg_notify_visual_audit_comment_added
  AFTER INSERT ON visual_audit_comments
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_comment_added();

-- 13. TRIGGER: Visual Audit Task Completed
CREATE OR REPLACE FUNCTION notify_visual_audit_task_completed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch record;
  v_section_name text;
  v_manager_ids uuid[];
BEGIN
  -- Only trigger when status changes to completed
  IF OLD.status = 'completed' OR NEW.status != 'completed' THEN
    RETURN NEW;
  END IF;

  -- Get branch details
  SELECT b.*, b.tenant_id INTO v_branch
  FROM branches b WHERE b.id = NEW.branch_id;

  SELECT name INTO v_section_name
  FROM visual_audit_sections WHERE id = NEW.section_id;

  -- Notify regional managers and above
  SELECT array_agg(id)
  INTO v_manager_ids
  FROM users
  WHERE tenant_id = v_branch.tenant_id
    AND role IN ('bolge_muduru', 'genel_mudur', 'patron')
    AND is_active = true;

  IF v_manager_ids IS NOT NULL AND array_length(v_manager_ids, 1) > 0 THEN
    PERFORM send_notification(
      v_branch.tenant_id,
      v_manager_ids,
      'visual_audit_completed',
      '✅ Görsel Denetim Tamamlandı',
      format('%s şubesi %s denetimini tamamladı',
        v_branch.name,
        v_section_name
      ),
      jsonb_build_object(
        'task_id', NEW.id,
        'branch_id', NEW.branch_id,
        'route', '/visual-audit/' || NEW.id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_visual_audit_task_completed ON visual_audit_tasks;
CREATE TRIGGER trg_notify_visual_audit_task_completed
  AFTER UPDATE ON visual_audit_tasks
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_task_completed();

-- GRANTS
GRANT EXECUTE ON FUNCTION send_notification(uuid, uuid[], notification_type, text, text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION send_notification_to_branch(uuid, uuid, notification_type, text, text, jsonb, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_all_notifications_read() TO authenticated;
GRANT EXECUTE ON FUNCTION get_unread_notification_count() TO authenticated;

GRANT SELECT, UPDATE ON notifications TO authenticated;

-- Comments
COMMENT ON TABLE notifications IS 'Bildirim geçmişi - kullanıcı bazlı bildirimler';
COMMENT ON TABLE notification_queue IS 'FCM bildirim kuyruğu - Edge Function tarafından işlenir';
COMMENT ON FUNCTION send_notification IS 'Belirtilen kullanıcılara bildirim gönderir';
COMMENT ON FUNCTION send_notification_to_branch IS 'Bir şubedeki belirtilen rollere bildirim gönderir';
