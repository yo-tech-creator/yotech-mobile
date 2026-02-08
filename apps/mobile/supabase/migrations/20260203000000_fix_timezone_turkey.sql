-- =====================================================
-- FIX: Use Turkey timezone for all visual audit functions
-- =====================================================
-- Supabase uses UTC, but Turkey is UTC+3
-- All date calculations should use Turkey timezone

-- =====================================================
-- 1. Update generate_daily_visual_audit_tasks
-- =====================================================
CREATE OR REPLACE FUNCTION public.generate_daily_visual_audit_tasks()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_plan RECORD;
    v_branch_id UUID;
    v_section_id UUID;
    v_today DATE;
    v_day_of_week INTEGER;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMPTZ;
    v_tasks_created INTEGER := 0;
    v_plans_processed INTEGER := 0;
BEGIN
    -- Use Turkey timezone for date calculation
    v_today := (NOW() AT TIME ZONE 'Europe/Istanbul')::DATE;
    v_day_of_week := EXTRACT(DOW FROM v_today)::INTEGER;

    FOR v_plan IN 
        SELECT * FROM visual_audit_task_plans 
        WHERE is_active = true 
        AND v_today >= start_date 
        AND v_today <= end_date
    LOOP
        v_plans_processed := v_plans_processed + 1;
        
        -- Check recurrence rules
        IF v_plan.recurrence = 'daily' OR 
           (v_plan.recurrence = 'weekly' AND v_day_of_week = ANY(v_plan.recurrence_days)) THEN
            
            v_scheduled_time := (LPAD(v_plan.scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
            v_deadline_at := (v_today::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP AT TIME ZONE 'Europe/Istanbul' 
                           + (v_plan.deadline_minutes || ' minutes')::INTERVAL;

            FOREACH v_branch_id IN ARRAY v_plan.branch_ids LOOP
                FOREACH v_section_id IN ARRAY v_plan.section_ids LOOP
                    -- Check if task already exists for today
                    IF NOT EXISTS (
                        SELECT 1 FROM visual_audit_tasks 
                        WHERE plan_id = v_plan.id 
                        AND branch_id = v_branch_id 
                        AND section_id = v_section_id 
                        AND scheduled_date = v_today
                    ) THEN
                        INSERT INTO visual_audit_tasks (
                            tenant_id, branch_id, section_id, status, scheduled_date,
                            scheduled_time, deadline_at, min_photos, notes, created_by, plan_id
                        ) VALUES (
                            v_plan.tenant_id, v_branch_id, v_section_id, 'pending', v_today,
                            v_scheduled_time, v_deadline_at, v_plan.min_photos, 
                            v_plan.notes, v_plan.created_by, v_plan.id
                        );
                        v_tasks_created := v_tasks_created + 1;
                    END IF;
                END LOOP;
            END LOOP;
            
            -- Update last_run_at
            UPDATE visual_audit_task_plans 
            SET last_run_at = NOW() 
            WHERE id = v_plan.id;
        END IF;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'date', v_today,
        'day_of_week', v_day_of_week,
        'plans_processed', v_plans_processed,
        'tasks_created', v_tasks_created,
        'timezone', 'Europe/Istanbul'
    );
END;
$$;

-- =====================================================
-- 2. Update create_visual_audit_task_with_plan
-- =====================================================
DROP FUNCTION IF EXISTS public.create_visual_audit_task_with_plan(UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[]);
DROP FUNCTION IF EXISTS public.create_visual_audit_task_with_plan(UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], DATE, DATE);

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
    v_today DATE;
    v_start_date DATE;
    v_end_date DATE;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMPTZ;
    v_branch_id UUID;
    v_section_id UUID;
    v_section_names TEXT[];
    v_branch_names TEXT[];
BEGIN
    -- Use Turkey timezone
    v_today := (NOW() AT TIME ZONE 'Europe/Istanbul')::DATE;
    
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

    -- Set default dates
    v_start_date := v_today;
    v_end_date := v_today + INTERVAL '1 year';

    -- Get section and branch names
    SELECT ARRAY_AGG(s.name) INTO v_section_names
    FROM visual_audit_sections s WHERE s.id = ANY(p_section_ids);
    
    SELECT ARRAY_AGG(b.name) INTO v_branch_names
    FROM branches b WHERE b.id = ANY(v_branch_ids);

    -- Create plan
    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, 
        recurrence_days, start_date, end_date, is_active, created_by
    ) VALUES (
        v_tenant_id,
        COALESCE(v_section_names[1], 'Görsel Denetim') || ' - ' || to_char(NOW() AT TIME ZONE 'Europe/Istanbul', 'DD.MM.YYYY'),
        p_section_ids,
        v_branch_ids,
        p_scheduled_hour,
        p_deadline_minutes,
        p_min_photos,
        p_notes,
        p_recurrence,
        COALESCE(p_recurrence_days, '{}'::integer[]),
        v_start_date,
        v_end_date,
        true,
        v_user_id
    )
    RETURNING id INTO v_plan_id;

    -- Calculate times with Turkey timezone
    v_scheduled_time := (LPAD(p_scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (v_today::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP AT TIME ZONE 'Europe/Istanbul' 
                   + (p_deadline_minutes || ' minutes')::INTERVAL;

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
        'tasks_created', array_length(v_branch_ids, 1) * array_length(p_section_ids, 1),
        'date', v_today
    );
END;
$$;

-- =====================================================
-- 3. Update execute_visual_audit_plan
-- =====================================================
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
    v_today DATE;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMPTZ;
    v_tasks_created INTEGER := 0;
BEGIN
    -- Use Turkey timezone
    v_today := (NOW() AT TIME ZONE 'Europe/Istanbul')::DATE;
    
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
    v_deadline_at := (v_today::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP AT TIME ZONE 'Europe/Istanbul' 
                   + (v_plan.deadline_minutes || ' minutes')::INTERVAL;

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

    RETURN json_build_object('success', true, 'tasks_created', v_tasks_created, 'date', v_today);
END;
$$;

-- =====================================================
-- 4. Update create_visual_audit_task (single task)
-- =====================================================
CREATE OR REPLACE FUNCTION public.create_visual_audit_task(
    p_section_ids UUID[],
    p_branch_ids UUID[] DEFAULT NULL,
    p_deadline_minutes INTEGER DEFAULT 60,
    p_min_photos INTEGER DEFAULT 1,
    p_note TEXT DEFAULT NULL,
    p_scheduled_date DATE DEFAULT NULL,
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
    v_scheduled_date DATE;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMPTZ;
    v_result JSON;
    v_results JSON[] := '{}';
    v_task_id UUID;
BEGIN
    -- Use Turkey timezone for default date
    v_scheduled_date := COALESCE(p_scheduled_date, (NOW() AT TIME ZONE 'Europe/Istanbul')::DATE);
    
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
    v_deadline_at := (v_scheduled_date::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP AT TIME ZONE 'Europe/Istanbul' 
                   + (p_deadline_minutes || ' minutes')::INTERVAL;

    FOREACH v_branch_id IN ARRAY v_branch_ids LOOP
        FOREACH v_section_id IN ARRAY p_section_ids LOOP
            INSERT INTO visual_audit_tasks (
                tenant_id, branch_id, section_id, status, scheduled_date,
                scheduled_time, deadline_at, min_photos, notes, created_by, plan_id
            ) VALUES (
                v_tenant_id, v_branch_id, v_section_id, 'pending', v_scheduled_date,
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

    RETURN json_build_object('success', true, 'tasks', v_results, 'date', v_scheduled_date);
END;
$$;

-- =====================================================
-- 5. Grant permissions
-- =====================================================
GRANT EXECUTE ON FUNCTION public.generate_daily_visual_audit_tasks() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_visual_audit_task_with_plan(UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.execute_visual_audit_plan(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE, INTEGER, UUID) TO authenticated, service_role;
