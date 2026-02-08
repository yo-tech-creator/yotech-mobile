-- ============================================================================
-- COMPREHENSIVE FIX: All Visual Audit and Notification Functions
-- ============================================================================
-- This migration fixes:
-- 1. branches.active -> branches.is_active (column was renamed)
-- 2. Invalid role enum values (genel_mudur, patron don't exist)
-- 3. Role enum comparisons (need ::text cast)
-- 4. All visual audit functions that reference branches
-- ============================================================================

-- =====================================================
-- 1. CREATE_VISUAL_AUDIT_TASK function
-- =====================================================
CREATE OR REPLACE FUNCTION create_visual_audit_task(
    p_section_ids UUID[],
    p_branch_ids UUID[] DEFAULT NULL,
    p_deadline_minutes INTEGER DEFAULT 60,
    p_min_photos INTEGER DEFAULT 1,
    p_note TEXT DEFAULT NULL,
    p_scheduled_date DATE DEFAULT CURRENT_DATE,
    p_scheduled_hour INTEGER DEFAULT 9,
    p_plan_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
    v_branch_ids UUID[];
    v_branch_id UUID;
    v_section_id UUID;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMP;
    v_result JSON;
    v_results JSON[] := '{}';
    v_task_id UUID;
BEGIN
    SELECT u.tenant_id, u.id INTO v_tenant_id, v_user_id 
    FROM users u WHERE u.id = auth.uid();
    
    IF v_tenant_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
    END IF;

    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir bölüm seçmelisiniz');
    END IF;

    -- FIX: Use is_active instead of active
    IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.is_active = true;
    ELSE
        v_branch_ids := p_branch_ids;
    END IF;

    IF v_branch_ids IS NULL OR array_length(v_branch_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Aktif şube bulunamadı');
    END IF;

    v_scheduled_time := (LPAD(p_scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (p_scheduled_date::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP + (p_deadline_minutes || ' minutes')::INTERVAL;

    FOREACH v_branch_id IN ARRAY v_branch_ids LOOP
        FOREACH v_section_id IN ARRAY p_section_ids LOOP
            INSERT INTO visual_audit_tasks (
                tenant_id, branch_id, section_id, status, scheduled_date,
                scheduled_time, deadline_at, min_photos, notes, created_by, plan_id
            ) VALUES (
                v_tenant_id, v_branch_id, v_section_id, 'pending', p_scheduled_date,
                v_scheduled_time, v_deadline_at, p_min_photos, p_note, v_user_id, p_plan_id
            )
            RETURNING id INTO v_task_id;

            SELECT json_build_object(
                'task_id', v_task_id,
                'branch_name', b.name,
                'section_name', s.name
            ) INTO v_result
            FROM branches b, visual_audit_sections s
            WHERE b.id = v_branch_id AND s.id = v_section_id;

            v_results := array_append(v_results, v_result);
        END LOOP;
    END LOOP;

    RETURN json_build_object('success', true, 'tasks', v_results);
END;
$$;

-- =====================================================
-- 2. CREATE_VISUAL_AUDIT_TASK_WITH_PLAN function
-- =====================================================
DROP FUNCTION IF EXISTS create_visual_audit_task_with_plan(UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], INTEGER);
DROP FUNCTION IF EXISTS create_visual_audit_task_with_plan;

CREATE OR REPLACE FUNCTION create_visual_audit_task_with_plan(
    p_section_ids UUID[],
    p_branch_ids UUID[] DEFAULT NULL,
    p_scheduled_hour INTEGER DEFAULT 9,
    p_deadline_minutes INTEGER DEFAULT 60,
    p_min_photos INTEGER DEFAULT 1,
    p_notes TEXT DEFAULT NULL,
    p_recurrence TEXT DEFAULT 'daily',
    p_days_of_week INTEGER[] DEFAULT NULL,
    p_day_of_month INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
    v_branch_ids UUID[];
    v_plan_id UUID;
    v_today DATE := CURRENT_DATE;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMP;
    v_branch_id UUID;
    v_section_id UUID;
    v_task_id UUID;
    v_section_names TEXT[];
    v_branch_names TEXT[];
BEGIN
    SELECT u.tenant_id, u.id INTO v_tenant_id, v_user_id 
    FROM users u WHERE u.id = auth.uid();
    
    IF v_tenant_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
    END IF;

    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir bölüm seçmelisiniz');
    END IF;

    -- FIX: Use is_active instead of active
    IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.is_active = true;
    ELSE
        v_branch_ids := p_branch_ids;
    END IF;

    IF v_branch_ids IS NULL OR array_length(v_branch_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Aktif şube bulunamadı');
    END IF;

    -- Get section and branch names
    SELECT ARRAY_AGG(s.name) INTO v_section_names
    FROM visual_audit_sections s WHERE s.id = ANY(p_section_ids);
    
    SELECT ARRAY_AGG(b.name) INTO v_branch_names
    FROM branches b WHERE b.id = ANY(v_branch_ids);

    -- Create plan
    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, 
        days_of_week, day_of_month, is_active, created_by
    ) VALUES (
        v_tenant_id,
        COALESCE(v_section_names[1], 'Görsel Denetim') || ' - ' || to_char(CURRENT_TIMESTAMP, 'DD.MM.YYYY'),
        p_section_ids,
        v_branch_ids,
        p_scheduled_hour,
        p_deadline_minutes,
        p_min_photos,
        p_notes,
        p_recurrence,
        p_days_of_week,
        p_day_of_month,
        true,
        v_user_id
    )
    RETURNING id INTO v_plan_id;

    -- Calculate times
    v_scheduled_time := (LPAD(p_scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (v_today::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP + (p_deadline_minutes || ' minutes')::INTERVAL;

    -- Create today's tasks
    FOREACH v_branch_id IN ARRAY v_branch_ids LOOP
        FOREACH v_section_id IN ARRAY p_section_ids LOOP
            INSERT INTO visual_audit_tasks (
                tenant_id, branch_id, section_id, status, scheduled_date,
                scheduled_time, deadline_at, min_photos, notes, created_by, plan_id
            ) VALUES (
                v_tenant_id, v_branch_id, v_section_id, 'pending', v_today,
                v_scheduled_time, v_deadline_at, p_min_photos, p_notes, v_user_id, v_plan_id
            );
        END LOOP;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'plan_id', v_plan_id,
        'sections', v_section_names,
        'branches', v_branch_names,
        'tasks_created', array_length(v_branch_ids, 1) * array_length(p_section_ids, 1)
    );
END;
$$;

-- =====================================================
-- 3. EXECUTE_VISUAL_AUDIT_PLAN function
-- =====================================================
CREATE OR REPLACE FUNCTION execute_visual_audit_plan(p_plan_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_plan RECORD;
    v_tenant_id UUID;
    v_branch_ids UUID[];
    v_branch_id UUID;
    v_section_id UUID;
    v_today DATE := CURRENT_DATE;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMP;
    v_tasks_created INTEGER := 0;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    SELECT * INTO v_plan FROM visual_audit_task_plans 
    WHERE id = p_plan_id AND tenant_id = v_tenant_id;
    
    IF v_plan IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamadı');
    END IF;

    -- FIX: Use is_active instead of active
    IF v_plan.branch_ids IS NULL OR array_length(v_plan.branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.is_active = true;
    ELSE
        v_branch_ids := v_plan.branch_ids;
    END IF;

    v_scheduled_time := (LPAD(v_plan.scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (v_today::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP + (v_plan.deadline_minutes || ' minutes')::INTERVAL;

    FOREACH v_branch_id IN ARRAY v_branch_ids LOOP
        FOREACH v_section_id IN ARRAY v_plan.section_ids LOOP
            IF NOT EXISTS (
                SELECT 1 FROM visual_audit_tasks 
                WHERE plan_id = p_plan_id AND branch_id = v_branch_id 
                AND section_id = v_section_id AND scheduled_date = v_today
            ) THEN
                INSERT INTO visual_audit_tasks (
                    tenant_id, branch_id, section_id, status, scheduled_date,
                    scheduled_time, deadline_at, min_photos, notes, created_by, plan_id
                ) VALUES (
                    v_tenant_id, v_branch_id, v_section_id, 'pending', v_today,
                    v_scheduled_time, v_deadline_at, v_plan.min_photos, 
                    v_plan.notes, v_plan.created_by, p_plan_id
                );
                v_tasks_created := v_tasks_created + 1;
            END IF;
        END LOOP;
    END LOOP;

    UPDATE visual_audit_task_plans 
    SET last_run_at = NOW() 
    WHERE id = p_plan_id;

    RETURN json_build_object('success', true, 'tasks_created', v_tasks_created);
END;
$$;

-- =====================================================
-- 4. GENERATE_TASKS_FOR_TEMPLATE function
-- =====================================================
CREATE OR REPLACE FUNCTION generate_tasks_for_template()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_branch_id UUID;
  v_branches UUID[];
  v_schedule DATE;
  v_scheduled_time TIME;
  v_deadline_at TIMESTAMP;
BEGIN
  IF NEW.is_active = TRUE THEN
    v_schedule := COALESCE(NEW.next_scheduled_date, CURRENT_DATE);
    
    -- FIX: Use is_active instead of active
    IF NEW.branch_ids IS NULL OR array_length(NEW.branch_ids, 1) = 0 THEN
      SELECT ARRAY_AGG(b.id) INTO v_branches
      FROM branches b
      WHERE b.tenant_id = NEW.tenant_id AND b.is_active = TRUE;
    ELSE
      v_branches := NEW.branch_ids;
    END IF;

    v_scheduled_time := (LPAD(COALESCE(NEW.scheduled_hour, 9)::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (v_schedule::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP + (COALESCE(NEW.deadline_minutes, 60) || ' minutes')::INTERVAL;

    IF v_branches IS NOT NULL AND array_length(v_branches, 1) > 0 THEN
      FOREACH v_branch_id IN ARRAY v_branches LOOP
        INSERT INTO visual_audit_tasks (
          tenant_id, branch_id, section_id, status, scheduled_date,
          scheduled_time, deadline_at, min_photos, notes, created_by
        ) VALUES (
          NEW.tenant_id, v_branch_id, NEW.section_id, 'pending', v_schedule,
          v_scheduled_time, v_deadline_at, COALESCE(NEW.min_photos, 1), 
          NEW.description, NEW.created_by
        );
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- =====================================================
-- 5. GET_TENANT_BRANCHES function
-- =====================================================
DROP FUNCTION IF EXISTS get_tenant_branches(UUID);
DROP FUNCTION IF EXISTS get_tenant_branches;

CREATE OR REPLACE FUNCTION get_tenant_branches(p_tenant_id UUID DEFAULT NULL)
RETURNS TABLE(
  id UUID,
  name TEXT,
  code TEXT,
  city TEXT,
  district TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
  v_role TEXT;
BEGIN
  SELECT u.tenant_id, u.role::text INTO v_tenant_id, v_role
  FROM users u WHERE u.id = auth.uid();

  RETURN QUERY
  SELECT b.id, b.name, b.code, b.city, b.district
  FROM branches b
  WHERE b.tenant_id = COALESCE(p_tenant_id, v_tenant_id)
    AND b.is_active = true
  ORDER BY b.name;
END;
$$;

-- =====================================================
-- 6. NOTIFICATION FUNCTIONS - FIX role comparisons
-- =====================================================

-- send_notification_to_branch
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

-- notify_visual_audit_task_created
CREATE OR REPLACE FUNCTION notify_visual_audit_task_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
  v_section_name text;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM branches WHERE id = NEW.branch_id;
  SELECT name INTO v_section_name FROM visual_audit_sections WHERE id = NEW.section_id;

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

-- notify_visual_audit_photo_uploaded
CREATE OR REPLACE FUNCTION notify_visual_audit_photo_uploaded()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task RECORD;
  v_uploader_name text;
  v_creator_ids uuid[];
BEGIN
  SELECT t.*, b.name as branch_name, b.tenant_id
  INTO v_task
  FROM visual_audit_tasks t
  JOIN branches b ON b.id = t.branch_id
  WHERE t.id = NEW.task_id;

  IF v_task IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(first_name || ' ' || last_name, 'Personel') INTO v_uploader_name
  FROM users WHERE id = NEW.uploaded_by;

  -- FIX: Use valid role values and ::text cast
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

-- notify_visual_audit_task_completed
CREATE OR REPLACE FUNCTION notify_visual_audit_task_completed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch RECORD;
  v_section_name text;
  v_manager_ids uuid[];
BEGIN
  IF NEW.status != 'completed' OR (OLD IS NOT NULL AND OLD.status = 'completed') THEN
    RETURN NEW;
  END IF;

  SELECT b.*, b.tenant_id INTO v_branch
  FROM branches b WHERE b.id = NEW.branch_id;

  IF v_branch IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT name INTO v_section_name
  FROM visual_audit_sections WHERE id = NEW.section_id;

  -- FIX: Use valid role values and ::text cast
  SELECT array_agg(id)
  INTO v_manager_ids
  FROM users
  WHERE tenant_id = v_branch.tenant_id
    AND role::text IN ('firma_admin', 'bolge_muduru')
    AND is_active = true;

  IF v_manager_ids IS NOT NULL AND array_length(v_manager_ids, 1) > 0 THEN
    PERFORM send_notification(
      v_branch.tenant_id,
      v_manager_ids,
      'visual_audit_completed',
      '✅ Görsel Denetim Tamamlandı',
      format('%s şubesi %s denetimini tamamladı',
        v_branch.name,
        COALESCE(v_section_name, 'Görsel Denetim')
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

-- notify_visual_audit_comment_added
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
  SELECT t.*, b.name as branch_name, b.tenant_id
  INTO v_task
  FROM visual_audit_tasks t
  JOIN branches b ON b.id = t.branch_id
  WHERE t.id = NEW.task_id;

  IF v_task IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(first_name || ' ' || last_name, 'Kullanıcı') INTO v_commenter_name
  FROM users WHERE id = NEW.user_id;

  -- FIX: Use valid role values and ::text cast
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

-- notify_announcement_published
CREATE OR REPLACE FUNCTION notify_announcement_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target_users uuid[];
  v_notification_type text := 'announcement';
  v_title text;
  v_body text;
BEGIN
  IF NEW.is_active = true AND (OLD IS NULL OR OLD.is_active IS NULL OR OLD.is_active = false) THEN
    
    v_title := 'Yeni Duyuru';
    v_body := NEW.title;

    SELECT array_agg(u.id)
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
      );

    IF v_target_users IS NOT NULL AND array_length(v_target_users, 1) > 0 THEN
      PERFORM send_notification(
        NEW.tenant_id,
        v_target_users,
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

-- =====================================================
-- 7. RECREATE ALL TRIGGERS
-- =====================================================
DROP TRIGGER IF EXISTS trg_notify_visual_audit_task_created ON visual_audit_tasks;
CREATE TRIGGER trg_notify_visual_audit_task_created
  AFTER INSERT ON visual_audit_tasks
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_task_created();

DROP TRIGGER IF EXISTS trg_notify_visual_audit_photo_uploaded ON visual_audit_photos;
CREATE TRIGGER trg_notify_visual_audit_photo_uploaded
  AFTER INSERT ON visual_audit_photos
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_photo_uploaded();

DROP TRIGGER IF EXISTS trg_notify_visual_audit_task_completed ON visual_audit_tasks;
CREATE TRIGGER trg_notify_visual_audit_task_completed
  AFTER UPDATE OF status ON visual_audit_tasks
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_task_completed();

DROP TRIGGER IF EXISTS trg_notify_visual_audit_comment_added ON visual_audit_comments;
CREATE TRIGGER trg_notify_visual_audit_comment_added
  AFTER INSERT ON visual_audit_comments
  FOR EACH ROW
  EXECUTE FUNCTION notify_visual_audit_comment_added();

DROP TRIGGER IF EXISTS trigger_notify_announcement_published ON announcements;
CREATE TRIGGER trigger_notify_announcement_published
  AFTER INSERT OR UPDATE OF is_active ON announcements
  FOR EACH ROW
  EXECUTE FUNCTION notify_announcement_published();

-- =====================================================
-- 8. GRANT PERMISSIONS
-- =====================================================
GRANT EXECUTE ON FUNCTION create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_visual_audit_task_with_plan(UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION execute_visual_audit_plan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_tenant_branches(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION send_notification_to_branch(UUID, UUID, TEXT, TEXT, TEXT, JSONB, TEXT[]) TO authenticated;
