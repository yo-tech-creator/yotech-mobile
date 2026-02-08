-- Create a cron job to generate visual audit tasks daily
-- This requires pg_cron extension to be enabled in Supabase

-- Enable pg_cron extension if not already enabled
-- Note: In Supabase, pg_cron is available but may need to be enabled via dashboard
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a wrapper function that can be called by cron
CREATE OR REPLACE FUNCTION public.daily_visual_audit_task_generator()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_template RECORD;
  v_plan RECORD;
  v_branch_id UUID;
  v_section_id UUID;
  v_time TEXT;
  v_today DATE := CURRENT_DATE;
  v_day_of_week INTEGER;
  v_day_of_month INTEGER;
  v_branches UUID[];
  v_sections UUID[];
  v_scheduled_time TIME;
  v_deadline_at TIMESTAMPTZ;
  v_tasks_created INTEGER := 0;
BEGIN
  v_day_of_week := EXTRACT(DOW FROM v_today)::INTEGER;
  v_day_of_month := EXTRACT(DAY FROM v_today)::INTEGER;
  
  -- ================================================
  -- 1. TEMPLATE BASED TASK GENERATION
  -- ================================================
  FOR v_template IN 
    SELECT * FROM visual_audit_templates 
    WHERE is_active = TRUE 
      AND (starts_at IS NULL OR starts_at <= v_today)
      AND (ends_at IS NULL OR ends_at >= v_today)
  LOOP
    -- Check recurrence
    CONTINUE WHEN v_template.recurrence = 'weekly' AND NOT (v_day_of_week = ANY(v_template.weekly_days));
    CONTINUE WHEN v_template.recurrence = 'monthly' AND NOT (v_day_of_month = ANY(v_template.monthly_days));
    
    -- Get branches from relational table first
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
    
    -- Get sections from relational table first
    SELECT ARRAY_AGG(ts.section_id) INTO v_sections
    FROM visual_audit_template_sections ts
    WHERE ts.template_id = v_template.id;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      v_sections := v_template.section_ids;
    END IF;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      CONTINUE;
    END IF;
    
    -- Create tasks
    IF v_branches IS NOT NULL THEN
      FOREACH v_branch_id IN ARRAY v_branches
      LOOP
        FOREACH v_section_id IN ARRAY v_sections
        LOOP
          FOREACH v_time IN ARRAY v_template.scheduled_times
          LOOP
            INSERT INTO visual_audit_tasks (
              tenant_id, template_id, branch_id, section_id,
              scheduled_date, scheduled_time, deadline_at, min_photos, status
            )
            VALUES (
              v_template.tenant_id, v_template.id, v_branch_id, v_section_id,
              v_today, v_time::TIME,
              (v_today + v_time::TIME) + (v_template.deadline_minutes || ' minutes')::INTERVAL,
              v_template.min_photos, 'pending'
            )
            ON CONFLICT (template_id, branch_id, section_id, scheduled_date, scheduled_time) DO NOTHING;
            
            v_tasks_created := v_tasks_created + 1;
          END LOOP;
        END LOOP;
      END LOOP;
    END IF;
  END LOOP;
  
  -- ================================================
  -- 2. PLAN BASED TASK GENERATION
  -- ================================================
  FOR v_plan IN 
    SELECT * FROM visual_audit_task_plans 
    WHERE is_active = TRUE 
      AND start_date <= v_today
      AND (end_date IS NULL OR end_date >= v_today)
  LOOP
    -- Check recurrence
    IF v_plan.recurrence = 'weekly' AND v_plan.recurrence_days IS NOT NULL THEN
      CONTINUE WHEN NOT (v_day_of_week = ANY(v_plan.recurrence_days));
    END IF;
    -- Daily: no skip needed
    
    -- Get branches
    IF v_plan.branch_ids IS NULL OR array_length(v_plan.branch_ids, 1) IS NULL THEN
      SELECT ARRAY_AGG(b.id) INTO v_branches
      FROM branches b
      WHERE b.tenant_id = v_plan.tenant_id AND b.is_active = TRUE;
    ELSE
      v_branches := v_plan.branch_ids;
    END IF;
    
    IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
      CONTINUE;
    END IF;
    
    v_scheduled_time := (LPAD(COALESCE(v_plan.scheduled_hour, 9)::TEXT, 2, '0') || ':00:00')::TIME;
    v_deadline_at := (v_today + v_scheduled_time) + (COALESCE(v_plan.deadline_minutes, 60) || ' minutes')::INTERVAL;
    
    -- Create tasks for each branch and section
    FOREACH v_branch_id IN ARRAY v_branches
    LOOP
      IF v_plan.section_ids IS NOT NULL THEN
        FOREACH v_section_id IN ARRAY v_plan.section_ids
        LOOP
          INSERT INTO visual_audit_tasks (
            tenant_id, branch_id, section_id, plan_id, status,
            scheduled_date, scheduled_time, deadline_at,
            min_photos, notes, created_by
          )
          SELECT 
            v_plan.tenant_id, v_branch_id, v_section_id, v_plan.id, 'pending',
            v_today, v_scheduled_time, v_deadline_at,
            COALESCE(v_plan.min_photos, 1), v_plan.notes, v_plan.created_by
          WHERE NOT EXISTS (
            SELECT 1 FROM visual_audit_tasks t
            WHERE t.plan_id = v_plan.id
              AND t.branch_id = v_branch_id
              AND t.section_id = v_section_id
              AND t.scheduled_date = v_today
          );
          
          IF FOUND THEN
            v_tasks_created := v_tasks_created + 1;
          END IF;
        END LOOP;
      END IF;
    END LOOP;
    
    -- Update last_run_at
    UPDATE visual_audit_task_plans 
    SET last_run_at = NOW() 
    WHERE id = v_plan.id;
  END LOOP;
  
  -- Log the result
  RAISE NOTICE 'Daily visual audit task generator completed. Tasks created: %', v_tasks_created;
END;
$function$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.daily_visual_audit_task_generator() TO service_role;

-- To set up cron in Supabase, you can use the SQL editor to run:
-- SELECT cron.schedule('daily-visual-audit-tasks', '0 0 * * *', 'SELECT public.daily_visual_audit_task_generator()');
-- This runs at midnight every day

-- For now, we'll also update the visual_audit_task_plans table to track when tasks were last generated
-- (last_run_at column was already added in a previous migration)

-- Also add a manual trigger function that can be called via RPC
CREATE OR REPLACE FUNCTION public.generate_visual_audit_tasks_for_today()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_role TEXT;
BEGIN
  v_role := current_user_role();
  
  -- Only allow admins to manually trigger
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'service_role') THEN
    RETURN json_build_object('success', false, 'error', 'Bu işlem için yetkiniz yok');
  END IF;
  
  -- Call the generator
  PERFORM daily_visual_audit_task_generator();
  
  RETURN json_build_object('success', true, 'message', 'Görevler oluşturuldu');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.generate_visual_audit_tasks_for_today() TO authenticated;
