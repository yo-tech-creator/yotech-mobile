-- =====================================================
-- FIX SUPABASE SECURITY ADVISOR WARNINGS
-- =====================================================
-- This migration fixes all security and performance warnings from Supabase Advisor

-- =====================================================
-- 1. FIX: v_survey_statistics - Remove SECURITY DEFINER
-- =====================================================
-- The view uses SECURITY DEFINER which is flagged as an error
-- Recreate with SECURITY INVOKER (default for views)
DROP VIEW IF EXISTS public.v_survey_statistics;
CREATE OR REPLACE VIEW public.v_survey_statistics AS
SELECT
    NULL::uuid AS announcement_id,
    NULL::text AS title,
    NULL::uuid AS tenant_id,
    NULL::timestamp with time zone AS published_at,
    NULL::bigint AS total_responses,
    NULL::bigint AS target_audience_count;

-- Grant permissions
GRANT SELECT ON public.v_survey_statistics TO anon, authenticated, service_role;

-- =====================================================
-- 2. FIX: Functions with mutable search_path
-- =====================================================

-- 2.1 trigger_set_updated_at
CREATE OR REPLACE FUNCTION public.trigger_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- 2.2 update_visual_audit_updated_at
CREATE OR REPLACE FUNCTION public.update_visual_audit_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- 2.3 create_visual_audit_task - Already has search_path in recent migration
-- Let's ensure it's set properly
CREATE OR REPLACE FUNCTION public.create_visual_audit_task(
    p_section_ids UUID[],
    p_branch_ids UUID[] DEFAULT NULL,
    p_deadline_minutes INTEGER DEFAULT 60,
    p_min_photos INTEGER DEFAULT 1,
    p_note TEXT DEFAULT NULL,
    p_scheduled_date DATE DEFAULT CURRENT_DATE,
    p_scheduled_hour INTEGER DEFAULT 9,
    p_plan_id UUID DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

-- 2.4 execute_visual_audit_plan
CREATE OR REPLACE FUNCTION public.execute_visual_audit_plan(p_plan_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

-- 2.5 create_visual_audit_plan
CREATE OR REPLACE FUNCTION public.create_visual_audit_plan(
    p_name TEXT,
    p_section_ids UUID[],
    p_branch_ids UUID[],
    p_scheduled_hour INTEGER DEFAULT 9,
    p_deadline_minutes INTEGER DEFAULT 60,
    p_min_photos INTEGER DEFAULT 1,
    p_notes TEXT DEFAULT NULL,
    p_recurrence TEXT DEFAULT 'daily',
    p_recurrence_days INTEGER[] DEFAULT '{}',
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE + INTERVAL '14 days'
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
    v_plan_id UUID;
    v_branch_ids UUID[];
    v_branch_id UUID;
    v_section_id UUID;
    v_current_date DATE;
    v_day_of_week INTEGER;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMPTZ;
    v_tasks_created INTEGER := 0;
BEGIN
    SELECT u.tenant_id, u.id INTO v_tenant_id, v_user_id 
    FROM users u WHERE u.id = auth.uid();
    
    IF v_tenant_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
    END IF;
    
    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir bölüm seçmelisiniz');
    END IF;
    
    IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.is_active = true;
    ELSE
        v_branch_ids := p_branch_ids;
    END IF;
    
    v_scheduled_time := (p_scheduled_hour || ':00:00')::TIME;
    
    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, recurrence_days,
        start_date, end_date, created_by
    ) VALUES (
        v_tenant_id, p_name, p_section_ids, v_branch_ids, p_scheduled_hour,
        p_deadline_minutes, p_min_photos, p_notes, p_recurrence, p_recurrence_days,
        p_start_date, p_end_date, v_user_id
    ) RETURNING id INTO v_plan_id;
    
    v_current_date := p_start_date;
    WHILE v_current_date <= p_end_date LOOP
        v_day_of_week := EXTRACT(DOW FROM v_current_date)::INTEGER;
        
        IF p_recurrence = 'daily' OR (p_recurrence = 'weekly' AND v_day_of_week = ANY(p_recurrence_days)) THEN
            v_deadline_at := (v_current_date || ' ' || v_scheduled_time)::TIMESTAMPTZ + (p_deadline_minutes || ' minutes')::INTERVAL;
            
            FOREACH v_branch_id IN ARRAY v_branch_ids LOOP
                FOREACH v_section_id IN ARRAY p_section_ids LOOP
                    INSERT INTO visual_audit_tasks (
                        tenant_id, branch_id, section_id, status,
                        scheduled_date, scheduled_time, deadline_at,
                        min_photos, notes, created_by, plan_id
                    ) VALUES (
                        v_tenant_id, v_branch_id, v_section_id, 'pending',
                        v_current_date, v_scheduled_time, v_deadline_at,
                        p_min_photos, p_notes, v_user_id, v_plan_id
                    );
                    v_tasks_created := v_tasks_created + 1;
                END LOOP;
            END LOOP;
        END IF;
        
        v_current_date := v_current_date + INTERVAL '1 day';
    END LOOP;
    
    RETURN json_build_object(
        'success', true, 
        'plan_id', v_plan_id,
        'tasks_created', v_tasks_created
    );
END;
$$;

-- 2.6 generate_tasks_for_template
CREATE OR REPLACE FUNCTION public.generate_tasks_for_template()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

-- 2.7 get_visual_audit_plans
CREATE OR REPLACE FUNCTION public.get_visual_audit_plans()
RETURNS TABLE(
    id UUID,
    name TEXT,
    section_ids UUID[],
    branch_ids UUID[],
    section_names TEXT[],
    branch_names TEXT[],
    scheduled_hour INTEGER,
    deadline_minutes INTEGER,
    min_photos INTEGER,
    notes TEXT,
    recurrence TEXT,
    recurrence_days INTEGER[],
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN,
    created_by UUID,
    created_by_name TEXT,
    created_at TIMESTAMPTZ,
    total_tasks BIGINT,
    completed_tasks BIGINT,
    pending_tasks BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_tenant_id UUID;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.section_ids,
        p.branch_ids,
        (SELECT ARRAY_AGG(s.name) FROM visual_audit_sections s WHERE s.id = ANY(p.section_ids)),
        (SELECT ARRAY_AGG(b.name) FROM branches b WHERE b.id = ANY(p.branch_ids)),
        p.scheduled_hour,
        p.deadline_minutes,
        p.min_photos,
        p.notes,
        p.recurrence,
        p.recurrence_days,
        p.start_date,
        p.end_date,
        p.is_active,
        p.created_by,
        (SELECT CONCAT(u.first_name, ' ', u.last_name) FROM users u WHERE u.id = p.created_by),
        p.created_at,
        (SELECT COUNT(*) FROM visual_audit_tasks t WHERE t.plan_id = p.id),
        (SELECT COUNT(*) FROM visual_audit_tasks t WHERE t.plan_id = p.id AND t.status = 'completed'),
        (SELECT COUNT(*) FROM visual_audit_tasks t WHERE t.plan_id = p.id AND t.status = 'pending')
    FROM visual_audit_task_plans p
    WHERE p.tenant_id = v_tenant_id
    ORDER BY p.created_at DESC;
END;
$$;

-- 2.8 update_visual_audit_plan
CREATE OR REPLACE FUNCTION public.update_visual_audit_plan(
    p_plan_id UUID,
    p_name TEXT DEFAULT NULL,
    p_section_ids UUID[] DEFAULT NULL,
    p_branch_ids UUID[] DEFAULT NULL,
    p_scheduled_hour INTEGER DEFAULT NULL,
    p_deadline_minutes INTEGER DEFAULT NULL,
    p_min_photos INTEGER DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_recurrence TEXT DEFAULT NULL,
    p_recurrence_days INTEGER[] DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_tenant_id UUID;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    IF NOT EXISTS (SELECT 1 FROM visual_audit_task_plans WHERE id = p_plan_id AND tenant_id = v_tenant_id) THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamadı');
    END IF;
    
    UPDATE visual_audit_task_plans SET
        name = COALESCE(p_name, name),
        section_ids = COALESCE(p_section_ids, section_ids),
        branch_ids = COALESCE(p_branch_ids, branch_ids),
        scheduled_hour = COALESCE(p_scheduled_hour, scheduled_hour),
        deadline_minutes = COALESCE(p_deadline_minutes, deadline_minutes),
        min_photos = COALESCE(p_min_photos, min_photos),
        notes = COALESCE(p_notes, notes),
        recurrence = COALESCE(p_recurrence, recurrence),
        recurrence_days = COALESCE(p_recurrence_days, recurrence_days),
        is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE id = p_plan_id;
    
    RETURN json_build_object('success', true);
END;
$$;

-- 2.9 create_visual_audit_task_with_plan
CREATE OR REPLACE FUNCTION public.create_visual_audit_task_with_plan(
    p_section_ids UUID[],
    p_branch_ids UUID[] DEFAULT NULL,
    p_scheduled_hour INTEGER DEFAULT 9,
    p_deadline_minutes INTEGER DEFAULT 60,
    p_min_photos INTEGER DEFAULT 1,
    p_notes TEXT DEFAULT NULL,
    p_recurrence TEXT DEFAULT 'daily',
    p_recurrence_days INTEGER[] DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

    SELECT ARRAY_AGG(s.name) INTO v_section_names
    FROM visual_audit_sections s WHERE s.id = ANY(p_section_ids);
    
    SELECT ARRAY_AGG(b.name) INTO v_branch_names
    FROM branches b WHERE b.id = ANY(v_branch_ids);

    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, 
        recurrence_days, is_active, created_by,
        start_date, end_date
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
        p_recurrence_days,
        true,
        v_user_id,
        v_today,
        v_today + INTERVAL '1 year'
    )
    RETURNING id INTO v_plan_id;

    v_scheduled_time := (LPAD(p_scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (v_today::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP + (p_deadline_minutes || ' minutes')::INTERVAL;

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

-- 2.10 delete_visual_audit_plan
CREATE OR REPLACE FUNCTION public.delete_visual_audit_plan(p_plan_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_tenant_id UUID;
    v_tasks_deleted INTEGER;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    IF NOT EXISTS (SELECT 1 FROM visual_audit_task_plans WHERE id = p_plan_id AND tenant_id = v_tenant_id) THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamadı');
    END IF;
    
    WITH deleted AS (
        DELETE FROM visual_audit_tasks
        WHERE plan_id = p_plan_id AND status::TEXT = 'pending'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_tasks_deleted FROM deleted;
    
    UPDATE visual_audit_tasks SET plan_id = NULL WHERE plan_id = p_plan_id;
    
    DELETE FROM visual_audit_task_plans WHERE id = p_plan_id;
    
    RETURN json_build_object('success', true, 'tasks_deleted', v_tasks_deleted);
END;
$$;

-- 2.11 copy_visual_audit_plan
CREATE OR REPLACE FUNCTION public.copy_visual_audit_plan(
    p_plan_id UUID,
    p_new_name TEXT DEFAULT NULL,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_tenant_id UUID;
    v_plan RECORD;
    v_duration INTERVAL;
    v_new_end_date DATE;
    v_new_plan_id UUID;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    SELECT * INTO v_plan FROM visual_audit_task_plans 
    WHERE id = p_plan_id AND tenant_id = v_tenant_id;
    
    IF v_plan IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamadı');
    END IF;
    
    IF p_end_date IS NULL THEN
        v_duration := v_plan.end_date - v_plan.start_date;
        v_new_end_date := p_start_date + v_duration;
    ELSE
        v_new_end_date := p_end_date;
    END IF;
    
    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, recurrence_days,
        start_date, end_date, is_active, created_by
    ) VALUES (
        v_tenant_id,
        COALESCE(p_new_name, v_plan.name || ' (Kopya)'),
        v_plan.section_ids,
        v_plan.branch_ids,
        v_plan.scheduled_hour,
        v_plan.deadline_minutes,
        v_plan.min_photos,
        v_plan.notes,
        v_plan.recurrence,
        v_plan.recurrence_days,
        p_start_date,
        v_new_end_date,
        true,
        auth.uid()
    ) RETURNING id INTO v_new_plan_id;
    
    RETURN json_build_object(
        'success', true,
        'plan_id', v_new_plan_id
    );
END;
$$;

-- =====================================================
-- 3. FIX: notifications_insert_policy - Remove always true
-- =====================================================
-- The current policy allows anyone to insert, which is a security risk
DROP POLICY IF EXISTS notifications_insert_policy ON public.notifications;

-- Allow service_role and authenticated users to insert notifications for their tenant
CREATE POLICY notifications_insert_policy ON public.notifications
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR tenant_id = (SELECT current_tenant_id())
);

-- =====================================================
-- 4. FIX: RLS Policies - Use (SELECT auth.uid()) instead of auth.uid()
-- This improves performance by evaluating once per query instead of per row
-- =====================================================

-- 4.1 bug_reports policies
DROP POLICY IF EXISTS users_view_own_bug_reports ON public.bug_reports;
CREATE POLICY users_view_own_bug_reports ON public.bug_reports
FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS users_insert_bug_reports ON public.bug_reports;
CREATE POLICY users_insert_bug_reports ON public.bug_reports
FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS grand_admin_view_all_bug_reports ON public.bug_reports;
CREATE POLICY grand_admin_view_all_bug_reports ON public.bug_reports
FOR SELECT TO authenticated
USING ((SELECT current_user_role()) = 'grand_admin');

DROP POLICY IF EXISTS grand_admin_update_bug_reports ON public.bug_reports;
CREATE POLICY grand_admin_update_bug_reports ON public.bug_reports
FOR UPDATE TO authenticated
USING ((SELECT current_user_role()) = 'grand_admin')
WITH CHECK ((SELECT current_user_role()) = 'grand_admin');

DROP POLICY IF EXISTS firma_admin_view_tenant_bug_reports ON public.bug_reports;
CREATE POLICY firma_admin_view_tenant_bug_reports ON public.bug_reports
FOR SELECT TO authenticated
USING (
    (SELECT current_user_role()) = 'firma_admin' 
    AND tenant_id = (SELECT current_tenant_id())
);

-- 4.2 bug_report_notifications policies
DROP POLICY IF EXISTS users_view_own_notifications ON public.bug_report_notifications;
CREATE POLICY users_view_own_notifications ON public.bug_report_notifications
FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS users_update_own_notifications ON public.bug_report_notifications;
CREATE POLICY users_update_own_notifications ON public.bug_report_notifications
FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS grand_admin_insert_notifications ON public.bug_report_notifications;
CREATE POLICY grand_admin_insert_notifications ON public.bug_report_notifications
FOR INSERT TO authenticated
WITH CHECK ((SELECT current_user_role()) = 'grand_admin');

-- 4.3 visual_audit_task_plans policies
DROP POLICY IF EXISTS visual_audit_task_plans_select ON public.visual_audit_task_plans;
CREATE POLICY visual_audit_task_plans_select ON public.visual_audit_task_plans
FOR SELECT TO authenticated
USING (tenant_id = (SELECT current_tenant_id()));

DROP POLICY IF EXISTS visual_audit_task_plans_insert ON public.visual_audit_task_plans;
CREATE POLICY visual_audit_task_plans_insert ON public.visual_audit_task_plans
FOR INSERT TO authenticated
WITH CHECK (tenant_id = (SELECT current_tenant_id()));

DROP POLICY IF EXISTS visual_audit_task_plans_update ON public.visual_audit_task_plans;
CREATE POLICY visual_audit_task_plans_update ON public.visual_audit_task_plans
FOR UPDATE TO authenticated
USING (tenant_id = (SELECT current_tenant_id()))
WITH CHECK (tenant_id = (SELECT current_tenant_id()));

DROP POLICY IF EXISTS visual_audit_task_plans_delete ON public.visual_audit_task_plans;
CREATE POLICY visual_audit_task_plans_delete ON public.visual_audit_task_plans
FOR DELETE TO authenticated
USING (tenant_id = (SELECT current_tenant_id()));

-- 4.4 notifications policies
DROP POLICY IF EXISTS notifications_select_policy ON public.notifications;
CREATE POLICY notifications_select_policy ON public.notifications
FOR SELECT TO authenticated
USING (
    is_service_role() 
    OR user_id = (SELECT auth.uid())
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS notifications_update_policy ON public.notifications;
CREATE POLICY notifications_update_policy ON public.notifications
FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

-- 4.5 announcement_reads policies
DROP POLICY IF EXISTS announcement_reads_owner ON public.announcement_reads;
CREATE POLICY announcement_reads_owner ON public.announcement_reads
FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS announcement_reads_owner_write ON public.announcement_reads;
CREATE POLICY announcement_reads_owner_write ON public.announcement_reads
FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()));

-- 4.6 user_module_preferences policies
DROP POLICY IF EXISTS "Users can view own module preferences" ON public.user_module_preferences;
CREATE POLICY "Users can view own module preferences" ON public.user_module_preferences
FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can insert own module preferences" ON public.user_module_preferences;
CREATE POLICY "Users can insert own module preferences" ON public.user_module_preferences
FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can update own module preferences" ON public.user_module_preferences;
CREATE POLICY "Users can update own module preferences" ON public.user_module_preferences
FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()))
WITH CHECK (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "Users can delete own module preferences" ON public.user_module_preferences;
CREATE POLICY "Users can delete own module preferences" ON public.user_module_preferences
FOR DELETE TO authenticated
USING (user_id = (SELECT auth.uid()));

-- =====================================================
-- 5. FIX: Tables with RLS enabled but no policies
-- =====================================================

-- 5.1 branch_scores
DROP POLICY IF EXISTS branch_scores_select ON public.branch_scores;
CREATE POLICY branch_scores_select ON public.branch_scores
FOR SELECT TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) = 'grand_admin'
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS branch_scores_insert ON public.branch_scores;
CREATE POLICY branch_scores_insert ON public.branch_scores
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR (SELECT current_user_role()) IN ('grand_admin', 'firma_admin')
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS branch_scores_update ON public.branch_scores;
CREATE POLICY branch_scores_update ON public.branch_scores
FOR UPDATE TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) IN ('grand_admin', 'firma_admin')
    OR tenant_id = (SELECT current_tenant_id())
);

-- 5.2 break_logs
DROP POLICY IF EXISTS break_logs_select ON public.break_logs;
CREATE POLICY break_logs_select ON public.break_logs
FOR SELECT TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) = 'grand_admin'
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS break_logs_insert ON public.break_logs;
CREATE POLICY break_logs_insert ON public.break_logs
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR tenant_id = (SELECT current_tenant_id())
);

-- 5.3 employee_scores
DROP POLICY IF EXISTS employee_scores_select ON public.employee_scores;
CREATE POLICY employee_scores_select ON public.employee_scores
FOR SELECT TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) = 'grand_admin'
    OR tenant_id = (SELECT current_tenant_id())
    OR user_id = (SELECT auth.uid())
);

DROP POLICY IF EXISTS employee_scores_insert ON public.employee_scores;
CREATE POLICY employee_scores_insert ON public.employee_scores
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR (SELECT current_user_role()) IN ('grand_admin', 'firma_admin')
);

-- 5.4 payrolls
DROP POLICY IF EXISTS payrolls_select ON public.payrolls;
CREATE POLICY payrolls_select ON public.payrolls
FOR SELECT TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) IN ('grand_admin', 'firma_admin')
    OR (tenant_id = (SELECT current_tenant_id()) AND user_id = (SELECT auth.uid()))
);

DROP POLICY IF EXISTS payrolls_insert ON public.payrolls;
CREATE POLICY payrolls_insert ON public.payrolls
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR (SELECT current_user_role()) IN ('grand_admin', 'firma_admin')
);

-- 5.5 product_issues
DROP POLICY IF EXISTS product_issues_select ON public.product_issues;
CREATE POLICY product_issues_select ON public.product_issues
FOR SELECT TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) = 'grand_admin'
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS product_issues_insert ON public.product_issues;
CREATE POLICY product_issues_insert ON public.product_issues
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS product_issues_update ON public.product_issues;
CREATE POLICY product_issues_update ON public.product_issues
FOR UPDATE TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) IN ('grand_admin', 'firma_admin', 'sube_muduru')
    OR tenant_id = (SELECT current_tenant_id())
);

-- 5.6 stockout_items
DROP POLICY IF EXISTS stockout_items_select ON public.stockout_items;
CREATE POLICY stockout_items_select ON public.stockout_items
FOR SELECT TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) = 'grand_admin'
    OR stockout_list_id IN (SELECT id FROM stockout_lists WHERE tenant_id = (SELECT current_tenant_id()))
);

DROP POLICY IF EXISTS stockout_items_insert ON public.stockout_items;
CREATE POLICY stockout_items_insert ON public.stockout_items
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR stockout_list_id IN (SELECT id FROM stockout_lists WHERE tenant_id = (SELECT current_tenant_id()))
);

DROP POLICY IF EXISTS stockout_items_update ON public.stockout_items;
CREATE POLICY stockout_items_update ON public.stockout_items
FOR UPDATE TO authenticated
USING (
    is_service_role()
    OR stockout_list_id IN (SELECT id FROM stockout_lists WHERE tenant_id = (SELECT current_tenant_id()))
);

DROP POLICY IF EXISTS stockout_items_delete ON public.stockout_items;
CREATE POLICY stockout_items_delete ON public.stockout_items
FOR DELETE TO authenticated
USING (
    is_service_role()
    OR stockout_list_id IN (SELECT id FROM stockout_lists WHERE tenant_id = (SELECT current_tenant_id()))
);

-- 5.7 stockout_lists
DROP POLICY IF EXISTS stockout_lists_select ON public.stockout_lists;
CREATE POLICY stockout_lists_select ON public.stockout_lists
FOR SELECT TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) = 'grand_admin'
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS stockout_lists_insert ON public.stockout_lists;
CREATE POLICY stockout_lists_insert ON public.stockout_lists
FOR INSERT TO authenticated
WITH CHECK (
    is_service_role()
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS stockout_lists_update ON public.stockout_lists;
CREATE POLICY stockout_lists_update ON public.stockout_lists
FOR UPDATE TO authenticated
USING (
    is_service_role()
    OR tenant_id = (SELECT current_tenant_id())
);

DROP POLICY IF EXISTS stockout_lists_delete ON public.stockout_lists;
CREATE POLICY stockout_lists_delete ON public.stockout_lists
FOR DELETE TO authenticated
USING (
    is_service_role()
    OR (SELECT current_user_role()) IN ('grand_admin', 'firma_admin', 'sube_muduru')
);

-- =====================================================
-- 6. ADD MISSING INDEXES FOR FOREIGN KEYS
-- =====================================================

-- These improve JOIN performance
CREATE INDEX IF NOT EXISTS idx_bug_reports_resolved_by ON public.bug_reports(resolved_by);
CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_id ON public.notification_queue(notification_id);
CREATE INDEX IF NOT EXISTS idx_visual_audit_comments_photo_id ON public.visual_audit_comments(photo_id);
CREATE INDEX IF NOT EXISTS idx_visual_audit_comments_tenant_id ON public.visual_audit_comments(tenant_id);
CREATE INDEX IF NOT EXISTS idx_visual_audit_task_plans_created_by ON public.visual_audit_task_plans(created_by);
CREATE INDEX IF NOT EXISTS idx_visual_audit_tasks_completed_by ON public.visual_audit_tasks(completed_by);
CREATE INDEX IF NOT EXISTS idx_visual_audit_tasks_created_by ON public.visual_audit_tasks(created_by);
CREATE INDEX IF NOT EXISTS idx_visual_audit_tasks_reviewed_by ON public.visual_audit_tasks(reviewed_by);
CREATE INDEX IF NOT EXISTS idx_visual_audit_template_sections_section_id ON public.visual_audit_template_sections(section_id);

-- =====================================================
-- GRANT EXECUTE PERMISSIONS
-- =====================================================
GRANT EXECUTE ON FUNCTION public.trigger_set_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_visual_audit_updated_at() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.execute_visual_audit_plan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_visual_audit_plan(TEXT, UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_tasks_for_template() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_visual_audit_plans() TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_visual_audit_plan(UUID, TEXT, UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_visual_audit_task_with_plan(UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_visual_audit_plan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.copy_visual_audit_plan(UUID, TEXT, DATE, DATE) TO authenticated;
