-- Fix create_visual_audit_task_with_plan: Add missing start_date and end_date columns
-- Error: null value in column "start_date" violates not-null constraint

DROP FUNCTION IF EXISTS create_visual_audit_task_with_plan(uuid[], uuid[], integer, integer, integer, text, text, integer[]);

CREATE OR REPLACE FUNCTION "public"."create_visual_audit_task_with_plan"(
    "p_section_ids" "uuid"[], 
    "p_branch_ids" "uuid"[] DEFAULT NULL::"uuid"[], 
    "p_scheduled_hour" integer DEFAULT 9, 
    "p_deadline_minutes" integer DEFAULT 60, 
    "p_min_photos" integer DEFAULT 1, 
    "p_notes" "text" DEFAULT NULL::"text", 
    "p_recurrence" "text" DEFAULT 'daily'::"text", 
    "p_recurrence_days" integer[] DEFAULT NULL::integer[],
    "p_start_date" date DEFAULT NULL,
    "p_end_date" date DEFAULT NULL
) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
    v_branch_ids UUID[];
    v_plan_id UUID;
    v_today DATE := CURRENT_DATE;
    v_start_date DATE;
    v_end_date DATE;
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
    v_start_date := COALESCE(p_start_date, CURRENT_DATE);
    v_end_date := COALESCE(p_end_date, CURRENT_DATE + INTERVAL '1 year');

    -- Get section and branch names
    SELECT ARRAY_AGG(s.name) INTO v_section_names
    FROM visual_audit_sections s WHERE s.id = ANY(p_section_ids);
    
    SELECT ARRAY_AGG(b.name) INTO v_branch_names
    FROM branches b WHERE b.id = ANY(v_branch_ids);

    -- Create plan with start_date and end_date
    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, 
        recurrence_days, start_date, end_date, is_active, created_by
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
        COALESCE(p_recurrence_days, '{}'::integer[]),
        v_start_date,
        v_end_date,
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

ALTER FUNCTION "public"."create_visual_audit_task_with_plan"(
    "uuid"[], "uuid"[], integer, integer, integer, "text", "text", integer[], date, date
) OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."create_visual_audit_task_with_plan"(
    "uuid"[], "uuid"[], integer, integer, integer, "text", "text", integer[], date, date
) TO "anon";
GRANT ALL ON FUNCTION "public"."create_visual_audit_task_with_plan"(
    "uuid"[], "uuid"[], integer, integer, integer, "text", "text", integer[], date, date
) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_visual_audit_task_with_plan"(
    "uuid"[], "uuid"[], integer, integer, integer, "text", "text", integer[], date, date
) TO "service_role";
