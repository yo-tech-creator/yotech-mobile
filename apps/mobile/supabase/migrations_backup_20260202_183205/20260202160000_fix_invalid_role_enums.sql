-- ============================================================================
-- Fix invalid user_role enum values
-- The enum only has: grand_admin, firma_admin, bolge_muduru, sube_muduru, personel
-- Previous migrations incorrectly used: genel_mudur, patron (which don't exist)
-- ============================================================================

-- 1. Fix send_notification_to_branch function
CREATE OR REPLACE FUNCTION send_notification_to_branch(
  p_tenant_id uuid,
  p_branch_id uuid,
  p_type text,
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
    AND role::text = ANY(p_roles)
    AND is_active = true;

  IF v_user_ids IS NULL OR array_length(v_user_ids, 1) = 0 THEN
    RETURN jsonb_build_object('success', true, 'message', 'No users found in branch');
  END IF;

  RETURN send_notification(p_tenant_id, v_user_ids, p_type, p_title, p_body, p_data);
END;
$$;

-- 2. Fix notify_visual_audit_photo_uploaded function
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

  IF v_task IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get uploader name
  SELECT COALESCE(first_name || ' ' || last_name, 'Personel') INTO v_uploader_name
  FROM users WHERE id = NEW.uploaded_by;

  -- Get users who should be notified (managers)
  -- Use valid enum values: firma_admin, bolge_muduru
  SELECT array_agg(id)
  INTO v_creator_ids
  FROM users
  WHERE tenant_id = v_task.tenant_id
    AND role::text IN ('firma_admin', 'bolge_muduru')
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

-- 3. Fix notify_visual_audit_comment_added function
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
  -- Get task and commenter details
  SELECT t.*, b.name as branch_name, b.tenant_id
  INTO v_task
  FROM visual_audit_tasks t
  JOIN branches b ON b.id = t.branch_id
  WHERE t.id = NEW.task_id;

  IF v_task IS NULL THEN
    RETURN NEW;
  END IF;

  -- Get commenter name
  SELECT COALESCE(first_name || ' ' || last_name, 'Kullanıcı') INTO v_commenter_name
  FROM users WHERE id = NEW.user_id;

  -- Get all participants who should be notified
  -- Use valid enum values: firma_admin, bolge_muduru
  SELECT array_agg(DISTINCT u.id)
  INTO v_notify_ids
  FROM users u
  WHERE u.tenant_id = v_task.tenant_id
    AND u.is_active = true
    AND u.id != NEW.user_id
    AND (
      u.branch_id = v_task.branch_id
      OR u.role::text IN ('firma_admin', 'bolge_muduru')
    );

  IF v_notify_ids IS NOT NULL AND array_length(v_notify_ids, 1) > 0 THEN
    PERFORM send_notification(
      v_task.tenant_id,
      v_notify_ids,
      'visual_audit_comment',
      '💬 Görsel Denetime Yorum Eklendi',
      format('%s: %s', v_commenter_name, LEFT(NEW.content, 100)),
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

-- 4. Fix notify_visual_audit_completed function
CREATE OR REPLACE FUNCTION notify_visual_audit_completed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task record;
  v_notify_ids uuid[];
BEGIN
  -- Only trigger when status changes to 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Get task details
    SELECT t.*, b.name as branch_name, b.tenant_id
    INTO v_task
    FROM visual_audit_tasks t
    JOIN branches b ON b.id = t.branch_id
    WHERE t.id = NEW.id;

    IF v_task IS NULL THEN
      RETURN NEW;
    END IF;

    -- Get managers who should be notified
    -- Use valid enum values: firma_admin, bolge_muduru
    SELECT array_agg(id)
    INTO v_notify_ids
    FROM users
    WHERE tenant_id = v_task.tenant_id
      AND role::text IN ('firma_admin', 'bolge_muduru')
      AND is_active = true;

    IF v_notify_ids IS NOT NULL AND array_length(v_notify_ids, 1) > 0 THEN
      PERFORM send_notification(
        v_task.tenant_id,
        v_notify_ids,
        'visual_audit_completed',
        '✅ Görsel Denetim Tamamlandı',
        format('%s şubesinde görsel denetim tamamlandı', v_task.branch_name),
        jsonb_build_object(
          'task_id', NEW.id,
          'branch_id', v_task.branch_id,
          'route', '/visual-audit/' || NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 5. Fix notify_announcement_published function
CREATE OR REPLACE FUNCTION notify_announcement_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_ids uuid[];
  v_notification_type text := 'announcement';
  v_title text;
  v_body text;
BEGIN
  -- Only trigger on publish (is_active changes to true or new record with is_active=true)
  IF NEW.is_active = true AND (OLD IS NULL OR OLD.is_active IS NULL OR OLD.is_active = false) THEN
    
    v_title := 'Yeni Duyuru';
    v_body := NEW.title;
    
    -- Get target users based on roles and branches
    SELECT array_agg(DISTINCT u.id)
    INTO v_user_ids
    FROM users u
    WHERE u.tenant_id = NEW.tenant_id
      AND u.is_active = true
      AND (
        -- Role filter
        NEW.target_roles IS NULL 
        OR array_length(NEW.target_roles, 1) IS NULL 
        OR u.role::text = ANY(NEW.target_roles)
      )
      AND (
        -- Branch filter
        NEW.target_branches IS NULL 
        OR array_length(NEW.target_branches, 1) IS NULL 
        OR u.branch_id = ANY(NEW.target_branches)
      );
    
    -- Send notifications
    IF v_user_ids IS NOT NULL AND array_length(v_user_ids, 1) > 0 THEN
      PERFORM send_notification(
        NEW.tenant_id,
        v_user_ids,
        v_notification_type,
        v_title,
        v_body,
        jsonb_build_object('announcement_id', NEW.id)
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- 6. Recreate triggers
DROP TRIGGER IF EXISTS trg_notify_visual_audit_photo_uploaded ON visual_audit_photos;
CREATE TRIGGER trg_notify_visual_audit_photo_uploaded
  AFTER INSERT ON visual_audit_photos
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_photo_uploaded();

DROP TRIGGER IF EXISTS trg_notify_visual_audit_comment_added ON visual_audit_comments;
CREATE TRIGGER trg_notify_visual_audit_comment_added
  AFTER INSERT ON visual_audit_comments
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_comment_added();

DROP TRIGGER IF EXISTS trg_notify_visual_audit_completed ON visual_audit_tasks;
CREATE TRIGGER trg_notify_visual_audit_completed
  AFTER UPDATE OF status ON visual_audit_tasks
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_completed();

DROP TRIGGER IF EXISTS trigger_notify_announcement_published ON announcements;
CREATE TRIGGER trigger_notify_announcement_published
  AFTER INSERT OR UPDATE OF is_active ON announcements
  FOR EACH ROW
  EXECUTE FUNCTION notify_announcement_published();
