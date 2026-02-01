-- =====================================================
-- VISUAL AUDIT PLANS SYSTEM
-- Tekrar eden görevleri plan olarak saklama ve yönetme
-- =====================================================

-- 1. Plans tablosu
CREATE TABLE IF NOT EXISTS visual_audit_task_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- Otomatik veya manuel isim
    section_ids UUID[] NOT NULL DEFAULT '{}',
    branch_ids UUID[] NOT NULL DEFAULT '{}', -- Boş = tüm şubeler
    scheduled_hour INTEGER NOT NULL DEFAULT 9, -- 0-23 saat
    deadline_minutes INTEGER NOT NULL DEFAULT 60,
    min_photos INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    recurrence TEXT NOT NULL DEFAULT 'daily' CHECK (recurrence IN ('daily', 'weekly')),
    recurrence_days INTEGER[] NOT NULL DEFAULT '{}', -- 0=Pazar, 1=Pazartesi...6=Cumartesi
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Mevcut tasks tablosuna plan_id ekle
ALTER TABLE visual_audit_tasks 
ADD COLUMN IF NOT EXISTS plan_id UUID REFERENCES visual_audit_task_plans(id) ON DELETE SET NULL;

-- 3. Index'ler
CREATE INDEX IF NOT EXISTS idx_visual_audit_task_plans_tenant ON visual_audit_task_plans(tenant_id);
CREATE INDEX IF NOT EXISTS idx_visual_audit_task_plans_active ON visual_audit_task_plans(is_active);
CREATE INDEX IF NOT EXISTS idx_visual_audit_tasks_plan ON visual_audit_tasks(plan_id);

-- 4. RLS
ALTER TABLE visual_audit_task_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "visual_audit_task_plans_select" ON visual_audit_task_plans;
CREATE POLICY "visual_audit_task_plans_select" ON visual_audit_task_plans
    FOR SELECT USING (tenant_id = (SELECT tenant_id FROM users WHERE id = auth.uid()));

DROP POLICY IF EXISTS "visual_audit_task_plans_insert" ON visual_audit_task_plans;
CREATE POLICY "visual_audit_task_plans_insert" ON visual_audit_task_plans
    FOR INSERT WITH CHECK (tenant_id = (SELECT tenant_id FROM users WHERE id = auth.uid()));

DROP POLICY IF EXISTS "visual_audit_task_plans_update" ON visual_audit_task_plans;
CREATE POLICY "visual_audit_task_plans_update" ON visual_audit_task_plans
    FOR UPDATE USING (tenant_id = (SELECT tenant_id FROM users WHERE id = auth.uid()));

DROP POLICY IF EXISTS "visual_audit_task_plans_delete" ON visual_audit_task_plans;
CREATE POLICY "visual_audit_task_plans_delete" ON visual_audit_task_plans
    FOR DELETE USING (tenant_id = (SELECT tenant_id FROM users WHERE id = auth.uid()));

-- =====================================================
-- PLAN FUNCTIONS
-- =====================================================

-- 5. Planları listele
CREATE OR REPLACE FUNCTION get_visual_audit_plans()
RETURNS TABLE (
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
LANGUAGE plpgsql SECURITY DEFINER
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
        -- Section names array
        (SELECT ARRAY_AGG(s.name ORDER BY s.name) 
         FROM visual_audit_sections s 
         WHERE s.id = ANY(p.section_ids)) AS section_names,
        -- Branch names array
        (SELECT ARRAY_AGG(b.name ORDER BY b.name) 
         FROM branches b 
         WHERE b.id = ANY(p.branch_ids)) AS branch_names,
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
        CONCAT(u.first_name, ' ', u.last_name) AS created_by_name,
        p.created_at,
        -- Task counts
        COUNT(t.id) AS total_tasks,
        COUNT(t.id) FILTER (WHERE t.status::TEXT = 'completed') AS completed_tasks,
        COUNT(t.id) FILTER (WHERE t.status::TEXT = 'pending') AS pending_tasks
    FROM visual_audit_task_plans p
    LEFT JOIN users u ON u.id = p.created_by
    LEFT JOIN visual_audit_tasks t ON t.plan_id = p.id
    WHERE p.tenant_id = v_tenant_id
    GROUP BY p.id, u.first_name, u.last_name
    ORDER BY p.created_at DESC;
END;
$$;

-- 6. Plan oluştur ve görevleri oluştur
CREATE OR REPLACE FUNCTION create_visual_audit_plan(
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
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
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
    
    -- Get branch IDs (if empty, get all active branches)
    IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.active = true;
    ELSE
        v_branch_ids := p_branch_ids;
    END IF;
    
    -- Calculate scheduled time
    v_scheduled_time := (p_scheduled_hour || ':00:00')::TIME;
    
    -- Create plan
    INSERT INTO visual_audit_task_plans (
        tenant_id, name, section_ids, branch_ids, scheduled_hour,
        deadline_minutes, min_photos, notes, recurrence, recurrence_days,
        start_date, end_date, created_by
    ) VALUES (
        v_tenant_id, p_name, p_section_ids, v_branch_ids, p_scheduled_hour,
        p_deadline_minutes, p_min_photos, p_notes, p_recurrence, p_recurrence_days,
        p_start_date, p_end_date, v_user_id
    ) RETURNING id INTO v_plan_id;
    
    -- Generate tasks for each date in range
    v_current_date := p_start_date;
    WHILE v_current_date <= p_end_date LOOP
        v_day_of_week := EXTRACT(DOW FROM v_current_date)::INTEGER; -- 0=Sunday
        
        -- Check if this day should have tasks
        IF p_recurrence = 'daily' OR (p_recurrence = 'weekly' AND v_day_of_week = ANY(p_recurrence_days)) THEN
            -- Calculate deadline for this date
            v_deadline_at := (v_current_date || ' ' || v_scheduled_time)::TIMESTAMPTZ + (p_deadline_minutes || ' minutes')::INTERVAL;
            
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
        'tasks_created', v_tasks_created
    );
END;
$$;

-- 7. Planı güncelle
CREATE OR REPLACE FUNCTION update_visual_audit_plan(
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
    p_end_date DATE DEFAULT NULL,
    p_is_active BOOLEAN DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id UUID;
    v_plan RECORD;
    v_new_branch_ids UUID[];
    v_removed_branches UUID[];
    v_added_branches UUID[];
    v_branch_id UUID;
    v_section_id UUID;
    v_current_date DATE;
    v_day_of_week INTEGER;
    v_scheduled_time TIME;
    v_deadline_at TIMESTAMPTZ;
    v_tasks_created INTEGER := 0;
    v_tasks_deleted INTEGER := 0;
    v_tasks_updated INTEGER := 0;
BEGIN
    -- Get user info
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    -- Get current plan
    SELECT * INTO v_plan FROM visual_audit_task_plans 
    WHERE id = p_plan_id AND tenant_id = v_tenant_id;
    
    IF v_plan IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamadı');
    END IF;
    
    -- Use new values or keep existing
    p_name := COALESCE(p_name, v_plan.name);
    p_section_ids := COALESCE(p_section_ids, v_plan.section_ids);
    p_scheduled_hour := COALESCE(p_scheduled_hour, v_plan.scheduled_hour);
    p_deadline_minutes := COALESCE(p_deadline_minutes, v_plan.deadline_minutes);
    p_min_photos := COALESCE(p_min_photos, v_plan.min_photos);
    p_notes := COALESCE(p_notes, v_plan.notes);
    p_recurrence := COALESCE(p_recurrence, v_plan.recurrence);
    p_recurrence_days := COALESCE(p_recurrence_days, v_plan.recurrence_days);
    p_end_date := COALESCE(p_end_date, v_plan.end_date);
    p_is_active := COALESCE(p_is_active, v_plan.is_active);
    
    -- Handle branch changes
    IF p_branch_ids IS NULL THEN
        v_new_branch_ids := v_plan.branch_ids;
    ELSE
        v_new_branch_ids := p_branch_ids;
        
        -- Find removed branches
        SELECT ARRAY_AGG(b) INTO v_removed_branches
        FROM unnest(v_plan.branch_ids) b
        WHERE b != ALL(p_branch_ids);
        
        -- Find added branches  
        SELECT ARRAY_AGG(b) INTO v_added_branches
        FROM unnest(p_branch_ids) b
        WHERE b != ALL(v_plan.branch_ids);
        
        -- Delete pending tasks for removed branches
        IF v_removed_branches IS NOT NULL AND array_length(v_removed_branches, 1) > 0 THEN
            WITH deleted AS (
                DELETE FROM visual_audit_tasks
                WHERE plan_id = p_plan_id 
                AND branch_id = ANY(v_removed_branches)
                AND status::TEXT = 'pending'
                AND scheduled_date >= CURRENT_DATE
                RETURNING id
            )
            SELECT COUNT(*) INTO v_tasks_deleted FROM deleted;
        END IF;
        
        -- Create tasks for added branches (for remaining dates)
        IF v_added_branches IS NOT NULL AND array_length(v_added_branches, 1) > 0 THEN
            v_scheduled_time := (p_scheduled_hour || ':00:00')::TIME;
            v_current_date := GREATEST(CURRENT_DATE, v_plan.start_date);
            
            WHILE v_current_date <= p_end_date LOOP
                v_day_of_week := EXTRACT(DOW FROM v_current_date)::INTEGER;
                
                IF p_recurrence = 'daily' OR (p_recurrence = 'weekly' AND v_day_of_week = ANY(p_recurrence_days)) THEN
                    v_deadline_at := (v_current_date || ' ' || v_scheduled_time)::TIMESTAMPTZ + (p_deadline_minutes || ' minutes')::INTERVAL;
                    
                    FOREACH v_branch_id IN ARRAY v_added_branches LOOP
                        FOREACH v_section_id IN ARRAY p_section_ids LOOP
                            INSERT INTO visual_audit_tasks (
                                tenant_id, branch_id, section_id, status,
                                scheduled_date, scheduled_time, deadline_at,
                                min_photos, notes, created_by, plan_id
                            ) VALUES (
                                v_tenant_id, v_branch_id, v_section_id, 'pending',
                                v_current_date, v_scheduled_time, v_deadline_at,
                                p_min_photos, p_notes, auth.uid(), p_plan_id
                            );
                            v_tasks_created := v_tasks_created + 1;
                        END LOOP;
                    END LOOP;
                END IF;
                
                v_current_date := v_current_date + INTERVAL '1 day';
            END LOOP;
        END IF;
    END IF;
    
    -- Update pending tasks with new values
    WITH updated AS (
        UPDATE visual_audit_tasks
        SET 
            min_photos = p_min_photos,
            notes = p_notes,
            scheduled_time = (p_scheduled_hour || ':00:00')::TIME,
            deadline_at = (scheduled_date || ' ' || (p_scheduled_hour || ':00:00')::TIME)::TIMESTAMPTZ + (p_deadline_minutes || ' minutes')::INTERVAL
        WHERE plan_id = p_plan_id 
        AND status::TEXT = 'pending'
        AND scheduled_date >= CURRENT_DATE
        RETURNING id
    )
    SELECT COUNT(*) INTO v_tasks_updated FROM updated;
    
    -- Handle end date extension
    IF p_end_date > v_plan.end_date THEN
        v_scheduled_time := (p_scheduled_hour || ':00:00')::TIME;
        v_current_date := v_plan.end_date + INTERVAL '1 day';
        
        WHILE v_current_date <= p_end_date LOOP
            v_day_of_week := EXTRACT(DOW FROM v_current_date)::INTEGER;
            
            IF p_recurrence = 'daily' OR (p_recurrence = 'weekly' AND v_day_of_week = ANY(p_recurrence_days)) THEN
                v_deadline_at := (v_current_date || ' ' || v_scheduled_time)::TIMESTAMPTZ + (p_deadline_minutes || ' minutes')::INTERVAL;
                
                FOREACH v_branch_id IN ARRAY v_new_branch_ids LOOP
                    FOREACH v_section_id IN ARRAY p_section_ids LOOP
                        INSERT INTO visual_audit_tasks (
                            tenant_id, branch_id, section_id, status,
                            scheduled_date, scheduled_time, deadline_at,
                            min_photos, notes, created_by, plan_id
                        ) VALUES (
                            v_tenant_id, v_branch_id, v_section_id, 'pending',
                            v_current_date, v_scheduled_time, v_deadline_at,
                            p_min_photos, p_notes, auth.uid(), p_plan_id
                        );
                        v_tasks_created := v_tasks_created + 1;
                    END LOOP;
                END LOOP;
            END IF;
            
            v_current_date := v_current_date + INTERVAL '1 day';
        END LOOP;
    END IF;
    
    -- Update plan record
    UPDATE visual_audit_task_plans SET
        name = p_name,
        section_ids = p_section_ids,
        branch_ids = v_new_branch_ids,
        scheduled_hour = p_scheduled_hour,
        deadline_minutes = p_deadline_minutes,
        min_photos = p_min_photos,
        notes = p_notes,
        recurrence = p_recurrence,
        recurrence_days = p_recurrence_days,
        end_date = p_end_date,
        is_active = p_is_active,
        updated_at = NOW()
    WHERE id = p_plan_id;
    
    RETURN json_build_object(
        'success', true,
        'tasks_created', v_tasks_created,
        'tasks_deleted', v_tasks_deleted,
        'tasks_updated', v_tasks_updated
    );
END;
$$;

-- 8. Planı sil (bekleyen görevleri de sil)
CREATE OR REPLACE FUNCTION delete_visual_audit_plan(p_plan_id UUID)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id UUID;
    v_tasks_deleted INTEGER;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    -- Check plan exists
    IF NOT EXISTS (SELECT 1 FROM visual_audit_task_plans WHERE id = p_plan_id AND tenant_id = v_tenant_id) THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamadı');
    END IF;
    
    -- Delete pending tasks
    WITH deleted AS (
        DELETE FROM visual_audit_tasks
        WHERE plan_id = p_plan_id AND status::TEXT = 'pending'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_tasks_deleted FROM deleted;
    
    -- Set plan_id to NULL for completed tasks (keep history)
    UPDATE visual_audit_tasks SET plan_id = NULL WHERE plan_id = p_plan_id;
    
    -- Delete plan
    DELETE FROM visual_audit_task_plans WHERE id = p_plan_id;
    
    RETURN json_build_object('success', true, 'tasks_deleted', v_tasks_deleted);
END;
$$;

-- 9. Planı kopyala
CREATE OR REPLACE FUNCTION copy_visual_audit_plan(
    p_plan_id UUID,
    p_new_name TEXT DEFAULT NULL,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_tenant_id UUID;
    v_plan RECORD;
    v_duration INTERVAL;
    v_new_end_date DATE;
    v_result JSON;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    -- Get source plan
    SELECT * INTO v_plan FROM visual_audit_task_plans 
    WHERE id = p_plan_id AND tenant_id = v_tenant_id;
    
    IF v_plan IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamadı');
    END IF;
    
    -- Calculate new end date if not provided
    IF p_end_date IS NULL THEN
        v_duration := v_plan.end_date - v_plan.start_date;
        v_new_end_date := p_start_date + v_duration;
    ELSE
        v_new_end_date := p_end_date;
    END IF;
    
    -- Create new plan with same settings
    SELECT create_visual_audit_plan(
        p_name := COALESCE(p_new_name, v_plan.name || ' (Kopya)'),
        p_section_ids := v_plan.section_ids,
        p_branch_ids := v_plan.branch_ids,
        p_scheduled_hour := v_plan.scheduled_hour,
        p_deadline_minutes := v_plan.deadline_minutes,
        p_min_photos := v_plan.min_photos,
        p_notes := v_plan.notes,
        p_recurrence := v_plan.recurrence,
        p_recurrence_days := v_plan.recurrence_days,
        p_start_date := p_start_date,
        p_end_date := v_new_end_date
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- 10. Grant permissions
GRANT EXECUTE ON FUNCTION get_visual_audit_plans() TO authenticated;
GRANT EXECUTE ON FUNCTION create_visual_audit_plan(TEXT, UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION update_visual_audit_plan(UUID, TEXT, UUID[], UUID[], INTEGER, INTEGER, INTEGER, TEXT, TEXT, INTEGER[], DATE, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_visual_audit_plan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION copy_visual_audit_plan(UUID, TEXT, DATE, DATE) TO authenticated;
