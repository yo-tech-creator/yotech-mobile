-- Migration: Fix ALL function-to-table column mismatches
-- Date: 2026-02-02
-- Issues fixed:
-- 1. Create user_module_preferences table (missing)
-- 2. Fix notify_visual_audit_comment_added: content -> message
-- 3. Fix get_visual_audit_templates_for_manager: display_name -> first_name || last_name
-- 4. Add last_run_at column to visual_audit_task_plans
-- 5. Fix generate_tasks_for_template trigger function

-- ============================================
-- 1. Create user_module_preferences table
-- ============================================
CREATE TABLE IF NOT EXISTS "public"."user_module_preferences" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "user_id" uuid NOT NULL,
    "module_code" text NOT NULL,
    "display_order" integer NOT NULL DEFAULT 0,
    "is_visible" boolean NOT NULL DEFAULT true,
    "created_at" timestamp with time zone DEFAULT now() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT "user_module_preferences_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "user_module_preferences_user_module_unique" UNIQUE ("user_id", "module_code"),
    CONSTRAINT "user_module_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE
);

ALTER TABLE "public"."user_module_preferences" OWNER TO "postgres";

-- Enable RLS
ALTER TABLE "public"."user_module_preferences" ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own module preferences" ON "public"."user_module_preferences"
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can insert own module preferences" ON "public"."user_module_preferences"
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own module preferences" ON "public"."user_module_preferences"
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can delete own module preferences" ON "public"."user_module_preferences"
    FOR DELETE USING (user_id = auth.uid());

-- Grant permissions
GRANT ALL ON TABLE "public"."user_module_preferences" TO "anon";
GRANT ALL ON TABLE "public"."user_module_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."user_module_preferences" TO "service_role";

-- ============================================
-- 2. Add last_run_at column to visual_audit_task_plans
-- ============================================
ALTER TABLE "public"."visual_audit_task_plans" 
ADD COLUMN IF NOT EXISTS "last_run_at" timestamp with time zone;

-- ============================================
-- 3. Fix notify_visual_audit_comment_added function
-- Uses NEW.content but table has 'message' column
-- ============================================
CREATE OR REPLACE FUNCTION "public"."notify_visual_audit_comment_added"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
      format('%s: %s', v_commenter_name, LEFT(NEW.message, 100)),  -- FIX: content -> message
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

-- ============================================
-- 4. Fix get_visual_audit_templates_for_manager function
-- Uses u.display_name but users table has first_name/last_name
-- ============================================
CREATE OR REPLACE FUNCTION "public"."get_visual_audit_templates_for_manager"() 
RETURNS TABLE(
    "id" "uuid", 
    "name" "text", 
    "description" "text", 
    "section_names" "text"[], 
    "branch_count" bigint, 
    "recurrence" "text", 
    "scheduled_times" "text"[], 
    "is_active" boolean, 
    "created_by_name" "text", 
    "created_at" timestamp with time zone
)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id UUID;
  v_role TEXT;
BEGIN
  v_role := current_user_role();
  
  IF v_role = 'grand_admin' THEN
    SELECT tenants.id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    COALESCE(
      (SELECT array_agg(s.name ORDER BY ts.display_order) 
       FROM visual_audit_template_sections ts 
       JOIN visual_audit_sections s ON s.id = ts.section_id
       WHERE ts.template_id = t.id),
      ARRAY[]::TEXT[]
    ) AS section_names,
    COALESCE(
      (SELECT COUNT(*) FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      0::BIGINT
    ) AS branch_count,
    t.recurrence::TEXT,
    t.scheduled_times,
    t.is_active,
    COALESCE(u.first_name || ' ' || u.last_name, 'Bilinmiyor') AS created_by_name,  -- FIX: display_name -> first_name || last_name
    t.created_at
  FROM visual_audit_templates t
  LEFT JOIN users u ON u.id = t.created_by
  WHERE t.tenant_id = v_tenant_id
    AND t.is_active = true
  ORDER BY t.created_at DESC;
END;
$$;

-- ============================================
-- 5. Fix generate_tasks_for_template trigger function
-- Issues:
-- - NEW.next_scheduled_date doesn't exist
-- - NEW.section_id should be NEW.section_ids (array)
-- - NEW.scheduled_hour should handle scheduled_times (text array)
-- ============================================
CREATE OR REPLACE FUNCTION "public"."generate_tasks_for_template"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_branch_id UUID;
  v_section_id UUID;
  v_branches UUID[];
  v_schedule DATE;
  v_scheduled_time TIME;
  v_deadline_at TIMESTAMP;
  v_time_str TEXT;
BEGIN
  IF NEW.is_active = TRUE THEN
    -- FIX: Use starts_at instead of next_scheduled_date (which doesn't exist)
    v_schedule := COALESCE(NEW.starts_at, CURRENT_DATE);
    
    -- FIX: Use is_active instead of active
    IF NEW.branch_ids IS NULL OR array_length(NEW.branch_ids, 1) = 0 THEN
      SELECT ARRAY_AGG(b.id) INTO v_branches
      FROM branches b
      WHERE b.tenant_id = NEW.tenant_id AND b.is_active = TRUE;
    ELSE
      v_branches := NEW.branch_ids;
    END IF;

    -- FIX: Use scheduled_times array instead of scheduled_hour
    -- Get first scheduled time or default to 09:00
    v_time_str := COALESCE(NEW.scheduled_times[1], '09:00');
    v_scheduled_time := v_time_str::TIME;
    
    v_deadline_at := (v_schedule::TEXT || ' ' || v_scheduled_time::TEXT)::TIMESTAMP 
                     + (COALESCE(NEW.deadline_minutes, 60) || ' minutes')::INTERVAL;

    IF v_branches IS NOT NULL AND array_length(v_branches, 1) > 0 THEN
      FOREACH v_branch_id IN ARRAY v_branches LOOP
        -- FIX: Iterate over section_ids array instead of using section_id
        IF NEW.section_ids IS NOT NULL AND array_length(NEW.section_ids, 1) > 0 THEN
          FOREACH v_section_id IN ARRAY NEW.section_ids LOOP
            INSERT INTO visual_audit_tasks (
              tenant_id, branch_id, section_id, status, scheduled_date,
              scheduled_time, deadline_at, min_photos, notes, created_by, template_id
            ) VALUES (
              NEW.tenant_id, v_branch_id, v_section_id, 'pending', v_schedule,
              v_scheduled_time, v_deadline_at, COALESCE(NEW.min_photos, 1), 
              NEW.description, NEW.created_by, NEW.id
            );
          END LOOP;
        END IF;
      END LOOP;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================
-- 6. Also fix get_visual_audit_templates_list (same display_name issue)
-- ============================================
CREATE OR REPLACE FUNCTION "public"."get_visual_audit_templates_list"() 
RETURNS TABLE(
    "id" "uuid", 
    "name" "text", 
    "description" "text", 
    "section_names" "text"[], 
    "branch_count" bigint, 
    "recurrence" "text", 
    "scheduled_times" "text"[], 
    "is_active" boolean, 
    "created_by_name" "text", 
    "created_at" timestamp with time zone
)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id UUID;
BEGIN
  v_tenant_id := current_tenant_id();
  
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    COALESCE(
      (SELECT array_agg(s.name ORDER BY ts.display_order) 
       FROM visual_audit_template_sections ts 
       JOIN visual_audit_sections s ON s.id = ts.section_id
       WHERE ts.template_id = t.id),
      ARRAY[]::TEXT[]
    ) AS section_names,
    COALESCE(
      (SELECT COUNT(*) FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      0::BIGINT
    ) AS branch_count,
    t.recurrence::TEXT,
    t.scheduled_times,
    t.is_active,
    COALESCE(u.first_name || ' ' || u.last_name, 'Bilinmiyor') AS created_by_name,  -- FIX: display_name -> first_name || last_name
    t.created_at
  FROM visual_audit_templates t
  LEFT JOIN users u ON u.id = t.created_by
  WHERE t.tenant_id = v_tenant_id
  ORDER BY t.created_at DESC;
END;
$$;

-- Grant permissions for functions
GRANT ALL ON FUNCTION "public"."notify_visual_audit_comment_added"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_comment_added"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_comment_added"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_for_manager"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_for_manager"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_for_manager"() TO "service_role";

GRANT ALL ON FUNCTION "public"."generate_tasks_for_template"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_tasks_for_template"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_tasks_for_template"() TO "service_role";

GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_list"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_list"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_list"() TO "service_role";
