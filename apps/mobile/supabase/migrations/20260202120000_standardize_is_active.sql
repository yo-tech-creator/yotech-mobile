-- ============================================================================
-- STANDARDIZATION: Rename all 'active' columns to 'is_active'
-- Tüm tablolarda aktiflik kolonunu 'is_active' olarak standardize et
-- ============================================================================

-- 1. ANNOUNCEMENTS
ALTER TABLE announcements RENAME COLUMN active TO is_active;

-- 2. BRANCHES  
ALTER TABLE branches RENAME COLUMN active TO is_active;

-- 3. FORM_TEMPLATES
ALTER TABLE form_templates RENAME COLUMN active TO is_active;

-- 4. MODULES
ALTER TABLE modules RENAME COLUMN active TO is_active;

-- 5. PRODUCTS
ALTER TABLE products RENAME COLUMN active TO is_active;

-- 6. REGIONS
ALTER TABLE regions RENAME COLUMN active TO is_active;

-- 7. TENANTS
ALTER TABLE tenants RENAME COLUMN active TO is_active;

-- 8. USERS
ALTER TABLE users RENAME COLUMN active TO is_active;

-- ============================================================================
-- FIX: Update all notification trigger functions to use is_active
-- ============================================================================

-- send_notification_to_branch function
CREATE OR REPLACE FUNCTION send_notification_to_branch(
  p_tenant_id uuid,
  p_branch_id uuid,
  p_roles text[],
  p_type notification_type,
  p_title text,
  p_body text,
  p_data jsonb DEFAULT '{}'::jsonb
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
    AND role = ANY(p_roles)
    AND is_active = true;

  IF v_user_ids IS NULL OR array_length(v_user_ids, 1) = 0 THEN
    RETURN jsonb_build_object('success', true, 'message', 'No users found in branch');
  END IF;

  RETURN send_notification(p_tenant_id, v_user_ids, p_type, p_title, p_body, p_data);
END;
$$;

-- notify_announcement_published function
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
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.published_at IS NOT NULL) 
     OR (TG_OP = 'UPDATE' AND OLD.published_at IS NULL AND NEW.published_at IS NOT NULL) THEN
    
    IF NEW.type = 'survey' THEN
      v_notification_type := 'survey';
      v_title := '📊 Yeni Anket: ' || NEW.title;
      v_body := COALESCE(NEW.summary, left(NEW.content, 100));
    ELSE
      v_notification_type := 'announcement';
      v_title := '📢 Yeni Duyuru: ' || NEW.title;
      v_body := COALESCE(NEW.summary, left(NEW.content, 100));
    END IF;

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

-- notify_visual_audit_photo_uploaded function
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

  SELECT full_name INTO v_uploader_name
  FROM users WHERE id = NEW.uploaded_by;

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

-- notify_visual_audit_task_completed function
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

  SELECT name INTO v_section_name
  FROM visual_audit_sections WHERE id = NEW.section_id;

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

-- ============================================================================
-- FIX: Update get_tenant_branches function
-- ============================================================================
DROP FUNCTION IF EXISTS get_tenant_branches(uuid);
CREATE OR REPLACE FUNCTION get_tenant_branches(p_tenant_id uuid)
RETURNS TABLE(id uuid, name text, code text, region_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT b.id, b.name, b.code, b.region_id
  FROM branches b
  WHERE b.tenant_id = p_tenant_id
    AND b.is_active = true
  ORDER BY b.name;
END;
$$;

-- ============================================================================
-- FIX: Update visual audit related functions that use branches.is_active
-- ============================================================================

-- generate_visual_audit_tasks function (if exists, update it)
CREATE OR REPLACE FUNCTION generate_visual_audit_tasks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template RECORD;
  v_branch_id uuid;
  v_section_id uuid;
  v_scheduled_time text;
  v_deadline timestamptz;
  v_task_exists boolean;
BEGIN
  -- Loop through active templates
  FOR v_template IN 
    SELECT * FROM visual_audit_templates
    WHERE is_active = TRUE 
      AND (starts_at IS NULL OR starts_at <= CURRENT_DATE)
      AND (ends_at IS NULL OR ends_at >= CURRENT_DATE)
  LOOP
    -- Check recurrence
    IF v_template.recurrence = 'daily' OR
       (v_template.recurrence = 'weekly' AND EXTRACT(DOW FROM CURRENT_DATE)::int = ANY(v_template.weekly_days)) OR
       (v_template.recurrence = 'monthly' AND EXTRACT(DAY FROM CURRENT_DATE)::int = ANY(v_template.monthly_days))
    THEN
      -- Get target branches
      IF v_template.branch_ids IS NULL THEN
        -- All active branches for tenant
        FOR v_branch_id IN 
          SELECT b.id FROM branches b 
          WHERE b.tenant_id = v_template.tenant_id AND b.is_active = TRUE
        LOOP
          -- Generate tasks for each section and time
          FOREACH v_section_id IN ARRAY v_template.section_ids
          LOOP
            FOREACH v_scheduled_time IN ARRAY v_template.scheduled_times
            LOOP
              v_deadline := (CURRENT_DATE + v_scheduled_time::time + (v_template.deadline_minutes || ' minutes')::interval);
              
              -- Check if task already exists
              SELECT EXISTS(
                SELECT 1 FROM visual_audit_tasks
                WHERE template_id = v_template.id
                  AND branch_id = v_branch_id
                  AND section_id = v_section_id
                  AND scheduled_date = CURRENT_DATE
                  AND scheduled_time = v_scheduled_time::time
              ) INTO v_task_exists;
              
              IF NOT v_task_exists THEN
                INSERT INTO visual_audit_tasks (
                  tenant_id, template_id, branch_id, section_id,
                  scheduled_date, scheduled_time, deadline_at
                ) VALUES (
                  v_template.tenant_id, v_template.id, v_branch_id, v_section_id,
                  CURRENT_DATE, v_scheduled_time::time, v_deadline
                );
              END IF;
            END LOOP;
          END LOOP;
        END LOOP;
      ELSE
        -- Specific branches
        FOREACH v_branch_id IN ARRAY v_template.branch_ids
        LOOP
          FOREACH v_section_id IN ARRAY v_template.section_ids
          LOOP
            FOREACH v_scheduled_time IN ARRAY v_template.scheduled_times
            LOOP
              v_deadline := (CURRENT_DATE + v_scheduled_time::time + (v_template.deadline_minutes || ' minutes')::interval);
              
              SELECT EXISTS(
                SELECT 1 FROM visual_audit_tasks
                WHERE template_id = v_template.id
                  AND branch_id = v_branch_id
                  AND section_id = v_section_id
                  AND scheduled_date = CURRENT_DATE
                  AND scheduled_time = v_scheduled_time::time
              ) INTO v_task_exists;
              
              IF NOT v_task_exists THEN
                INSERT INTO visual_audit_tasks (
                  tenant_id, template_id, branch_id, section_id,
                  scheduled_date, scheduled_time, deadline_at
                ) VALUES (
                  v_template.tenant_id, v_template.id, v_branch_id, v_section_id,
                  CURRENT_DATE, v_scheduled_time::time, v_deadline
                );
              END IF;
            END LOOP;
          END LOOP;
        END LOOP;
      END IF;
    END IF;
  END LOOP;
END;
$$;
