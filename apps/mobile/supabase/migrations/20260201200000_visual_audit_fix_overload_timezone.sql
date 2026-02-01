-- =====================================================
-- FIX: Function overloading ve timezone sorunları
-- =====================================================

-- 1. Eski fonksiyonları temizle (overloading sorunu)
DROP FUNCTION IF EXISTS create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE, INTEGER);
DROP FUNCTION IF EXISTS create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE, INTEGER, UUID);

-- 2. Tek bir fonksiyon oluştur - tüm parametreler default değerli
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
    v_deadline_at TIMESTAMP; -- TIMESTAMP without time zone kullan
    v_result JSON;
    v_results JSON[] := '{}';
    v_task_id UUID;
BEGIN
    -- Get current user's tenant
    SELECT u.tenant_id, u.id INTO v_tenant_id, v_user_id 
    FROM users u WHERE u.id = auth.uid();
    
    IF v_tenant_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
    END IF;

    -- Validate sections
    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir bölüm seçmelisiniz');
    END IF;

    -- Get branch IDs (if null, get all active branches for tenant)
    IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.active = true;
    ELSE
        v_branch_ids := p_branch_ids;
    END IF;

    IF v_branch_ids IS NULL OR array_length(v_branch_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Aktif şube bulunamadı');
    END IF;

    -- Calculate times - timezone olmadan
    v_scheduled_time := (LPAD(p_scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (p_scheduled_date::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP + (p_deadline_minutes || ' minutes')::INTERVAL;

    -- Create task for each branch and section combination
    FOREACH v_branch_id IN ARRAY v_branch_ids LOOP
        FOREACH v_section_id IN ARRAY p_section_ids LOOP
            INSERT INTO visual_audit_tasks (
                tenant_id,
                branch_id,
                section_id,
                status,
                scheduled_date,
                scheduled_time,
                deadline_at,
                min_photos,
                notes,
                created_by,
                plan_id
            ) VALUES (
                v_tenant_id,
                v_branch_id,
                v_section_id,
                'pending',
                p_scheduled_date,
                v_scheduled_time,
                v_deadline_at,
                p_min_photos,
                p_note,
                v_user_id,
                p_plan_id
            )
            RETURNING id INTO v_task_id;

            -- Get branch and section names for response
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

-- 3. create_visual_audit_task_with_plan fonksiyonunu da güncelle
CREATE OR REPLACE FUNCTION create_visual_audit_task_with_plan(
    p_section_ids UUID[],
    p_branch_ids UUID[] DEFAULT NULL,
    p_scheduled_hour INTEGER DEFAULT 9,
    p_deadline_minutes INTEGER DEFAULT 60,
    p_min_photos INTEGER DEFAULT 1,
    p_notes TEXT DEFAULT NULL,
    p_recurrence TEXT DEFAULT 'daily',
    p_recurrence_days INTEGER[] DEFAULT '{}',
    p_recurrence_weeks INTEGER DEFAULT 2
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
    v_plan_id UUID;
    v_branch_ids UUID[];
    v_start_date DATE := CURRENT_DATE;
    v_end_date DATE;
    v_current_date DATE;
    v_day_of_week INTEGER;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMP; -- TIMESTAMP without time zone
    v_branch_id UUID;
    v_section_id UUID;
    v_tasks_created INTEGER := 0;
    v_plan_name TEXT;
    v_section_names TEXT;
BEGIN
    -- Get user info
    SELECT u.tenant_id, u.id INTO v_tenant_id, v_user_id 
    FROM users u WHERE u.id = auth.uid();
    
    IF v_tenant_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
    END IF;
    
    -- Validate sections
    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir bölüm seçmelisiniz');
    END IF;
    
    -- Get branch IDs
    IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.active = true;
    ELSE
        v_branch_ids := p_branch_ids;
    END IF;
    
    -- Calculate end date
    v_end_date := v_start_date + (p_recurrence_weeks * 7 - 1);
    
    -- Generate plan name from section names
    SELECT STRING_AGG(s.name, ' + ' ORDER BY s.name) INTO v_section_names
    FROM visual_audit_sections s WHERE s.id = ANY(p_section_ids);
    
    v_plan_name := v_section_names || ' - ' || 
        CASE 
            WHEN p_recurrence = 'daily' THEN 'Her Gün'
            ELSE (
                SELECT STRING_AGG(
                    CASE d 
                        WHEN 0 THEN 'Paz'
                        WHEN 1 THEN 'Pzt'
                        WHEN 2 THEN 'Sal'
                        WHEN 3 THEN 'Çar'
                        WHEN 4 THEN 'Per'
                        WHEN 5 THEN 'Cum'
                        WHEN 6 THEN 'Cmt'
                    END, '/' ORDER BY d
                ) FROM unnest(p_recurrence_days) d
            )
        END || ' ' || LPAD(p_scheduled_hour::TEXT, 2, '0') || ':00';
    
    -- Create plan
    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, recurrence_days,
        start_date, end_date, created_by
    ) VALUES (
        v_tenant_id, v_plan_name, p_section_ids, v_branch_ids, p_scheduled_hour,
        p_deadline_minutes, p_min_photos, p_notes, p_recurrence, p_recurrence_days,
        v_start_date, v_end_date, v_user_id
    ) RETURNING id INTO v_plan_id;
    
    -- Calculate scheduled time - timezone olmadan
    v_scheduled_time := (LPAD(p_scheduled_hour::TEXT, 2, '0') || ':00:00')::TIME;
    
    -- Generate tasks for each date in range
    v_current_date := v_start_date;
    WHILE v_current_date <= v_end_date LOOP
        v_day_of_week := EXTRACT(DOW FROM v_current_date)::INTEGER;
        
        -- Check if this day should have tasks
        IF p_recurrence = 'daily' OR (p_recurrence = 'weekly' AND v_day_of_week = ANY(p_recurrence_days)) THEN
            -- TIMESTAMP without timezone kullan
            v_deadline_at := (v_current_date::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP + (p_deadline_minutes || ' minutes')::INTERVAL;
            
            -- Create tasks for each branch and section
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
        'plan_name', v_plan_name,
        'tasks_created', v_tasks_created
    );
END;
$$;

-- 4. deadline_at kolonunun tipini kontrol et ve düzelt
-- Eğer TIMESTAMPTZ ise TIMESTAMP'e çevir
DO $$
BEGIN
    -- Mevcut görevlerin deadline_at değerlerini düzelt (UTC offset'i kaldır)
    UPDATE visual_audit_tasks 
    SET deadline_at = deadline_at AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Istanbul'
    WHERE deadline_at IS NOT NULL;
EXCEPTION
    WHEN OTHERS THEN
        -- Hata olursa sessizce geç
        NULL;
END $$;

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE, INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_visual_audit_task_with_plan(UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], INTEGER) TO authenticated;
