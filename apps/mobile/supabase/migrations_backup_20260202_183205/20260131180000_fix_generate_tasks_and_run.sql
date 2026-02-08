-- Fix generate_visual_audit_tasks_for_date to use relational tables
-- instead of section_ids array (which is now nullable)

CREATE OR REPLACE FUNCTION generate_visual_audit_tasks_for_date(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template RECORD;
  v_branch_id UUID;
  v_section_id UUID;
  v_time TEXT;
  v_day_of_week INTEGER;
  v_day_of_month INTEGER;
  v_count INTEGER := 0;
  v_branches UUID[];
  v_sections UUID[];
BEGIN
  v_day_of_week := EXTRACT(DOW FROM p_date)::INTEGER;
  v_day_of_month := EXTRACT(DAY FROM p_date)::INTEGER;
  
  FOR v_template IN 
    SELECT * FROM visual_audit_templates 
    WHERE is_active = TRUE 
      AND starts_at <= p_date 
      AND (ends_at IS NULL OR ends_at >= p_date)
  LOOP
    -- Tekrar tipine göre kontrol
    CONTINUE WHEN v_template.recurrence = 'weekly' AND NOT (v_day_of_week = ANY(v_template.weekly_days));
    CONTINUE WHEN v_template.recurrence = 'monthly' AND NOT (v_day_of_month = ANY(v_template.monthly_days));
    
    -- Şubeleri belirle - önce relational table'dan, yoksa branch_ids array'inden
    SELECT ARRAY_AGG(tb.branch_id) INTO v_branches
    FROM visual_audit_template_branches tb
    WHERE tb.template_id = v_template.id;
    
    IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
      -- Fallback to branch_ids array
      IF v_template.branch_ids IS NULL OR array_length(v_template.branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branches 
        FROM branches b 
        WHERE b.tenant_id = v_template.tenant_id AND b.is_active = TRUE;
      ELSE
        v_branches := v_template.branch_ids;
      END IF;
    END IF;
    
    -- Bölümleri belirle - önce relational table'dan, yoksa section_ids array'inden
    SELECT ARRAY_AGG(ts.section_id) INTO v_sections
    FROM visual_audit_template_sections ts
    WHERE ts.template_id = v_template.id;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      -- Fallback to section_ids array
      v_sections := v_template.section_ids;
    END IF;
    
    -- Eğer hala bölüm yoksa atla
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      CONTINUE;
    END IF;
    
    -- Her şube için
    FOREACH v_branch_id IN ARRAY v_branches
    LOOP
      -- Her bölüm için
      FOREACH v_section_id IN ARRAY v_sections
      LOOP
        -- Her saat için
        FOREACH v_time IN ARRAY v_template.scheduled_times
        LOOP
          INSERT INTO visual_audit_tasks (
            tenant_id, template_id, branch_id, section_id,
            scheduled_date, scheduled_time, deadline_at
          )
          VALUES (
            v_template.tenant_id, v_template.id, v_branch_id, v_section_id,
            p_date, v_time::TIME,
            (p_date + v_time::TIME) + (v_template.deadline_minutes || ' minutes')::INTERVAL
          )
          ON CONFLICT (template_id, branch_id, section_id, scheduled_date, scheduled_time) DO NOTHING;
          
          v_count := v_count + 1;
        END LOOP;
      END LOOP;
    END LOOP;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- GRANT execute
GRANT EXECUTE ON FUNCTION generate_visual_audit_tasks_for_date(DATE) TO authenticated;

-- Bugün için görevleri oluştur
SELECT generate_visual_audit_tasks_for_date(CURRENT_DATE);
