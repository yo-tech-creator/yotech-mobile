Using workdir C:\flutter_projects\yotech2\apps\mobile
Initialising login role...
Dumping schemas from remote database...



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."announcement_type" AS ENUM (
    'announcement',
    'survey'
);


ALTER TYPE "public"."announcement_type" OWNER TO "postgres";


CREATE TYPE "public"."depot_notice_status" AS ENUM (
    'open',
    'in_transfer',
    'fulfilled',
    'cancelled'
);


ALTER TYPE "public"."depot_notice_status" OWNER TO "postgres";


CREATE TYPE "public"."depot_notice_type" AS ENUM (
    'shortage',
    'surplus'
);


ALTER TYPE "public"."depot_notice_type" OWNER TO "postgres";


CREATE TYPE "public"."depot_offer_status" AS ENUM (
    'pending',
    'accepted',
    'rejected',
    'expired',
    'cancelled',
    'delivered'
);


ALTER TYPE "public"."depot_offer_status" OWNER TO "postgres";


CREATE TYPE "public"."leave_status" AS ENUM (
    'beklemede',
    'onaylandi',
    'reddedildi'
);


ALTER TYPE "public"."leave_status" OWNER TO "postgres";


CREATE TYPE "public"."leave_type" AS ENUM (
    'yillik',
    'ucretsiz',
    'ucretli',
    'saglik'
);


ALTER TYPE "public"."leave_type" OWNER TO "postgres";


CREATE TYPE "public"."malfunction_category" AS ENUM (
    'bt_donanim',
    'sogutma',
    'bina_tesisat',
    'depo_lojistik',
    'guvenlik',
    'diger'
);


ALTER TYPE "public"."malfunction_category" OWNER TO "postgres";


CREATE TYPE "public"."malfunction_priority" AS ENUM (
    'dusuk',
    'orta',
    'yuksek',
    'kritik'
);


ALTER TYPE "public"."malfunction_priority" OWNER TO "postgres";


CREATE TYPE "public"."malfunction_status" AS ENUM (
    'acik',
    'devam_ediyor',
    'cozuldu',
    'iptal'
);


ALTER TYPE "public"."malfunction_status" OWNER TO "postgres";


CREATE TYPE "public"."manager_todo_status" AS ENUM (
    'pending',
    'completed'
);


ALTER TYPE "public"."manager_todo_status" OWNER TO "postgres";


CREATE TYPE "public"."notification_type" AS ENUM (
    'visual_audit_task',
    'visual_audit_photo',
    'visual_audit_comment',
    'visual_audit_completed',
    'task_assigned',
    'task_completed',
    'task_approved',
    'announcement',
    'survey',
    'skt_warning',
    'depot_transfer',
    'general'
);


ALTER TYPE "public"."notification_type" OWNER TO "postgres";


CREATE TYPE "public"."product_issue_status" AS ENUM (
    'acik',
    'inceleniyor',
    'cozuldu',
    'kapandi'
);


ALTER TYPE "public"."product_issue_status" OWNER TO "postgres";


CREATE TYPE "public"."request_category" AS ENUM (
    'malfunction',
    'equipment',
    'leave',
    'other'
);


ALTER TYPE "public"."request_category" OWNER TO "postgres";


CREATE TYPE "public"."request_status" AS ENUM (
    'pending',
    'in_progress',
    'resolved',
    'cancelled'
);


ALTER TYPE "public"."request_status" OWNER TO "postgres";


CREATE TYPE "public"."skt_alarm_type" AS ENUM (
    'day_before',
    'due_day'
);


ALTER TYPE "public"."skt_alarm_type" OWNER TO "postgres";


CREATE TYPE "public"."skt_status" AS ENUM (
    'normal',
    'yaklasan',
    'gecmis'
);


ALTER TYPE "public"."skt_status" OWNER TO "postgres";


CREATE TYPE "public"."store_scoring_item_result" AS ENUM (
    'positive',
    'negative',
    'not_applicable',
    'neutral'
);


ALTER TYPE "public"."store_scoring_item_result" OWNER TO "postgres";


COMMENT ON TYPE "public"."store_scoring_item_result" IS 'Form scoring item results: positive (Evet), negative (Hay─▒r), neutral (K─▒smen), not_applicable (N/A)';



CREATE TYPE "public"."survey_question_type" AS ENUM (
    'single_choice',
    'multiple_choice',
    'text',
    'rating',
    'yes_no',
    'textarea',
    'number'
);


ALTER TYPE "public"."survey_question_type" OWNER TO "postgres";


CREATE TYPE "public"."target_scope" AS ENUM (
    'all_branches',
    'selected_branches',
    'my_branches',
    'my_branch',
    'region_managers_only'
);


ALTER TYPE "public"."target_scope" OWNER TO "postgres";


CREATE TYPE "public"."task_status" AS ENUM (
    'atandi',
    'devam_ediyor',
    'tamamlandi',
    'iptal'
);


ALTER TYPE "public"."task_status" OWNER TO "postgres";


CREATE TYPE "public"."transfer_status" AS ENUM (
    'hazirlaniyor',
    'yolda',
    'teslim_edildi',
    'iptal'
);


ALTER TYPE "public"."transfer_status" OWNER TO "postgres";


CREATE TYPE "public"."user_role" AS ENUM (
    'grand_admin',
    'firma_admin',
    'bolge_muduru',
    'sube_muduru',
    'personel'
);


ALTER TYPE "public"."user_role" OWNER TO "postgres";


CREATE TYPE "public"."visual_audit_comment_type" AS ENUM (
    'comment',
    'approval',
    'rejection',
    'revision_request'
);


ALTER TYPE "public"."visual_audit_comment_type" OWNER TO "postgres";


CREATE TYPE "public"."visual_audit_recurrence" AS ENUM (
    'daily',
    'weekly',
    'monthly'
);


ALTER TYPE "public"."visual_audit_recurrence" OWNER TO "postgres";


CREATE TYPE "public"."visual_audit_task_status" AS ENUM (
    'pending',
    'in_progress',
    'completed',
    'missed',
    'approved',
    'rejected'
);


ALTER TYPE "public"."visual_audit_task_status" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_personel"("p_employee_code" "text", "p_password" "text", "p_tenant_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid;
  v_email text;
  v_phone text;
  v_encrypted_password text;
BEGIN
  v_user_id := gen_random_uuid();
  v_email := LOWER(p_employee_code) || '@filemarket.com';
  v_phone := '5550000000';
  v_encrypted_password := crypt(p_password, gen_salt('bf')); 

  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    v_encrypted_password,
    NOW(),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  );

  INSERT INTO public.users (
    id,
    tenant_id,
    first_name,
    last_name,
    email,
    phone,
    employee_code,
    role,
    position,
    hire_date,
    is_active
  )
  VALUES (
    v_user_id,
    p_tenant_id,
    'Yeni',
    'Personel',
    v_email,
    v_phone,
    p_employee_code,
    'personel',
    'Ma─şaza Personeli',
    CURRENT_DATE,
    TRUE
  );

  RETURN jsonb_build_object('success', TRUE, 'user_id', v_user_id, 'email', v_email);

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."add_personel"("p_employee_code" "text", "p_password" "text", "p_tenant_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_visual_audit_comment"("p_task_id" "uuid", "p_message" "text", "p_comment_type" "public"."visual_audit_comment_type" DEFAULT 'comment'::"public"."visual_audit_comment_type", "p_photo_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_id UUID;
  v_task RECORD;
BEGIN
  SELECT * INTO v_task FROM visual_audit_tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'G├Ârev bulunamad─▒';
  END IF;
  
  INSERT INTO visual_audit_comments (tenant_id, task_id, user_id, comment_type, message, photo_id)
  VALUES (v_task.tenant_id, p_task_id, current_user_id(), p_comment_type, p_message, p_photo_id)
  RETURNING id INTO v_id;
  
  -- Onay/Red durumlar─▒n─▒ g├╝ncelle
  IF p_comment_type = 'approval' THEN
    UPDATE visual_audit_tasks 
    SET status = 'approved', reviewed_by = current_user_id(), reviewed_at = now(), review_note = p_message, updated_at = now()
    WHERE id = p_task_id;
  ELSIF p_comment_type = 'rejection' OR p_comment_type = 'revision_request' THEN
    UPDATE visual_audit_tasks 
    SET status = 'rejected', reviewed_by = current_user_id(), reviewed_at = now(), review_note = p_message, updated_at = now()
    WHERE id = p_task_id;
  END IF;
  
  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."add_visual_audit_comment"("p_task_id" "uuid", "p_message" "text", "p_comment_type" "public"."visual_audit_comment_type", "p_photo_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."batch_update_module_order"("p_module_orders" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_module JSONB;
  v_count INT := 0;
BEGIN
  FOR v_module IN SELECT * FROM jsonb_array_elements(p_module_orders)
  LOOP
    INSERT INTO user_module_preferences (user_id, module_code, display_order)
    VALUES (
      current_user_id(),
      v_module->>'module_code',
      (v_module->>'display_order')::INT
    )
    ON CONFLICT (user_id, module_code)
    DO UPDATE SET 
      display_order = (v_module->>'display_order')::INT,
      updated_at = NOW();
    
    v_count := v_count + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'updated_count', v_count
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;


ALTER FUNCTION "public"."batch_update_module_order"("p_module_orders" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."branch_belongs_to_current_tenant"("p_branch_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.branches b
    WHERE b.id = p_branch_id
      AND b.tenant_id = current_tenant_id()
  );
$$;


ALTER FUNCTION "public"."branch_belongs_to_current_tenant"("p_branch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_attendance_minutes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.check_out_time IS NOT NULL THEN
    NEW.total_minutes = EXTRACT(EPOCH FROM (NEW.check_out_time - NEW.check_in_time)) / 60;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_attendance_minutes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_break_duration"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.break_end IS NOT NULL THEN
    NEW.duration_minutes = EXTRACT(EPOCH FROM (NEW.break_end - NEW.break_start)) / 60;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_break_duration"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_skt_alarm_date"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  NEW.alarm_date = NEW.expiry_date - (NEW.alarm_days_before || ' days')::INTERVAL;
  
  IF NEW.expiry_date < CURRENT_DATE THEN
    NEW.status = 'gecmis';
  ELSIF NEW.expiry_date <= CURRENT_DATE + (NEW.alarm_days_before || ' days')::INTERVAL THEN
    NEW.status = 'yaklasan';
  ELSE
    NEW.status = 'normal';
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."calculate_skt_alarm_date"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."copy_visual_audit_plan"("p_plan_id" "uuid", "p_new_name" "text" DEFAULT NULL::"text", "p_start_date" "date" DEFAULT CURRENT_DATE, "p_end_date" "date" DEFAULT NULL::"date") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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
        RETURN json_build_object('success', false, 'error', 'Plan bulunamad─▒');
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


ALTER FUNCTION "public"."copy_visual_audit_plan"("p_plan_id" "uuid", "p_new_name" "text", "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_announcement"("p_title" "text", "p_content" "text", "p_summary" "text" DEFAULT NULL::"text", "p_cover_image_url" "text" DEFAULT NULL::"text", "p_target_scope" "public"."target_scope" DEFAULT 'all_branches'::"public"."target_scope", "p_target_branches" "uuid"[] DEFAULT NULL::"uuid"[], "p_target_regions" "uuid"[] DEFAULT NULL::"uuid"[], "p_managers_only" boolean DEFAULT false, "p_include_region_managers" boolean DEFAULT false, "p_expires_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_pinned" boolean DEFAULT false, "p_priority" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_user_role user_role;
  v_announcement_id uuid;
BEGIN
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = v_user_id;
  
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullan─▒c─▒ bulunamad─▒');
  END IF;
  
  IF v_user_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru olu┼şturma yetkiniz yok');
  END IF;
  
  IF v_user_role = 'sube_muduru' AND p_target_scope NOT IN ('my_branch') THEN
    p_target_scope := 'my_branch';
  END IF;
  
  IF v_user_role = 'bolge_muduru' AND p_target_scope = 'region_managers_only' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu hedef kitleyi se├ğme yetkiniz yok');
  END IF;
  
  -- FIX: is_active instead of active
  INSERT INTO public.announcements (
    tenant_id,
    title,
    content,
    summary,
    cover_image_url,
    type,
    target_scope,
    target_branches,
    target_regions,
    managers_only,
    include_region_managers,
    published_by,
    created_by_role,
    expires_at,
    pinned,
    priority,
    is_active
  ) VALUES (
    v_tenant_id,
    p_title,
    p_content,
    p_summary,
    p_cover_image_url,
    'announcement',
    p_target_scope,
    p_target_branches,
    p_target_regions,
    p_managers_only,
    p_include_region_managers,
    v_user_id,
    v_user_role,
    p_expires_at,
    p_pinned,
    p_priority,
    true
  )
  RETURNING id INTO v_announcement_id;
  
  RETURN jsonb_build_object('success', true, 'announcement_id', v_announcement_id);
END;
$$;


ALTER FUNCTION "public"."create_announcement"("p_title" "text", "p_content" "text", "p_summary" "text", "p_cover_image_url" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_pinned" boolean, "p_priority" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_bug_report"("p_title" "text", "p_description" "text", "p_device_info" "jsonb" DEFAULT '{}'::"jsonb", "p_app_version" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID;
    v_tenant_id UUID;
    v_report_id UUID;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Oturum a├ğ─▒lmam─▒┼ş';
    END IF;
    
    -- Kullan─▒c─▒n─▒n tenant_id'sini al
    SELECT tenant_id INTO v_tenant_id
    FROM public.users
    WHERE id = v_user_id;
    
    -- Rapor olu┼ştur
    INSERT INTO public.bug_reports (
        tenant_id,
        user_id,
        title,
        description,
        device_info,
        app_version
    ) VALUES (
        v_tenant_id,
        v_user_id,
        p_title,
        p_description,
        p_device_info,
        p_app_version
    )
    RETURNING id INTO v_report_id;
    
    RETURN v_report_id;
END;
$$;


ALTER FUNCTION "public"."create_bug_report"("p_title" "text", "p_description" "text", "p_device_info" "jsonb", "p_app_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_survey"("p_title" "text", "p_content" "text", "p_summary" "text" DEFAULT NULL::"text", "p_target_scope" "public"."target_scope" DEFAULT 'all_branches'::"public"."target_scope", "p_target_branches" "uuid"[] DEFAULT NULL::"uuid"[], "p_target_regions" "uuid"[] DEFAULT NULL::"uuid"[], "p_managers_only" boolean DEFAULT false, "p_include_region_managers" boolean DEFAULT false, "p_expires_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_questions" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_user_role user_role;
  v_announcement_id uuid;
  v_question jsonb;
  v_question_id uuid;
  v_sort_order int := 0;
BEGIN
  SELECT tenant_id, role INTO v_tenant_id, v_user_role
  FROM public.users
  WHERE id = v_user_id;
  
  IF v_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullan─▒c─▒ bulunamad─▒');
  END IF;
  
  IF v_user_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anket olu┼şturma yetkiniz yok');
  END IF;
  
  IF v_user_role = 'sube_muduru' AND p_target_scope NOT IN ('my_branch') THEN
    p_target_scope := 'my_branch';
  END IF;
  
  IF v_user_role = 'bolge_muduru' AND p_target_scope = 'region_managers_only' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu hedef kitleyi se├ğme yetkiniz yok');
  END IF;
  
  -- FIX: is_active instead of active
  INSERT INTO public.announcements (
    tenant_id,
    title,
    content,
    summary,
    type,
    target_scope,
    target_branches,
    target_regions,
    managers_only,
    include_region_managers,
    published_by,
    created_by_role,
    expires_at,
    is_active
  ) VALUES (
    v_tenant_id,
    p_title,
    p_content,
    p_summary,
    'survey',
    p_target_scope,
    p_target_branches,
    p_target_regions,
    p_managers_only,
    p_include_region_managers,
    v_user_id,
    v_user_role,
    p_expires_at,
    true
  )
  RETURNING id INTO v_announcement_id;
  
  FOR v_question IN SELECT * FROM jsonb_array_elements(p_questions)
  LOOP
    INSERT INTO public.survey_questions (
      announcement_id,
      question_text,
      question_type,
      options,
      required,
      sort_order
    ) VALUES (
      v_announcement_id,
      v_question->>'question_text',
      (v_question->>'question_type')::survey_question_type,
      COALESCE(v_question->'options', '[]'::jsonb),
      COALESCE((v_question->>'required')::boolean, true),
      v_sort_order
    );
    v_sort_order := v_sort_order + 1;
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true, 
    'announcement_id', v_announcement_id,
    'question_count', v_sort_order
  );
END;
$$;


ALTER FUNCTION "public"."create_survey"("p_title" "text", "p_content" "text", "p_summary" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_questions" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_visual_audit_plan"("p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer DEFAULT 9, "p_deadline_minutes" integer DEFAULT 60, "p_min_photos" integer DEFAULT 1, "p_notes" "text" DEFAULT NULL::"text", "p_recurrence" "text" DEFAULT 'daily'::"text", "p_recurrence_days" integer[] DEFAULT '{}'::integer[], "p_start_date" "date" DEFAULT CURRENT_DATE, "p_end_date" "date" DEFAULT (CURRENT_DATE + '14 days'::interval)) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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
        RETURN json_build_object('success', false, 'error', 'Kullan─▒c─▒ bulunamad─▒');
    END IF;
    
    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir b├Âl├╝m se├ğmelisiniz');
    END IF;
    
    -- FIX: is_active instead of active
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


ALTER FUNCTION "public"."create_visual_audit_plan"("p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_visual_audit_section"("p_name" "text", "p_description" "text" DEFAULT NULL::"text", "p_icon" "text" DEFAULT 'store'::"text", "p_color" "text" DEFAULT '#3B82F6'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_id UUID;
  v_role TEXT;
  v_tenant_id UUID;
BEGIN
  v_role := current_user_role();
  
  -- grand_admin de ekleyebilsin
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  -- grand_admin i├ğin tenant_id parametre olarak al─▒nmal─▒, ┼şimdilik first tenant
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  INSERT INTO visual_audit_sections (tenant_id, name, description, icon, color)
  VALUES (v_tenant_id, p_name, p_description, p_icon, p_color)
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."create_visual_audit_section"("p_name" "text", "p_description" "text", "p_icon" "text", "p_color" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_visual_audit_task"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_deadline_minutes" integer DEFAULT 60, "p_min_photos" integer DEFAULT 1, "p_note" "text" DEFAULT NULL::"text", "p_scheduled_date" "date" DEFAULT CURRENT_DATE, "p_scheduled_hour" integer DEFAULT 9, "p_plan_id" "uuid" DEFAULT NULL::"uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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
        RETURN json_build_object('success', false, 'error', 'Kullan─▒c─▒ bulunamad─▒');
    END IF;

    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir b├Âl├╝m se├ğmelisiniz');
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
        RETURN json_build_object('success', false, 'error', 'Aktif ┼şube bulunamad─▒');
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


ALTER FUNCTION "public"."create_visual_audit_task"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_note" "text", "p_scheduled_date" "date", "p_scheduled_hour" integer, "p_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_visual_audit_task_with_plan"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_scheduled_hour" integer DEFAULT 9, "p_deadline_minutes" integer DEFAULT 60, "p_min_photos" integer DEFAULT 1, "p_notes" "text" DEFAULT NULL::"text", "p_recurrence" "text" DEFAULT 'daily'::"text", "p_recurrence_days" integer[] DEFAULT NULL::integer[], "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date") RETURNS json
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
        RETURN json_build_object('success', false, 'error', 'Kullan─▒c─▒ bulunamad─▒');
    END IF;

    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir b├Âl├╝m se├ğmelisiniz');
    END IF;

    IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
        SELECT ARRAY_AGG(b.id) INTO v_branch_ids
        FROM branches b
        WHERE b.tenant_id = v_tenant_id AND b.is_active = true;
    ELSE
        v_branch_ids := p_branch_ids;
    END IF;

    IF v_branch_ids IS NULL OR array_length(v_branch_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Aktif ┼şube bulunamad─▒');
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
        COALESCE(v_section_names[1], 'G├Ârsel Denetim') || ' - ' || to_char(CURRENT_TIMESTAMP, 'DD.MM.YYYY'),
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


ALTER FUNCTION "public"."create_visual_audit_task_with_plan"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_visual_audit_template"("p_name" "text", "p_section_ids" "uuid"[], "p_scheduled_times" "text"[], "p_description" "text" DEFAULT NULL::"text", "p_branch_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_recurrence" "public"."visual_audit_recurrence" DEFAULT 'daily'::"public"."visual_audit_recurrence", "p_weekly_days" integer[] DEFAULT ARRAY[1, 2, 3, 4, 5], "p_monthly_days" integer[] DEFAULT NULL::integer[], "p_deadline_minutes" integer DEFAULT 60, "p_min_photos" integer DEFAULT 1) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_id UUID;
  v_role TEXT;
  v_user_id UUID;
  v_tenant_id UUID;
  v_section_id UUID;
  v_branch_id UUID;
  v_actual_branch_ids UUID[];
  v_order INTEGER := 0;
  v_time TEXT;
  v_day_of_week INTEGER;
  v_should_create_today BOOLEAN := FALSE;
BEGIN
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'En az bir b├Âl├╝m se├ğmelisiniz';
  END IF;
  
  -- FIX: is_active instead of active
  IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
    SELECT array_agg(id) INTO v_actual_branch_ids
    FROM branches
    WHERE tenant_id = v_tenant_id AND is_active = true;
  ELSE
    v_actual_branch_ids := p_branch_ids;
  END IF;
  
  INSERT INTO visual_audit_templates (
    tenant_id, name, description, recurrence, 
    weekly_days, monthly_days, scheduled_times,
    deadline_minutes, min_photos, created_by
  ) VALUES (
    v_tenant_id, p_name, p_description, p_recurrence,
    p_weekly_days, p_monthly_days, p_scheduled_times,
    p_deadline_minutes, p_min_photos, v_user_id
  ) RETURNING id INTO v_id;
  
  FOREACH v_section_id IN ARRAY p_section_ids
  LOOP
    INSERT INTO visual_audit_template_sections (template_id, section_id, display_order)
    VALUES (v_id, v_section_id, v_order);
    v_order := v_order + 1;
  END LOOP;
  
  IF v_actual_branch_ids IS NOT NULL THEN
    FOREACH v_branch_id IN ARRAY v_actual_branch_ids
    LOOP
      INSERT INTO visual_audit_template_branches (template_id, branch_id)
      VALUES (v_id, v_branch_id);
    END LOOP;
  END IF;
  
  v_day_of_week := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
  
  IF p_recurrence = 'daily' THEN
    v_should_create_today := TRUE;
  ELSIF p_recurrence = 'weekly' AND p_weekly_days IS NOT NULL THEN
    v_should_create_today := v_day_of_week = ANY(p_weekly_days);
  ELSIF p_recurrence = 'monthly' AND p_monthly_days IS NOT NULL THEN
    v_should_create_today := EXTRACT(DAY FROM CURRENT_DATE)::INTEGER = ANY(p_monthly_days);
  END IF;
  
  IF v_should_create_today AND v_actual_branch_ids IS NOT NULL THEN
    FOREACH v_branch_id IN ARRAY v_actual_branch_ids
    LOOP
      FOREACH v_section_id IN ARRAY p_section_ids
      LOOP
        FOREACH v_time IN ARRAY p_scheduled_times
        LOOP
          INSERT INTO visual_audit_tasks (
            tenant_id, template_id, branch_id, section_id,
            scheduled_date, scheduled_time, deadline_at, min_photos
          )
          VALUES (
            v_tenant_id, v_id, v_branch_id, v_section_id,
            CURRENT_DATE, v_time::TIME,
            (CURRENT_DATE + v_time::TIME) + (p_deadline_minutes || ' minutes')::INTERVAL,
            p_min_photos
          )
          ON CONFLICT (template_id, branch_id, section_id, scheduled_date, scheduled_time) DO NOTHING;
        END LOOP;
      END LOOP;
    END LOOP;
  END IF;
  
  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."create_visual_audit_template"("p_name" "text", "p_section_ids" "uuid"[], "p_scheduled_times" "text"[], "p_description" "text", "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_monthly_days" integer[], "p_deadline_minutes" integer, "p_min_photos" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  -- First try JWT claim (for custom tokens)
  -- Then fallback to users table lookup
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.tenant_id', true), '')::uuid,
    (SELECT tenant_id FROM public.users WHERE id = auth.uid())
  );
$$;


ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."current_tenant_id"() IS 'Returns the current user''s tenant_id. First checks JWT claim, then falls back to users table lookup.';



CREATE OR REPLACE FUNCTION "public"."current_user_ctx"() RETURNS TABLE("id" "uuid", "tenant_id" "uuid", "role" "public"."user_role", "branch_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  select u.id, u.tenant_id, u.role, u.branch_id
  from users u
  where u.id = auth.uid();
$$;


ALTER FUNCTION "public"."current_user_ctx"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  select auth.uid();
$$;


ALTER FUNCTION "public"."current_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT COALESCE(
    (SELECT role::text FROM users WHERE id = auth.uid()),
    'anonymous'
  );
$$;


ALTER FUNCTION "public"."current_user_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."custom_access_token_hook"("event" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
begin
  return event;
end;
$$;


ALTER FUNCTION "public"."custom_access_token_hook"("event" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") IS 'Custom access token hook - JWT''ye tenant_id ve role ekler (enum safe)';



CREATE OR REPLACE FUNCTION "public"."delete_visual_audit_plan"("p_plan_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_tenant_id UUID;
    v_tasks_deleted INTEGER;
BEGIN
    SELECT u.tenant_id INTO v_tenant_id FROM users u WHERE u.id = auth.uid();
    
    -- Check plan exists
    IF NOT EXISTS (SELECT 1 FROM visual_audit_task_plans WHERE id = p_plan_id AND tenant_id = v_tenant_id) THEN
        RETURN json_build_object('success', false, 'error', 'Plan bulunamad─▒');
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


ALTER FUNCTION "public"."delete_visual_audit_plan"("p_plan_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_visual_audit_tasks"("p_task_ids" "uuid"[]) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role TEXT;
  v_user_id UUID;
  v_tenant_id UUID;
  v_deleted_count INTEGER := 0;
BEGIN
  -- Yetki kontrol├╝
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN json_build_object('success', false, 'error', 'Bu i┼şlem i├ğin yetkiniz yok');
  END IF;
  
  -- Tenant kontrol├╝
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  IF p_task_ids IS NULL OR array_length(p_task_ids, 1) IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Silinecek g├Ârev se├ğilmedi');
  END IF;
  
  -- ├ûnce foto─şraflar─▒ sil
  DELETE FROM visual_audit_photos 
  WHERE task_id = ANY(p_task_ids);
  
  -- Yorumlar─▒ sil
  DELETE FROM visual_audit_comments 
  WHERE task_id = ANY(p_task_ids);
  
  -- G├Ârevleri sil (sadece kendi tenant'─▒n─▒n g├Ârevlerini)
  WITH deleted AS (
    DELETE FROM visual_audit_tasks 
    WHERE id = ANY(p_task_ids) 
      AND tenant_id = v_tenant_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted;
  
  RETURN json_build_object('success', true, 'deleted', v_deleted_count);
END;
$$;


ALTER FUNCTION "public"."delete_visual_audit_tasks"("p_task_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_visual_audit_template"("p_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role TEXT;
  v_tenant_id UUID;
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    UPDATE visual_audit_templates SET is_active = FALSE, updated_at = NOW() WHERE id = p_id;
  ELSE
    v_tenant_id := current_tenant_id();
    UPDATE visual_audit_templates 
    SET is_active = FALSE, updated_at = NOW() 
    WHERE id = p_id AND tenant_id = v_tenant_id;
  END IF;
  
  RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."delete_visual_audit_template"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."depot_set_branch_name"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
    v_branch_name text;
begin
    select name into v_branch_name
    from public.branches
    where id = new.branch_id;

    new.branch_name = v_branch_name;
    return new;
end;
$$;


ALTER FUNCTION "public"."depot_set_branch_name"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."depot_touch_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
    NEW.updated_at = timezone('utc', now());
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."depot_touch_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."dispatch_skt_alarm_notifications"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_now timestamptz := now();
  v_warn_cutoff timestamptz := v_now + interval '1 day';
  rec record;
  tok record;
  notif_id uuid;
begin
  -- 1 g├╝n kala uyar─▒lar─▒
  for rec in
    select sr.id as record_id,
           sr.user_id,
           sr.tenant_id,
           sr.expiry_date,
           sr.alarm_date,
           p.name as product_name,
           b.name as branch_name
    from skt_records sr
      join products p on p.id = sr.product_id
      left join branches b on b.id = sr.branch_id
    where sr.alarm_warn_sent = false
      and sr.alarm_date <= v_warn_cutoff
      and sr.alarm_date >= v_now - interval '12 hour'
  loop
    insert into skt_alarm_notifications(
      record_id, user_id, tenant_id, type, scheduled_for, payload
    ) values (
      rec.record_id,
      rec.user_id,
      rec.tenant_id,
      'day_before',
      rec.alarm_date,
      jsonb_build_object(
        'productName', rec.product_name,
        'branchName', rec.branch_name,
        'expiryDate', rec.expiry_date
      )
    ) returning id into notif_id;

    for tok in select token from device_tokens where user_id = rec.user_id loop
      perform net.http_post(
        url := 'https://YOUR_FUNCTION_URL/skt-alarm-dispatcher',
        headers := jsonb_build_object('Content-Type','application/json'),
        body := jsonb_build_object(
          'notificationId', notif_id,
          'recordId', rec.record_id,
          'type', 'day_before',
          'token', tok.token,
          'title', rec.product_name,
          'body', format('%s ├╝r├╝n├╝ i├ğin SKT yakla┼ş─▒yor.', rec.product_name)
        )
      );
    end loop;

    update skt_records
      set alarm_warn_sent = true, alarm_warn_sent_at = now()
      where id = rec.record_id;
  end loop;

  -- G├╝n├╝ gelen uyar─▒lar
  for rec in
    select sr.id as record_id,
           sr.user_id,
           sr.tenant_id,
           sr.expiry_date,
           p.name as product_name,
           b.name as branch_name
    from skt_records sr
      join products p on p.id = sr.product_id
      left join branches b on b.id = sr.branch_id
    where sr.expiry_date <= v_now
      and sr.alarm_due_sent = false
  loop
    insert into skt_alarm_notifications(
      record_id, user_id, tenant_id, type, scheduled_for, payload
    ) values (
      rec.record_id,
      rec.user_id,
      rec.tenant_id,
      'due_day',
      rec.expiry_date,
      jsonb_build_object(
        'productName', rec.product_name,
        'branchName', rec.branch_name,
        'expiryDate', rec.expiry_date
      )
    ) returning id into notif_id;

    for tok in select token from device_tokens where user_id = rec.user_id loop
      perform net.http_post(
        url := 'https://YOUR_FUNCTION_URL/skt-alarm-dispatcher',
        headers := jsonb_build_object('Content-Type','application/json'),
        body := jsonb_build_object(
          'notificationId', notif_id,
          'recordId', rec.record_id,
          'type', 'due_day',
          'token', tok.token,
          'title', rec.product_name,
          'body', format('%s ├╝r├╝n├╝ bug├╝n son kullanma tarihinde.', rec.product_name)
        )
      );
    end loop;

    update skt_records
      set alarm_due_sent = true, alarm_due_sent_at = now()
      where id = rec.record_id;
  end loop;
end;
$$;


ALTER FUNCTION "public"."dispatch_skt_alarm_notifications"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."break_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "ended_at" timestamp with time zone,
    "duration_seconds" integer GENERATED ALWAYS AS (
CASE
    WHEN ("ended_at" IS NULL) THEN NULL::integer
    ELSE (GREATEST((1)::numeric, EXTRACT(epoch FROM ("ended_at" - "started_at"))))::integer
END) STORED,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."break_sessions" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."end_break_session"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS "public"."break_sessions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_session break_sessions;
BEGIN
  SELECT * INTO v_session
  FROM break_sessions
  WHERE user_id = p_user_id AND ended_at IS NULL
  ORDER BY started_at DESC
  LIMIT 1;

  IF v_session.id IS NULL THEN
    RAISE EXCEPTION 'Aktif mola bulunamad─▒';
  END IF;

  UPDATE break_sessions
  SET ended_at = now()
  WHERE id = v_session.id
  RETURNING * INTO v_session;

  RETURN v_session;
END;
$$;


ALTER FUNCTION "public"."end_break_session"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."execute_visual_audit_plan"("p_plan_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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
        RETURN json_build_object('success', false, 'error', 'Plan bulunamad─▒');
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


ALTER FUNCTION "public"."execute_visual_audit_plan"("p_plan_id" "uuid") OWNER TO "postgres";


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


ALTER FUNCTION "public"."generate_tasks_for_template"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_visual_audit_tasks"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."generate_visual_audit_tasks"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_visual_audit_tasks_for_date"("p_date" "date" DEFAULT CURRENT_DATE) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
    CONTINUE WHEN v_template.recurrence = 'weekly' AND NOT (v_day_of_week = ANY(v_template.weekly_days));
    CONTINUE WHEN v_template.recurrence = 'monthly' AND NOT (v_day_of_month = ANY(v_template.monthly_days));
    
    SELECT ARRAY_AGG(tb.branch_id) INTO v_branches
    FROM visual_audit_template_branches tb
    WHERE tb.template_id = v_template.id;
    
    IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
      IF v_template.branch_ids IS NULL OR array_length(v_template.branch_ids, 1) IS NULL THEN
        -- FIX: is_active instead of active
        SELECT ARRAY_AGG(b.id) INTO v_branches 
        FROM branches b 
        WHERE b.tenant_id = v_template.tenant_id AND b.is_active = TRUE;
      ELSE
        v_branches := v_template.branch_ids;
      END IF;
    END IF;
    
    SELECT ARRAY_AGG(ts.section_id) INTO v_sections
    FROM visual_audit_template_sections ts
    WHERE ts.template_id = v_template.id;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      v_sections := v_template.section_ids;
    END IF;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      CONTINUE;
    END IF;
    
    IF v_branches IS NOT NULL THEN
      FOREACH v_branch_id IN ARRAY v_branches
      LOOP
        FOREACH v_section_id IN ARRAY v_sections
        LOOP
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
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."generate_visual_audit_tasks_for_date"("p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_visual_audit_tasks_for_templates"("p_template_ids" "uuid"[], "p_date" "date" DEFAULT CURRENT_DATE) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_template RECORD;
  v_branch_id UUID;
  v_section_id UUID;
  v_time TEXT;
  v_count INTEGER := 0;
  v_branches UUID[];
  v_sections UUID[];
BEGIN
  FOR v_template IN 
    SELECT * FROM visual_audit_templates 
    WHERE id = ANY(p_template_ids)
      AND is_active = TRUE
  LOOP
    SELECT ARRAY_AGG(tb.branch_id) INTO v_branches
    FROM visual_audit_template_branches tb
    WHERE tb.template_id = v_template.id;
    
    IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
      -- FIX: is_active instead of active
      SELECT ARRAY_AGG(b.id) INTO v_branches 
      FROM branches b 
      WHERE b.tenant_id = v_template.tenant_id AND b.is_active = TRUE;
    END IF;
    
    SELECT ARRAY_AGG(ts.section_id) INTO v_sections
    FROM visual_audit_template_sections ts
    WHERE ts.template_id = v_template.id;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      v_sections := v_template.section_ids;
    END IF;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      CONTINUE;
    END IF;
    
    IF v_branches IS NOT NULL THEN
      FOREACH v_branch_id IN ARRAY v_branches
      LOOP
        FOREACH v_section_id IN ARRAY v_sections
        LOOP
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
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."generate_visual_audit_tasks_for_templates"("p_template_ids" "uuid"[], "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_all_tenants"() RETURNS TABLE("id" "uuid", "code" "text", "name" "text", "is_active" boolean, "total_users" bigint, "active_modules" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF current_user_role() != 'grand_admin' THEN
    RAISE EXCEPTION 'Bu fonksiyonu sadece Grand Admin ├ğa─ş─▒rabilir';
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.code,
    t.name,
    t.is_active,
    COUNT(DISTINCT u.id) as total_users,
    COUNT(DISTINCT tm.module_code) FILTER (WHERE tm.is_enabled = true) as active_modules
  FROM tenants t
  LEFT JOIN users u ON u.tenant_id = t.id AND u.is_active = true
  LEFT JOIN tenant_modules tm ON tm.tenant_id = t.id
  WHERE t.code != 'SYSTEM'
  GROUP BY t.id, t.code, t.name, t.is_active
  ORDER BY t.name;
END;
$$;


ALTER FUNCTION "public"."get_all_tenants"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS SETOF "public"."break_sessions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_mgr users;
  v_managed_region_ids uuid[];
BEGIN
  SELECT * INTO v_mgr FROM users WHERE id = p_user_id;

  IF v_mgr.id IS NULL THEN
    RAISE EXCEPTION 'Kullan─▒c─▒ bulunamad─▒';
  END IF;

  IF v_mgr.role = 'bolge_muduru'::user_role THEN
    -- Get regions where this user is the manager
    SELECT array_agg(id) INTO v_managed_region_ids
    FROM regions
    WHERE manager_id = p_user_id
      AND tenant_id = v_mgr.tenant_id;

    -- If no managed regions found, return empty
    IF v_managed_region_ids IS NULL OR array_length(v_managed_region_ids, 1) IS NULL THEN
      RETURN;
    END IF;

    RETURN QUERY
      SELECT bs.*
      FROM break_sessions bs
      JOIN branches b ON b.id = bs.branch_id
      WHERE b.region_id = ANY(v_managed_region_ids)
        AND bs.tenant_id = v_mgr.tenant_id
      ORDER BY bs.started_at DESC;

  ELSIF v_mgr.role = 'sube_muduru'::user_role THEN
    RETURN QUERY
      SELECT bs.*
      FROM break_sessions bs
      WHERE bs.branch_id = v_mgr.branch_id
        AND bs.tenant_id = v_mgr.tenant_id
      ORDER BY bs.started_at DESC;

  ELSIF v_mgr.role = 'firma_admin'::user_role THEN
    -- Firma admin can see all breaks in their tenant
    RETURN QUERY
      SELECT bs.*
      FROM break_sessions bs
      WHERE bs.tenant_id = v_mgr.tenant_id
      ORDER BY bs.started_at DESC;

  ELSE
    -- Regular users only see their own breaks
    RETURN QUERY
      SELECT * FROM break_sessions WHERE user_id = v_mgr.id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_branch_personnel"("p_branch_id" "uuid") RETURNS TABLE("id" "uuid", "first_name" "text", "last_name" "text", "role" "text", "branch_id" "uuid")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.first_name, u.last_name, u.role::text, u.branch_id
  FROM public.users u
  WHERE u.branch_id = p_branch_id
    AND u.role = 'personel'
  ORDER BY u.first_name;
END;
$$;


ALTER FUNCTION "public"."get_branch_personnel"("p_branch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") RETURNS TABLE("member_id" "uuid", "first_name" "text", "last_name" "text", "position" "text", "role" "public"."user_role", "phone" "text", "email" "text", "employee_code" "text", "branch_id" "uuid", "is_branch_manager" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_branch uuid;
  v_tenant uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik do─şrulamas─▒ gerekiyor';
  END IF;

  SELECT u.branch_id, u.tenant_id
    INTO v_branch, v_tenant
  FROM users u
  WHERE u.id = p_user_id;

  IF v_branch IS NULL THEN
    RAISE EXCEPTION 'Bu kullan─▒c─▒ herhangi bir ┼şubeye ba─şl─▒ de─şil';
  END IF;

  IF v_requester <> p_user_id THEN
    PERFORM 1
    FROM users u
    WHERE u.id = v_requester
      AND (
        u.role = 'grand_admin'::user_role OR
        (u.tenant_id = v_tenant AND u.role = ANY (ARRAY[
          'firma_admin'::user_role,
          'bolge_muduru'::user_role,
          'sube_muduru'::user_role
        ]))
      );

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Bu tak─▒m bilgisine eri┼şim yetkiniz yok';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    u.id AS member_id,
    u.first_name,
    u.last_name,
    u."position",
    u.role,
    u.phone,
    u.email,
    u.employee_code,
    u.branch_id,
    (u.role = 'sube_muduru') AS is_branch_manager
  FROM users u
  WHERE u.branch_id = v_branch
  ORDER BY u.first_name, u.last_name;
END;
$$;


ALTER FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_bug_reports"("p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("report_id" "uuid", "report_tenant_id" "uuid", "report_tenant_name" "text", "report_user_id" "uuid", "report_user_name" "text", "report_user_email" "text", "report_title" "text", "report_description" "text", "report_device_info" "jsonb", "report_app_version" "text", "report_status" "text", "report_priority" "text", "report_admin_notes" "text", "report_resolved_by" "uuid", "report_resolved_by_name" "text", "report_resolved_at" timestamp with time zone, "report_created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID;
    v_role TEXT;
BEGIN
    v_user_id := auth.uid();
    
    SELECT role INTO v_role
    FROM public.users
    WHERE public.users.id = v_user_id;
    
    IF v_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu i┼şlem i├ğin yetkiniz yok';
    END IF;
    
    RETURN QUERY
    SELECT 
        br.id,
        br.tenant_id,
        t.name::TEXT,
        br.user_id,
        (u.first_name || ' ' || u.last_name)::TEXT,
        au.email::TEXT,
        br.title::TEXT,
        br.description::TEXT,
        br.device_info,
        br.app_version::TEXT,
        br.status::TEXT,
        br.priority::TEXT,
        br.admin_notes::TEXT,
        br.resolved_by,
        (ru.first_name || ' ' || ru.last_name)::TEXT,
        br.resolved_at,
        br.created_at
    FROM public.bug_reports br
    LEFT JOIN public.tenants t ON t.id = br.tenant_id
    LEFT JOIN public.users u ON u.id = br.user_id
    LEFT JOIN auth.users au ON au.id = br.user_id
    LEFT JOIN public.users ru ON ru.id = br.resolved_by
    WHERE (p_status IS NULL OR br.status = p_status)
    ORDER BY 
        CASE br.priority 
            WHEN 'critical' THEN 1 
            WHEN 'high' THEN 2 
            WHEN 'normal' THEN 3 
            ELSE 4 
        END,
        br.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_bug_reports"("p_status" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_current_user_profile"() RETURNS TABLE("branch_id" "uuid", "tenant_id" "uuid", "region_id" "uuid")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT u.branch_id, u.tenant_id, b.region_id
    FROM public.users u
    LEFT JOIN public.branches b ON b.id = u.branch_id
    WHERE u.id = auth.uid();
END;
$$;


ALTER FUNCTION "public"."get_current_user_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_depot_notice_offer_counts"() RETURNS TABLE("notice_id" "uuid", "pending_count" bigint, "accepted_count" bigint, "rejected_count" bigint)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
    SELECT
        n.id AS notice_id,
        COUNT(*) FILTER (WHERE o.status = 'pending') AS pending_count,
        COUNT(*) FILTER (WHERE o.status = 'accepted') AS accepted_count,
        COUNT(*) FILTER (WHERE o.status = 'rejected') AS rejected_count
    FROM public.depot_notices n
    LEFT JOIN public.depot_notice_offers o ON o.notice_id = n.id
    WHERE n.tenant_id = current_tenant_id()
    GROUP BY n.id;
$$;


ALTER FUNCTION "public"."get_depot_notice_offer_counts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_announcements"("p_type" "text" DEFAULT NULL::"text", "p_include_expired" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant_id uuid;
  v_user_role user_role;
  v_branch_id uuid;
  v_region_id uuid;
BEGIN
  SELECT tenant_id, role, branch_id 
  INTO v_tenant_id, v_user_role, v_branch_id
  FROM public.users
  WHERE id = v_user_id;
  
  SELECT region_id INTO v_region_id FROM public.branches WHERE id = v_branch_id;
  
  RETURN (
    SELECT jsonb_build_object(
      'success', true,
      'announcements', COALESCE(jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'title', a.title,
          'content', a.content,
          'summary', a.summary,
          'cover_image_url', a.cover_image_url,
          'type', a.type,
          'published_at', a.published_at,
          'expires_at', a.expires_at,
          'pinned', a.pinned,
          'priority', a.priority,
          'is_read', EXISTS (
            SELECT 1 FROM public.announcement_reads ar 
            WHERE ar.announcement_id = a.id AND ar.user_id = v_user_id
          ),
          'is_responded', CASE WHEN a.type = 'survey' THEN EXISTS (
            SELECT 1 FROM public.survey_responses sr 
            WHERE sr.announcement_id = a.id AND sr.user_id = v_user_id
          ) ELSE NULL END,
          'question_count', CASE WHEN a.type = 'survey' THEN (
            SELECT COUNT(*) FROM public.survey_questions sq WHERE sq.announcement_id = a.id
          ) ELSE NULL END,
          'publisher', (
            SELECT jsonb_build_object(
              'id', u.id,
              'name', u.first_name || ' ' || u.last_name,
              'role', u.role
            )
            FROM public.users u WHERE u.id = a.published_by
          )
        )
        ORDER BY a.pinned DESC, a.priority DESC, a.published_at DESC
      ), '[]'::jsonb)
    )
    FROM public.announcements a
    WHERE a.tenant_id = v_tenant_id
      AND a.is_active = true
      AND (p_type IS NULL OR a.type::text = p_type)
      AND (p_include_expired OR a.expires_at IS NULL OR a.expires_at > now())
      AND (
        a.target_scope = 'all_branches'
        OR (a.target_scope = 'selected_branches' AND v_branch_id = ANY(a.target_branches))
        OR (a.target_scope = 'my_branches' AND v_region_id = ANY(a.target_regions))
        OR (a.target_scope = 'my_branch' AND (
          v_branch_id = ANY(a.target_branches)
          OR EXISTS (SELECT 1 FROM public.users u WHERE u.id = a.published_by AND u.branch_id = v_branch_id)
        ))
        OR (a.target_scope = 'region_managers_only' AND v_user_role = 'bolge_muduru')
        OR a.published_by = v_user_id
        OR (a.include_region_managers AND v_user_role = 'bolge_muduru')
      )
      AND (
        NOT a.managers_only 
        OR v_user_role IN ('sube_muduru', 'bolge_muduru', 'firma_admin', 'grand_admin')
      )
  );
END;
$$;


ALTER FUNCTION "public"."get_my_announcements"("p_type" "text", "p_include_expired" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_branch_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT branch_id FROM users WHERE id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_branch_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_managed_branch_ids"() RETURNS SETOF "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT b.id 
  FROM branches b
  INNER JOIN regions r ON r.id = b.region_id
  WHERE r.manager_id = auth.uid() AND r.tenant_id = current_tenant_id();
$$;


ALTER FUNCTION "public"."get_my_managed_branch_ids"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_role"() RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT role::TEXT FROM users WHERE id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_visual_audit_tasks"("p_date" "date" DEFAULT CURRENT_DATE, "p_status" "text" DEFAULT NULL::"text") RETURNS TABLE("id" "uuid", "template_id" "uuid", "template_name" "text", "section_id" "uuid", "section_name" "text", "section_icon" "text", "section_color" "text", "scheduled_date" "date", "scheduled_time" time without time zone, "deadline_at" timestamp with time zone, "status" "public"."visual_audit_task_status", "photo_count" bigint, "min_photos" integer, "completed_by" "uuid", "completed_at" timestamp with time zone, "is_overdue" boolean, "notes" "text", "title" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_branch_id UUID;
BEGIN
  -- Kullan─▒c─▒n─▒n ┼şubesini al
  SELECT u.branch_id INTO v_branch_id FROM users u WHERE u.id = current_user_id();
  
  IF v_branch_id IS NULL THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.template_id,
    -- template yoksa section name veya title kullan
    COALESCE(
      vt.name,
      t.title,
      s.name
    ) AS template_name,
    t.section_id,
    s.name AS section_name,
    s.icon AS section_icon,
    s.color AS section_color,
    t.scheduled_date,
    t.scheduled_time,
    t.deadline_at,
    t.status,
    COUNT(p.id) AS photo_count,
    COALESCE(t.min_photos, vt.min_photos, 1) AS min_photos,
    t.completed_by,
    t.completed_at,
    (t.deadline_at < now() AND t.status NOT IN ('completed', 'approved')) AS is_overdue,
    t.notes,
    COALESCE(t.title, s.name) AS title
  FROM visual_audit_tasks t
  LEFT JOIN visual_audit_templates vt ON vt.id = t.template_id
  JOIN visual_audit_sections s ON s.id = t.section_id
  LEFT JOIN visual_audit_photos p ON p.task_id = t.id
  WHERE t.branch_id = v_branch_id
    AND t.scheduled_date = p_date
    AND (p_status IS NULL OR t.status::TEXT = p_status)
  GROUP BY t.id, vt.name, vt.min_photos, s.name, s.icon, s.color
  ORDER BY t.scheduled_time, s.name;
END;
$$;


ALTER FUNCTION "public"."get_my_visual_audit_tasks"("p_date" "date", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") RETURNS TABLE("id" "uuid", "first_name" "text", "last_name" "text", "email" "text", "phone" "text", "position" "text", "role" "public"."user_role", "employee_code" "text", "hire_date" "date", "tenant_id" "uuid", "tenant_name" "text", "branch_id" "uuid", "branch_name" "text", "branch_code" "text", "branch_city" "text", "branch_district" "text", "branch_manager_id" "uuid", "branch_manager_first_name" "text", "branch_manager_last_name" "text", "branch_manager_phone" "text", "region_id" "uuid", "region_name" "text", "regional_manager_id" "uuid", "regional_manager_first_name" "text", "regional_manager_last_name" "text", "regional_manager_phone" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_target_tenant uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik do─şrulamas─▒ gerekiyor';
  END IF;

  SELECT u.tenant_id INTO v_target_tenant FROM users u WHERE u.id = p_user_id;
  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'Kullan─▒c─▒ bulunamad─▒';
  END IF;

  -- Kendisi d─▒┼ş─▒ndaki profillere eri┼şmek i├ğin ilgili tenant i├ğinde
  -- yetkili role sahip olmak gerekir.
  IF v_requester <> p_user_id THEN
    PERFORM 1
    FROM users u
    WHERE u.id = v_requester
      AND (
        u.role = 'grand_admin'::user_role OR
        (u.tenant_id = v_target_tenant AND u.role = ANY (
          ARRAY['firma_admin'::user_role, 'bolge_muduru'::user_role, 'sube_muduru'::user_role]
        ))
      );

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Bu profile eri┼şim yetkiniz yok';
    END IF;
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.first_name,
    u.last_name,
    u.email,
    u.phone,
    u."position",
    u.role,
    u.employee_code,
    u.hire_date,
    u.tenant_id,
    t.name AS tenant_name,
    u.branch_id,
    b.name AS branch_name,
    b.code AS branch_code,
    b.city AS branch_city,
    b.district AS branch_district,
    COALESCE(b.manager_id, fb.id) AS branch_manager_id,
    COALESCE(bm.first_name, fb.first_name) AS branch_manager_first_name,
    COALESCE(bm.last_name, fb.last_name) AS branch_manager_last_name,
    COALESCE(bm.phone, fb.phone) AS branch_manager_phone,
    r.id AS region_id,
    r.name AS region_name,
    r.manager_id AS regional_manager_id,
    rm.first_name AS regional_manager_first_name,
    rm.last_name AS regional_manager_last_name,
    rm.phone AS regional_manager_phone
  FROM users u
  LEFT JOIN tenants t ON t.id = u.tenant_id
  LEFT JOIN branches b ON b.id = u.branch_id
  LEFT JOIN users bm ON bm.id = b.manager_id
  LEFT JOIN LATERAL (
    SELECT lb.id, lb.first_name, lb.last_name, lb.phone
    FROM users lb
    WHERE lb.branch_id = b.id AND lb.role = 'sube_muduru'
    ORDER BY lb.created_at DESC
    LIMIT 1
  ) fb ON TRUE
  LEFT JOIN regions r ON r.id = b.region_id
  LEFT JOIN users rm ON rm.id = r.manager_id
  WHERE u.id = p_user_id
  LIMIT 1;
END;
$$;


ALTER FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_survey_results"("p_announcement_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user_role user_role;
  v_result jsonb;
BEGIN
  -- Get user role
  SELECT role INTO v_user_role FROM public.users WHERE id = v_user_id;
  
  -- Check access
  IF NOT EXISTS (
    SELECT 1 FROM public.announcements 
    WHERE id = p_announcement_id 
      AND (published_by = v_user_id OR v_user_role IN ('firma_admin', 'grand_admin'))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Eri┼şim yetkiniz yok');
  END IF;
  
  -- Build results
  SELECT jsonb_build_object(
    'success', true,
    'announcement_id', p_announcement_id,
    'total_responses', (
      SELECT COUNT(*) FROM public.survey_responses WHERE announcement_id = p_announcement_id
    ),
    'questions', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'question_id', sq.id,
          'question_text', sq.question_text,
          'question_type', sq.question_type,
          'options', sq.options,
          'answers', (
            SELECT jsonb_agg(
              jsonb_build_object(
                'user_id', sr.user_id,
                'user_name', u.first_name || ' ' || u.last_name,
                'branch_name', b.name,
                'answer_text', sa.answer_text,
                'answer_options', sa.answer_options,
                'answer_rating', sa.answer_rating,
                'answer_boolean', sa.answer_boolean,
                'submitted_at', sr.submitted_at
              )
            )
            FROM public.survey_answers sa
            JOIN public.survey_responses sr ON sr.id = sa.response_id
            JOIN public.users u ON u.id = sr.user_id
            LEFT JOIN public.branches b ON b.id = u.branch_id
            WHERE sa.question_id = sq.id
          ),
          'summary', CASE 
            WHEN sq.question_type IN ('single_choice', 'multiple_choice') THEN (
              SELECT jsonb_object_agg(
                opt.value,
                (
                  SELECT COUNT(*) 
                  FROM public.survey_answers sa2 
                  WHERE sa2.question_id = sq.id 
                    AND sa2.answer_options ? opt.value
                )
              )
              FROM jsonb_array_elements_text(sq.options) opt(value)
            )
            WHEN sq.question_type = 'rating' THEN (
              SELECT jsonb_build_object(
                'average', ROUND(AVG(sa.answer_rating)::numeric, 2),
                'count_1', COUNT(*) FILTER (WHERE sa.answer_rating = 1),
                'count_2', COUNT(*) FILTER (WHERE sa.answer_rating = 2),
                'count_3', COUNT(*) FILTER (WHERE sa.answer_rating = 3),
                'count_4', COUNT(*) FILTER (WHERE sa.answer_rating = 4),
                'count_5', COUNT(*) FILTER (WHERE sa.answer_rating = 5)
              )
              FROM public.survey_answers sa
              WHERE sa.question_id = sq.id
            )
            WHEN sq.question_type = 'yes_no' THEN (
              SELECT jsonb_build_object(
                'yes', COUNT(*) FILTER (WHERE sa.answer_boolean = true),
                'no', COUNT(*) FILTER (WHERE sa.answer_boolean = false)
              )
              FROM public.survey_answers sa
              WHERE sa.question_id = sq.id
            )
            ELSE NULL
          END
        )
        ORDER BY sq.sort_order
      )
      FROM public.survey_questions sq
      WHERE sq.announcement_id = p_announcement_id
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_survey_results"("p_announcement_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_branches"("p_tenant_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("id" "uuid", "name" "text", "code" "text", "city" "text", "district" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."get_tenant_branches"("p_tenant_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") RETURNS TABLE("module_code" "text", "module_name" "text", "module_icon" "text", "module_description" "text", "is_core" boolean, "is_enabled" boolean, "enabled_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF current_user_role() != 'grand_admin' AND current_tenant_id() != p_tenant_id THEN
    RAISE EXCEPTION 'Bu firmaya eri┼şim yetkiniz yok';
  END IF;
  
  RETURN QUERY
  SELECT 
    m.code,
    m.name,
    m.icon,
    m.description,
    m.is_core,
    COALESCE(tm.is_enabled, false) as is_enabled,
    tm.enabled_at
  FROM modules m
  LEFT JOIN tenant_modules tm ON tm.module_code = m.code AND tm.tenant_id = p_tenant_id
  WHERE m.is_active = true
  ORDER BY m.display_order;
END;
$$;


ALTER FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tenant_regions"() RETURNS TABLE("id" "uuid", "name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  SELECT u.tenant_id INTO v_tenant_id FROM public.users u WHERE u.id = auth.uid();
  
  RETURN QUERY
  SELECT r.id, r.name
  FROM public.regions r
  WHERE r.tenant_id = v_tenant_id
  ORDER BY r.name;
END;
$$;


ALTER FUNCTION "public"."get_tenant_regions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unread_notification_count"() RETURNS integer
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT count(*)::int
  FROM notifications
  WHERE user_id = auth.uid()
    AND read_at IS NULL;
$$;


ALTER FUNCTION "public"."get_unread_notification_count"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_bug_notifications"("p_unread_only" boolean DEFAULT false, "p_limit" integer DEFAULT 20) RETURNS TABLE("notification_id" "uuid", "bug_report_id" "uuid", "notification_title" "text", "notification_message" "text", "notification_type" "text", "is_read" boolean, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.bug_report_id,
        n.title::TEXT,
        n.message::TEXT,
        n.notification_type::TEXT,
        n.is_read,
        n.created_at
    FROM public.bug_report_notifications n
    WHERE n.user_id = auth.uid()
    AND (NOT p_unread_only OR n.is_read = FALSE)
    ORDER BY n.created_at DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_user_bug_notifications"("p_unread_only" boolean, "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") RETURNS TABLE("id" "text", "email" "text", "first_name" "text", "last_name" "text", "role" "text", "tenant_id" "text", "branch_id" "text", "employee_code" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT 
    id::TEXT, email::TEXT, first_name::TEXT, last_name::TEXT,
    role::TEXT, tenant_id::TEXT, branch_id::TEXT, employee_code::TEXT
  FROM users WHERE id = p_user_id::UUID LIMIT 1;
$$;


ALTER FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") RETURNS TABLE("email" "text", "is_active" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT email::TEXT, is_active FROM users WHERE employee_code = p_sicil_no LIMIT 1;
$$;


ALTER FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_modules"() RETURNS TABLE("module_code" "text", "module_name" "text", "module_icon" "text", "is_core" boolean, "display_order" integer, "is_visible" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id UUID;
BEGIN
  v_tenant_id := current_tenant_id();
  
  RETURN QUERY
  SELECT 
    m.code,
    m.name,
    m.icon,
    m.is_core,
    COALESCE(ump.display_order, m.display_order) as display_order,
    COALESCE(ump.is_visible, true) as is_visible
  FROM modules m
  INNER JOIN tenant_modules tm ON tm.module_code = m.code AND tm.tenant_id = v_tenant_id
  LEFT JOIN user_module_preferences ump ON ump.module_code = m.code AND ump.user_id = current_user_id()
  WHERE m.is_active = true AND tm.is_enabled = true
  ORDER BY COALESCE(ump.display_order, m.display_order);
END;
$$;


ALTER FUNCTION "public"."get_user_modules"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_comments"("p_task_id" "uuid") RETURNS TABLE("id" "uuid", "user_id" "uuid", "user_name" "text", "user_role" "text", "comment_type" "public"."visual_audit_comment_type", "message" "text", "photo_id" "uuid", "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS user_name,
    u.role::TEXT AS user_role,
    c.comment_type,
    c.message,
    c.photo_id,
    c.created_at
  FROM visual_audit_comments c
  JOIN users u ON u.id = c.user_id
  WHERE c.task_id = p_task_id
  ORDER BY c.created_at;
END;
$$;


ALTER FUNCTION "public"."get_visual_audit_comments"("p_task_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_plans"() RETURNS TABLE("id" "uuid", "name" "text", "section_ids" "uuid"[], "branch_ids" "uuid"[], "section_names" "text"[], "branch_names" "text"[], "scheduled_hour" integer, "deadline_minutes" integer, "min_photos" integer, "notes" "text", "recurrence" "text", "recurrence_days" integer[], "start_date" "date", "end_date" "date", "is_active" boolean, "created_by" "uuid", "created_by_name" "text", "created_at" timestamp with time zone, "total_tasks" bigint, "completed_tasks" bigint, "pending_tasks" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
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


ALTER FUNCTION "public"."get_visual_audit_plans"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_sections"() RETURNS TABLE("id" "uuid", "name" "text", "description" "text", "icon" "text", "color" "text", "display_order" integer, "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id UUID;
  v_role TEXT;
BEGIN
  v_role := current_user_role();
  
  IF v_role = 'grand_admin' THEN
    -- Grand admin t├╝m tenant'lar─▒n b├Âl├╝mlerini g├Ârebilir (ilk tenant i├ğin)
    SELECT t.id INTO v_tenant_id FROM tenants t LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  RETURN QUERY
  SELECT 
    s.id,
    s.name,
    s.description,
    s.icon,
    s.color,
    s.display_order,
    s.is_active
  FROM visual_audit_sections s
  WHERE s.tenant_id = v_tenant_id
    AND s.is_active = true
  ORDER BY s.display_order, s.name;
END;
$$;


ALTER FUNCTION "public"."get_visual_audit_sections"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_stats"("p_date" "date" DEFAULT NULL::"date") RETURNS TABLE("total_tasks" bigint, "pending_tasks" bigint, "completed_tasks" bigint, "overdue_tasks" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role TEXT;
  v_tenant_id UUID;
  v_user_branch_id UUID;
  v_user_id UUID;
BEGIN
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role = 'grand_admin' THEN
    SELECT tenants.id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  IF v_role IN ('sube_muduru', 'personel') THEN
    SELECT users.branch_id INTO v_user_branch_id FROM users WHERE users.id = v_user_id;
  END IF;
  
  RETURN QUERY
  SELECT 
    COUNT(*) AS total_tasks,
    COUNT(*) FILTER (WHERE t.status = 'pending') AS pending_tasks,
    COUNT(*) FILTER (WHERE t.status = 'completed') AS completed_tasks,
    COUNT(*) FILTER (WHERE t.status = 'pending' AND t.deadline_at < NOW()) AS overdue_tasks
  FROM visual_audit_tasks t
  WHERE t.tenant_id = v_tenant_id
    AND (p_date IS NULL OR t.scheduled_date = p_date)
    AND (v_user_branch_id IS NULL OR t.branch_id = v_user_branch_id);
END;
$$;


ALTER FUNCTION "public"."get_visual_audit_stats"("p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_task_photos"("p_task_id" "uuid") RETURNS TABLE("id" "uuid", "photo_url" "text", "thumbnail_url" "text", "caption" "text", "uploaded_by" "uuid", "uploader_name" "text", "latitude" double precision, "longitude" double precision, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.photo_url,
    p.thumbnail_url,
    p.caption,
    p.uploaded_by,
    CONCAT(u.first_name, ' ', u.last_name) AS uploader_name,
    p.latitude,
    p.longitude,
    p.created_at
  FROM visual_audit_photos p
  JOIN users u ON u.id = p.uploaded_by
  WHERE p.task_id = p_task_id
  ORDER BY p.created_at;
END;
$$;


ALTER FUNCTION "public"."get_visual_audit_task_photos"("p_task_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_tasks"("p_date" "date" DEFAULT NULL::"date", "p_status" "text" DEFAULT NULL::"text", "p_branch_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("id" "uuid", "branch_id" "uuid", "branch_name" "text", "section_id" "uuid", "section_name" "text", "section_color" "text", "status" "text", "scheduled_date" "date", "scheduled_time" time without time zone, "deadline_at" timestamp with time zone, "min_photos" integer, "notes" "text", "created_by" "uuid", "created_by_name" "text", "created_at" timestamp with time zone, "completed_at" timestamp with time zone, "photo_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role TEXT;
  v_user_id UUID;
  v_tenant_id UUID;
  v_user_branch_id UUID;
BEGIN
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role = 'grand_admin' THEN
    SELECT tenants.id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  IF v_role IN ('sube_muduru', 'personel') THEN
    SELECT users.branch_id INTO v_user_branch_id FROM users WHERE users.id = v_user_id;
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.branch_id,
    b.name AS branch_name,
    t.section_id,
    s.name AS section_name,
    s.color AS section_color,
    t.status::TEXT AS status,
    t.scheduled_date,
    t.scheduled_time,
    t.deadline_at,
    COALESCE(t.min_photos, 1) AS min_photos,
    t.notes,
    t.created_by,
    CONCAT(u.first_name, ' ', u.last_name) AS created_by_name,
    t.created_at,
    t.completed_at,
    (SELECT COUNT(*) FROM visual_audit_photos p WHERE p.task_id = t.id) AS photo_count
  FROM visual_audit_tasks t
  JOIN branches b ON b.id = t.branch_id
  JOIN visual_audit_sections s ON s.id = t.section_id
  LEFT JOIN users u ON u.id = t.created_by
  WHERE t.tenant_id = v_tenant_id
    AND (p_date IS NULL OR t.scheduled_date = p_date)
    AND (p_status IS NULL OR t.status::TEXT = p_status)
    AND (p_branch_id IS NULL OR t.branch_id = p_branch_id)
    AND (v_user_branch_id IS NULL OR t.branch_id = v_user_branch_id)
  ORDER BY t.deadline_at DESC NULLS LAST, t.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_visual_audit_tasks"("p_date" "date", "p_status" "text", "p_branch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_tasks_for_manager"("p_date" "date" DEFAULT CURRENT_DATE, "p_branch_id" "uuid" DEFAULT NULL::"uuid", "p_section_id" "uuid" DEFAULT NULL::"uuid", "p_status" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "template_name" "text", "section_id" "uuid", "section_name" "text", "section_color" "text", "branch_id" "uuid", "branch_name" "text", "scheduled_date" "date", "scheduled_time" time without time zone, "deadline_at" timestamp with time zone, "status" "public"."visual_audit_task_status", "photo_count" bigint, "min_photos" integer, "completed_by_name" "text", "completed_at" timestamp with time zone, "is_overdue" boolean, "total_count" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id UUID;
  v_role TEXT;
BEGIN
  v_tenant_id := current_tenant_id();
  v_role := current_user_role();
  
  IF v_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru', 'grand_admin') THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  WITH filtered AS (
    SELECT 
      t.id,
      vt.name AS template_name,
      t.section_id,
      s.name AS section_name,
      s.color AS section_color,
      t.branch_id,
      b.name AS branch_name,
      t.scheduled_date,
      t.scheduled_time,
      t.deadline_at,
      t.status,
      COUNT(p.id) AS photo_count,
      vt.min_photos,
      CONCAT(cu.first_name, ' ', cu.last_name) AS completed_by_name,
      t.completed_at,
      (t.deadline_at < now() AND t.status NOT IN ('completed', 'approved')) AS is_overdue
    FROM visual_audit_tasks t
    JOIN visual_audit_templates vt ON vt.id = t.template_id
    JOIN visual_audit_sections s ON s.id = t.section_id
    JOIN branches b ON b.id = t.branch_id
    LEFT JOIN visual_audit_photos p ON p.task_id = t.id
    LEFT JOIN users cu ON cu.id = t.completed_by
    WHERE t.tenant_id = v_tenant_id
      AND (p_date IS NULL OR t.scheduled_date = p_date)
      AND (p_branch_id IS NULL OR t.branch_id = p_branch_id)
      AND (p_section_id IS NULL OR t.section_id = p_section_id)
      AND (p_status IS NULL OR t.status::TEXT = p_status)
    GROUP BY t.id, vt.name, vt.min_photos, s.name, s.color, b.name, cu.first_name, cu.last_name
  )
  SELECT 
    f.*,
    (SELECT COUNT(*) FROM filtered) AS total_count
  FROM filtered f
  ORDER BY f.scheduled_date DESC, f.scheduled_time, f.branch_name
  LIMIT p_limit OFFSET p_offset;
END;
$$;


ALTER FUNCTION "public"."get_visual_audit_tasks_for_manager"("p_date" "date", "p_branch_id" "uuid", "p_section_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_template_detail"("p_id" "uuid") RETURNS TABLE("id" "uuid", "name" "text", "description" "text", "section_ids" "uuid"[], "branch_ids" "uuid"[], "recurrence" "text", "weekly_days" integer[], "monthly_days" integer[], "scheduled_times" "text"[], "deadline_minutes" integer, "min_photos" integer, "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role TEXT;
  v_tenant_id UUID;
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    RETURN QUERY
    SELECT 
      t.id,
      t.name,
      t.description,
      ARRAY(SELECT ts.section_id FROM visual_audit_template_sections ts WHERE ts.template_id = t.id ORDER BY ts.display_order),
      ARRAY(SELECT tb.branch_id FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      t.recurrence::TEXT,
      t.weekly_days,
      t.monthly_days,
      t.scheduled_times,
      t.deadline_minutes,
      t.min_photos,
      t.is_active
    FROM visual_audit_templates t
    WHERE t.id = p_id;
  ELSE
    v_tenant_id := current_tenant_id();
    RETURN QUERY
    SELECT 
      t.id,
      t.name,
      t.description,
      ARRAY(SELECT ts.section_id FROM visual_audit_template_sections ts WHERE ts.template_id = t.id ORDER BY ts.display_order),
      ARRAY(SELECT tb.branch_id FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      t.recurrence::TEXT,
      t.weekly_days,
      t.monthly_days,
      t.scheduled_times,
      t.deadline_minutes,
      t.min_photos,
      t.is_active
    FROM visual_audit_templates t
    WHERE t.id = p_id AND t.tenant_id = v_tenant_id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."get_visual_audit_template_detail"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_templates_for_manager"() RETURNS TABLE("id" "uuid", "name" "text", "description" "text", "section_names" "text"[], "branch_count" bigint, "recurrence" "text", "scheduled_times" "text"[], "is_active" boolean, "created_by_name" "text", "created_at" timestamp with time zone)
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


ALTER FUNCTION "public"."get_visual_audit_templates_for_manager"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_visual_audit_templates_list"() RETURNS TABLE("id" "uuid", "name" "text", "description" "text", "section_names" "text"[], "branch_count" bigint, "recurrence" "text", "scheduled_times" "text"[], "is_active" boolean, "created_by_name" "text", "created_at" timestamp with time zone)
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


ALTER FUNCTION "public"."get_visual_audit_templates_list"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grand_admin_list_tenants"() RETURNS TABLE("id" "uuid", "name" "text", "code" "text", "is_active" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select id, name, code, is_active
  from public.tenants
  where is_active = true
  order by name;
$$;


ALTER FUNCTION "public"."grand_admin_list_tenants"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_offer_cancellation"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'accepted' AND NEW.status = 'cancelled' THEN
            UPDATE public.depot_notices n
            SET quantity = n.quantity + OLD.quantity,
                status = CASE
                    WHEN EXISTS (
                        SELECT 1 FROM public.depot_notice_offers o
                        WHERE o.notice_id = n.id
                          AND o.status = 'accepted'
                          AND o.id <> NEW.id
                    ) THEN 'in_transfer'::public.depot_notice_status
                    ELSE 'open'::public.depot_notice_status
                END
            WHERE n.id = NEW.notice_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_offer_cancellation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_service_role"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
  select auth.role() = 'service_role';
$$;


ALTER FUNCTION "public"."is_service_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_edge_functions"() RETURNS TABLE("name" "text", "version" "text", "deployed_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if exists (select 1 from pg_namespace where nspname = 'supabase_functions') then
    return query
    select
      f.name::text,
      coalesce(f.ver::text, '0') as version,
      f.created_at as deployed_at
    from supabase_functions.functions f
    order by f.created_at desc;
  else
    return;
  end if;
end;
$$;


ALTER FUNCTION "public"."list_edge_functions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_rls_policies"() RETURNS TABLE("schema_name" "text", "table_name" "text", "policy" "text", "command" "text", "roles" "text"[], "permissive" "text", "using_sql" "text", "check_sql" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    schemaname::text      as schema_name,
    tablename::text       as table_name,
    policyname::text      as policy,
    cmd::text             as command,
    roles::text[]         as roles,
    permissive::text      as permissive,
    qual::text            as using_sql,
    with_check::text      as check_sql
  from pg_policies
  where schemaname not in ('pg_catalog', 'information_schema')
  order by schemaname, tablename, policyname;
$$;


ALTER FUNCTION "public"."list_rls_policies"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_all_bug_notifications_read"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE public.bug_report_notifications
    SET is_read = TRUE, read_at = NOW()
    WHERE user_id = auth.uid() AND is_read = FALSE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."mark_all_bug_notifications_read"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_all_notifications_read"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE notifications
  SET read_at = now()
  WHERE user_id = auth.uid()
    AND read_at IS NULL;
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."mark_all_notifications_read"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_bug_notification_read"("p_notification_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
    UPDATE public.bug_report_notifications
    SET is_read = TRUE, read_at = NOW()
    WHERE id = p_notification_id AND user_id = auth.uid();
    
    RETURN FOUND;
END;
$$;


ALTER FUNCTION "public"."mark_bug_notification_read"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  UPDATE notifications
  SET read_at = now()
  WHERE id = p_notification_id
    AND user_id = auth.uid()
    AND read_at IS NULL;
  
  RETURN FOUND;
END;
$$;


ALTER FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_announcement_published"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."notify_announcement_published"() OWNER TO "postgres";


COMMENT ON FUNCTION "public"."notify_announcement_published"() IS 'Duyuru veya anket yay─▒nland─▒─ş─▒nda hedef kitleye push bildirim g├Ânderir';



CREATE OR REPLACE FUNCTION "public"."notify_bug_report_status_change"("p_report_id" "uuid", "p_new_status" "text", "p_admin_message" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID;
    v_report_title TEXT;
    v_notification_title TEXT;
    v_notification_message TEXT;
    v_notification_type TEXT;
BEGIN
    -- Rapor bilgilerini al
    SELECT user_id, title INTO v_user_id, v_report_title
    FROM public.bug_reports
    WHERE id = p_report_id;
    
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Duruma g├Âre bildirim i├ğeri─şini belirle
    CASE p_new_status
        WHEN 'in_progress' THEN
            v_notification_title := 'Bildiriminiz ─░┼şleme Al─▒nd─▒';
            v_notification_message := 'Bildirdi─şiniz "' || v_report_title || '" hatas─▒ incelemeye al─▒nd─▒.';
            v_notification_type := 'status_change';
        WHEN 'closed' THEN
            v_notification_title := 'Bildiriminiz ├ç├Âz├╝ld├╝';
            v_notification_message := 'Bildirdi─şiniz "' || v_report_title || '" hatas─▒ ├ğ├Âz├╝ld├╝. Te┼şekk├╝r ederiz!';
            v_notification_type := 'resolved';
        ELSE
            RETURN FALSE;
    END CASE;
    
    -- Admin mesaj─▒ varsa ekle
    IF p_admin_message IS NOT NULL AND p_admin_message != '' THEN
        v_notification_message := v_notification_message || E'\n\nY├Ânetici notu: ' || p_admin_message;
    END IF;
    
    -- Bildirim olu┼ştur
    INSERT INTO public.bug_report_notifications (
        bug_report_id,
        user_id,
        title,
        message,
        notification_type
    ) VALUES (
        p_report_id,
        v_user_id,
        v_notification_title,
        v_notification_message,
        v_notification_type
    );
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."notify_bug_report_status_change"("p_report_id" "uuid", "p_new_status" "text", "p_admin_message" "text") OWNER TO "postgres";


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

  SELECT COALESCE(first_name || ' ' || last_name, 'Kullan─▒c─▒') INTO v_commenter_name
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
      '­şÆ¼ G├Ârsel Denetime Yorum Eklendi',
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


ALTER FUNCTION "public"."notify_visual_audit_comment_added"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_visual_audit_completed"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_task record;
  v_notify_ids uuid[];
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    SELECT t.*, b.name as branch_name, b.tenant_id
    INTO v_task
    FROM visual_audit_tasks t
    JOIN branches b ON b.id = t.branch_id
    WHERE t.id = NEW.id;

    IF v_task IS NULL THEN
      RETURN NEW;
    END IF;

    -- Use VALID enum values: firma_admin, bolge_muduru (NOT genel_mudur, patron)
    SELECT array_agg(id)
    INTO v_notify_ids
    FROM users
    WHERE tenant_id = v_task.tenant_id
      AND role::text IN ('firma_admin', 'bolge_muduru')
      AND is_active = true;

    IF v_notify_ids IS NOT NULL AND array_length(v_notify_ids, 1) > 0 THEN
      PERFORM send_notification(
        v_task.tenant_id,
        v_notify_ids,
        'visual_audit_completed',
        'Ô£à G├Ârsel Denetim Tamamland─▒',
        format('%s ┼şubesinde g├Ârsel denetim tamamland─▒', v_task.branch_name),
        jsonb_build_object(
          'task_id', NEW.id,
          'branch_id', v_task.branch_id,
          'route', '/visual-audit/' || NEW.id
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_visual_audit_completed"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_visual_audit_photo_uploaded"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
      '­şôÀ G├Ârsel Denetim Foto─şraf─▒ Y├╝klendi',
      format('%s ┼şubesinden %s foto─şraf y├╝kledi',
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


ALTER FUNCTION "public"."notify_visual_audit_photo_uploaded"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_visual_audit_task_completed"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
      'Ô£à G├Ârsel Denetim Tamamland─▒',
      format('%s ┼şubesi %s denetimini tamamlad─▒',
        v_branch.name,
        COALESCE(v_section_name, 'G├Ârsel Denetim')
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


ALTER FUNCTION "public"."notify_visual_audit_task_completed"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_visual_audit_task_created"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
    '­şô© Yeni G├Ârsel Denetim G├Ârevi',
    format('%s b├Âl├╝m├╝ i├ğin foto─şraf ├ğekmeniz isteniyor. Deadline: %s',
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


ALTER FUNCTION "public"."notify_visual_audit_task_created"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."region_manager_create_personnel"("p_branch_id" "uuid", "p_employee_code" "text", "p_password" "text", "p_first_name" "text", "p_last_name" "text", "p_role" "public"."user_role", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_position" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_branch RECORD;
  v_result jsonb;
  v_user_id uuid;
  v_generated_email text;
  v_final_email text;
  v_employee_code text;
  v_password text;
  v_custom_email text;
  v_first_name text := COALESCE(NULLIF(TRIM(p_first_name), ''), 'Yeni');
  v_last_name text := COALESCE(NULLIF(TRIM(p_last_name), ''), 'Personel');
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik do─şrulamas─▒ gerekiyor';
  END IF;

  -- FIX: is_active instead of active
  SELECT b.id, b.tenant_id, b.region_id
    INTO v_branch
  FROM public.branches b
  WHERE b.id = p_branch_id AND b.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION '┼Şube bulunamad─▒ veya aktif de─şil';
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_branch.region_id
    AND r.tenant_id = v_branch.tenant_id
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu ┼şube ├╝zerinde yetkiniz yok';
  END IF;

  IF p_role NOT IN ('personel', 'sube_muduru') THEN
    RAISE EXCEPTION 'Ge├ğersiz rol: %', p_role;
  END IF;

  v_employee_code := NULLIF(TRIM(p_employee_code), '');
  IF v_employee_code IS NULL THEN
    RAISE EXCEPTION 'Personel kodu gerekli';
  END IF;

  PERFORM 1
    FROM public.users u
   WHERE u.tenant_id = v_branch.tenant_id
     AND u.employee_code = v_employee_code
   LIMIT 1;
  IF FOUND THEN
    RAISE EXCEPTION 'Bu personel kodu zaten kullan─▒l─▒yor';
  END IF;

  v_password := NULLIF(TRIM(p_password), '');
  IF v_password IS NULL OR LENGTH(v_password) < 6 THEN
    RAISE EXCEPTION '┼Şifre en az 6 karakter olmal─▒';
  END IF;

  v_custom_email := NULLIF(TRIM(p_email), '');
  IF v_custom_email IS NOT NULL THEN
    PERFORM 1
      FROM auth.users au
     WHERE LOWER(au.email) = LOWER(v_custom_email)
     LIMIT 1;
    IF FOUND THEN
      RAISE EXCEPTION 'Bu e-posta adresi zaten kay─▒tl─▒';
    END IF;
  END IF;

  v_result := public.add_personel(v_employee_code, v_password, v_branch.tenant_id);

  IF COALESCE((v_result->>'success')::boolean, FALSE) IS FALSE THEN
    RAISE EXCEPTION 'Personel olu┼şturulamad─▒: %', v_result->>'error';
  END IF;

  v_user_id := (v_result->>'user_id')::uuid;
  v_generated_email := v_result->>'email';
  v_final_email := COALESCE(v_custom_email, v_generated_email);

  -- FIX: is_active instead of active
  UPDATE public.users
  SET first_name = v_first_name,
      last_name = v_last_name,
      email = v_final_email,
      phone = NULLIF(TRIM(p_phone), ''),
      "position" = NULLIF(TRIM(p_position), ''),
      branch_id = p_branch_id,
      role = p_role,
      is_active = TRUE,
      updated_at = NOW()
  WHERE id = v_user_id;

  UPDATE auth.users
  SET email = v_final_email,
      email_confirmed_at = NOW(),
      updated_at = NOW()
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'user_id', v_user_id,
    'email', v_final_email
  );
END;
$$;


ALTER FUNCTION "public"."region_manager_create_personnel"("p_branch_id" "uuid", "p_employee_code" "text", "p_password" "text", "p_first_name" "text", "p_last_name" "text", "p_role" "public"."user_role", "p_email" "text", "p_phone" "text", "p_position" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."region_manager_get_branch_personnel"("p_branch_id" "uuid") RETURNS TABLE("member_id" "uuid", "first_name" "text", "last_name" "text", "email" "text", "phone" "text", "employee_code" "text", "role" "public"."user_role", "position" "text", "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_branch RECORD;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik do─şrulamas─▒ gerekiyor';
  END IF;

  SELECT b.id, b.tenant_id, b.region_id
    INTO v_branch
  FROM public.branches b
  WHERE b.id = p_branch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION '┼Şube bulunamad─▒';
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_branch.region_id
    AND r.tenant_id = v_branch.tenant_id
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu ┼şube ├╝zerinde yetkiniz yok';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.first_name,
    u.last_name,
    u.email,
    u.phone,
    u.employee_code,
    u.role,
    u."position",
    u.is_active
  FROM public.users u
  WHERE u.branch_id = p_branch_id
    AND u.tenant_id = v_branch.tenant_id
    AND u.is_active
  ORDER BY u.first_name, u.last_name;
END;
$$;


ALTER FUNCTION "public"."region_manager_get_branch_personnel"("p_branch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."region_manager_remove_personnel"("p_personnel_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_target RECORD;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik do─şrulamas─▒ gerekiyor';
  END IF;

  SELECT u.*, b.region_id, b.tenant_id AS branch_tenant
    INTO v_target
  FROM public.users u
  LEFT JOIN public.branches b ON b.id = u.branch_id
  WHERE u.id = p_personnel_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Personel bulunamad─▒';
  END IF;

  IF v_target.branch_id IS NULL THEN
    RAISE NOTICE 'Personel zaten ┼şubeye ba─şl─▒ de─şil';
    RETURN;
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_target.region_id
    AND r.tenant_id = v_target.branch_tenant
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu personel ├╝zerinde yetkiniz yok';
  END IF;

  -- FIX: is_active instead of active
  UPDATE public.users
  SET branch_id = NULL,
      is_active = FALSE,
      role = 'personel',
      updated_at = NOW()
  WHERE id = v_target.id;
END;
$$;


ALTER FUNCTION "public"."region_manager_remove_personnel"("p_personnel_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."region_manager_update_personnel_role"("p_personnel_id" "uuid", "p_role" "public"."user_role") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_target RECORD;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik do─şrulamas─▒ gerekiyor';
  END IF;

  SELECT u.*, b.region_id, b.tenant_id AS branch_tenant
    INTO v_target
  FROM public.users u
  LEFT JOIN public.branches b ON b.id = u.branch_id
  WHERE u.id = p_personnel_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Personel bulunamad─▒';
  END IF;

  IF v_target.branch_id IS NULL THEN
    RAISE EXCEPTION 'Personel herhangi bir ┼şubeye ba─şl─▒ de─şil';
  END IF;

  IF p_role NOT IN ('personel', 'sube_muduru') THEN
    RAISE EXCEPTION 'Ge├ğersiz rol: %', p_role;
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_target.region_id
    AND r.tenant_id = v_target.branch_tenant
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu personel ├╝zerinde yetkiniz yok';
  END IF;

  UPDATE public.users
  SET role = p_role,
      updated_at = NOW()
  WHERE id = v_target.id;
END;
$$;


ALTER FUNCTION "public"."region_manager_update_personnel_role"("p_personnel_id" "uuid", "p_role" "public"."user_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_device_token"("p_user_id" "uuid", "p_tenant_id" "uuid", "p_token" "text", "p_platform" "text" DEFAULT 'android'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
  v_existing_id uuid;
  v_now timestamptz := now();
BEGIN
  -- Validate platform
  IF p_platform NOT IN ('android', 'ios', 'other') THEN
    p_platform := 'other';
  END IF;

  -- Check if token already exists for this user
  SELECT id INTO v_existing_id
  FROM device_tokens
  WHERE user_id = p_user_id AND token = p_token;

  IF v_existing_id IS NOT NULL THEN
    -- Token exists for this user, just update timestamps
    UPDATE device_tokens
    SET updated_at = v_now,
        last_seen_at = v_now
    WHERE id = v_existing_id;
    
    RETURN jsonb_build_object(
      'success', true,
      'action', 'updated',
      'id', v_existing_id
    );
  END IF;

  -- Check if token exists for another user (device changed hands)
  SELECT id INTO v_existing_id
  FROM device_tokens
  WHERE token = p_token AND user_id != p_user_id;

  IF v_existing_id IS NOT NULL THEN
    -- Delete the old token record (device now belongs to new user)
    DELETE FROM device_tokens WHERE id = v_existing_id;
  END IF;

  -- Delete old tokens for this user (keep only the current device)
  DELETE FROM device_tokens
  WHERE user_id = p_user_id AND token != p_token;

  -- Insert new token
  INSERT INTO device_tokens (user_id, tenant_id, token, platform, updated_at, last_seen_at)
  VALUES (p_user_id, p_tenant_id, p_token, p_platform, v_now, v_now)
  RETURNING id INTO v_existing_id;

  RETURN jsonb_build_object(
    'success', true,
    'action', 'inserted',
    'id', v_existing_id
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;


ALTER FUNCTION "public"."register_device_token"("p_user_id" "uuid", "p_tenant_id" "uuid", "p_token" "text", "p_platform" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."register_device_token"("p_user_id" "uuid", "p_tenant_id" "uuid", "p_token" "text", "p_platform" "text") IS 'Registers a device token for push notifications. 
Handles device ownership changes by removing old records.
Uses SECURITY DEFINER to bypass RLS restrictions.';



CREATE OR REPLACE FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
DECLARE
  v_user_id UUID;
  v_hashed_password TEXT;
BEGIN
  -- User ID bul
  SELECT id INTO v_user_id 
  FROM auth.users 
  WHERE email = p_email;
  
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Kullan─▒c─▒ bulunamad─▒');
  END IF;
  
  -- ┼Şifreyi hash'le (bcrypt benzeri basit y├Ântem)
  v_hashed_password := crypt(p_new_password, gen_salt('bf'));
  
  -- Auth tablosunda g├╝ncelle
  UPDATE auth.users
  SET 
    encrypted_password = v_hashed_password,
    updated_at = NOW()
  WHERE id = v_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', '┼Şifre g├╝ncellendi'
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text" DEFAULT 'STORE_STANDARD'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_existing uuid;
  v_form_id uuid;
  v_version_id uuid;
  v_section_id uuid;
  v_section_index integer := 0;
  v_item_index integer;
  rec_section record;
  item_text text;
  v_sections jsonb := jsonb_build_array(
    jsonb_build_object(
      'title', 'GENEL',
      'items', jsonb_build_array(
        'Ma─şaza d─▒┼ş alan─▒; otopark temizli─şi ve d├╝zeni, cam, sticker ve do─şrama temizli─şi',
        'Ma─şazadan d─▒┼ş alana a├ğ─▒lan kap─▒ ve pencerelerde ha┼şereÔÇôkemirgen giri┼şini engelleyecek ├Ânlemlerin kontrol├╝',
        'Ma─şaza s─▒f─▒r ├╝r├╝n say─▒s─▒ (ma─şaza kaynakl─▒ s─▒f─▒r say─▒s─▒ 10 adet ├╝zeri ise puan verilmez)',
        'M├╝┼şteri arabas─▒ ve m├╝┼şteri sepeti temizlik ve konumland─▒rma',
        'Kasa b├Âlgesi standartlar─▒ (etiket, po┼şet, optik okuyucular, kasa ├╝st├╝ te┼şhir)',
        'Macao dolap k─▒rm─▒z─▒ ├ğizgi, doluluk, etiket ve temizlik'
      )
    ),
    jsonb_build_object(
      'title', 'MANAV',
      'items', jsonb_build_array(
        'Manav b├Âl├╝m├╝ doluluk ve RYS',
        'Manav b├Âl├╝m├╝ tazelik ve bile┼şeleme (kalite standart temellendirilmeli)',
        'Manav b├Âl├╝m├╝ eksik etiket ve k├╝nye',
        'Manav b├Âl├╝m├╝ AHT etiket, doluluk, k─▒rm─▒z─▒ ├ğizgi ve temizlik',
        'Manav b├Âl├╝m├╝ so─şuk dolap (+4) temizlik, doluluk ve etiket',
        'Manav haz─▒rl─▒k odas─▒ ve so─şuk oda temizlik, d├╝zen ve kalite temelli kontrol (s─▒cakl─▒k ve temizlik formu, tan─▒ml─▒ kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'UNLU',
      'items', jsonb_build_array(
        'Unlu servis/distriyel ekmek doluluk & RYS & SKT/RKS',
        'Unlu servis b├Âl├╝m├╝ ekipman, doluluk ve RYS',
        'Unlu servis b├Âl├╝m├╝ izlenebilirlik',
        'Unlu servis b├Âl├╝m├╝ ├ğ├Âz├╝nd├╝rme, pi┼şirme adetler ve ├╝retim standard─▒ kontrol├╝ (fazla pi┼şme, ├ği─ş kalma, hamurla┼şma)',
        'Unlu b├Âl├╝m AHT etiket, doluluk, k─▒rm─▒z─▒ ├ğizgi ve temizlik',
        'Unlu haz─▒rl─▒k odas─▒ ve so─şuk oda temizlik, d├╝zen ve kalite temelli kontrol (s─▒cakl─▒k ve temizlik formu, tan─▒ml─▒ kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'KASAP / ┼ŞARK├£TER─░',
      'items', jsonb_build_array(
        'Kasap ┼şark├╝teri b├Âl├╝m├╝ tazelik, doluluk ve RYS',
        'Kasap ┼şark├╝teri b├Âl├╝m├╝ izlenebilirlik',
        'Kasap ┼şark├╝teri b├Âl├╝m├╝ k─▒yma mak. standart kullan─▒m',
        'Kasap ┼şark├╝teri b├Âl├╝m├╝ SKT/RKS (elle├ğleme / 10 adet ├╝r├╝n)',
        'Kasap ┼şark├╝teri b├Âl├╝m├╝ AHT etiket, doluluk, k─▒rm─▒z─▒ ├ğizgi ve temizlik',
        'Kasap ve ┼şark├╝teri haz─▒rl─▒k odas─▒ ve so─şuk oda temizlik, d├╝zen ve kalite temelli kontrol (s─▒cakl─▒k ve temizlik formu, tan─▒ml─▒ kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'GENEL (DEVAM)',
      'items', jsonb_build_array(
        '─░ptal kart─▒n muhafaza ve y├Ânetili┼ş ┼şekli & gider pusulas─▒ muhafaza ve y├Ânetili┼ş ┼şekli',
        'Personel d─▒┼ş g├Âr├╝n├╝┼ş, i┼ş k─▒yafeti, yaka kart─▒ ve ki┼şisel hijyen',
        'B├Âl├╝mlerde personel bulunurlu─şu',
        'Te┼şhir sepet say─▒s─▒, dolulu─şu, etiketleri ve konumland─▒r─▒lmas─▒',
        '─░├ğecek dolap FIFO, doluluk ve etiket',
        'Ma─şaza genel koli a├ğ─▒l─▒┼şlar─▒ (perfora), ├Ân y├╝z ve doluluk',
        'Genel depo d├╝zen / mal kabul / karton kafes / sigara i├ğme alan─▒ y├Ânetimi',
        'At─▒k, iade ve karantina alan standartlar─▒',
        'Sosyal alan standartlar─▒ (mutfak, soyunma dolap, WC ve mescit)',
        'Ma─şaza genel SKT/RKS (elle├ğleme 10 ├╝r├╝n)',
        'Ma─şaza palet alt─▒, raf ve reyon temizlik',
        'Bir ├Ânceki ma─şaza ziyareti tespit / aksiyon',
        'Haftal─▒k ve ayl─▒k b├╝lten uygulamalar─▒',
        'M├╝┼şteri g├Âz├╝yle ma─şaza kontrol formu'
      )
    )
  );
BEGIN
  IF p_tenant_id IS NULL OR p_admin_id IS NULL THEN
    RAISE EXCEPTION 'tenant ve admin kullan─▒c─▒ kimli─şi zorunludur';
  END IF;

  SELECT id INTO v_existing
  FROM public.store_scoring_forms
  WHERE tenant_id = p_tenant_id
    AND code = p_form_code;

  IF v_existing IS NOT NULL THEN
    SELECT id
      INTO v_version_id
    FROM public.store_scoring_form_versions
    WHERE form_id = v_existing
      AND status = 'published'
    ORDER BY version DESC
    LIMIT 1;

    IF v_version_id IS NULL THEN
      RETURN v_existing;
    END IF;

    RETURN v_version_id;
  END IF;

  INSERT INTO public.store_scoring_forms (
    tenant_id, code, title, description, created_by
  )
  VALUES (
    p_tenant_id,
    p_form_code,
    'Ma─şaza Genel Denetim Formu',
    'Varsay─▒lan ma─şaza kalite ve operasyon kontrol listesi',
    p_admin_id
  )
  RETURNING id INTO v_form_id;

  INSERT INTO public.store_scoring_form_versions (
    form_id, version, status, published_at, created_by
  )
  VALUES (
    v_form_id,
    1,
    'published',
    now(),
    p_admin_id
  )
  RETURNING id INTO v_version_id;

  FOR rec_section IN
    SELECT value
    FROM jsonb_array_elements(v_sections) AS t(value)
  LOOP
    INSERT INTO public.store_scoring_sections (
      form_version_id, title, order_index
    )
    VALUES (
      v_version_id,
      rec_section.value->>'title',
      v_section_index
    )
    RETURNING id INTO v_section_id;

    v_item_index := 0;
    FOR item_text IN SELECT jsonb_array_elements_text(rec_section.value->'items') LOOP
      INSERT INTO public.store_scoring_items (
        section_id,
        label,
        positive_points,
        negative_points,
        order_index,
        is_required
      )
      VALUES (
        v_section_id,
        item_text,
        2,
        0,
        v_item_index,
        false
      );
      v_item_index := v_item_index + 1;
    END LOOP;

    v_section_index := v_section_index + 1;
  END LOOP;

  RETURN v_version_id;
END;
$$;


ALTER FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_bug_report_message"("p_report_id" "uuid", "p_message" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_admin_id UUID;
    v_admin_role TEXT;
    v_user_id UUID;
    v_report_title TEXT;
BEGIN
    v_admin_id := auth.uid();
    
    -- Admin kontrol├╝
    SELECT role INTO v_admin_role
    FROM public.users
    WHERE id = v_admin_id;
    
    IF v_admin_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu i┼şlem i├ğin yetkiniz yok';
    END IF;
    
    -- Rapor bilgilerini al
    SELECT user_id, title INTO v_user_id, v_report_title
    FROM public.bug_reports
    WHERE id = p_report_id;
    
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Mesaj─▒ admin_notes'a kaydet
    UPDATE public.bug_reports
    SET admin_notes = COALESCE(admin_notes || E'\n\n', '') || '[' || NOW()::TEXT || '] ' || p_message
    WHERE id = p_report_id;
    
    -- Bildirim olu┼ştur
    INSERT INTO public.bug_report_notifications (
        bug_report_id,
        user_id,
        title,
        message,
        notification_type
    ) VALUES (
        p_report_id,
        v_user_id,
        'Y├Âneticiden Mesaj',
        'Bildirdi─şiniz "' || v_report_title || '" hakk─▒nda y├Ânetici size mesaj g├Ânderdi: ' || p_message,
        'admin_message'
    );
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."send_bug_report_message"("p_report_id" "uuid", "p_message" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "text", "p_title" "text", "p_body" "text" DEFAULT NULL::"text", "p_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_notification_id uuid;
  v_device_token record;
  v_notifications_created int := 0;
  v_queue_items_created int := 0;
  v_notification_pref text;
  v_pref_key text;
BEGIN
  -- Map notification type to preference key
  v_pref_key := CASE p_type
    WHEN 'visual_audit_task' THEN 'gorevler'
    WHEN 'visual_audit_photo' THEN 'gorevler'
    WHEN 'visual_audit_comment' THEN 'gorevler'
    WHEN 'visual_audit_completed' THEN 'gorevler'
    WHEN 'task_assigned' THEN 'gorevler'
    WHEN 'task_completed' THEN 'gorevler'
    WHEN 'task_approved' THEN 'gorevler'
    WHEN 'announcement' THEN 'duyurular'
    WHEN 'survey' THEN 'duyurular'
    WHEN 'skt_warning' THEN 'skt'
    WHEN 'depot_transfer' THEN 'depo'
    ELSE 'general'
  END;

  -- Process each user
  FOREACH v_user_id IN ARRAY p_user_ids
  LOOP
    -- Check user notification preferences (skip if function doesn't have access)
    BEGIN
      SELECT raw_user_meta_data->'notification_preferences'->>v_pref_key
      INTO v_notification_pref
      FROM auth.users
      WHERE id = v_user_id;
    EXCEPTION WHEN OTHERS THEN
      v_notification_pref := NULL;
    END;

    -- Skip if user disabled this notification type (null = enabled by default)
    IF v_notification_pref = 'false' THEN
      CONTINUE;
    END IF;

    -- Create notification record
    INSERT INTO notifications (tenant_id, user_id, type, title, body, data)
    VALUES (p_tenant_id, v_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO v_notification_id;
    
    v_notifications_created := v_notifications_created + 1;

    -- Queue FCM notification for each device (if device_tokens table exists)
    BEGIN
      FOR v_device_token IN
        SELECT id, token, platform
        FROM device_tokens
        WHERE user_id = v_user_id
          AND updated_at > now() - interval '30 days'
      LOOP
        INSERT INTO notification_queue (device_token_id, notification_id, title, body, data)
        VALUES (
          v_device_token.id,
          v_notification_id,
          p_title,
          p_body,
          jsonb_build_object(
            'type', p_type,
            'notification_id', v_notification_id
          ) || COALESCE(p_data, '{}'::jsonb)
        );
        
        v_queue_items_created := v_queue_items_created + 1;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      -- device_tokens or notification_queue may not exist yet
      NULL;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_created', v_notifications_created,
    'queue_items_created', v_queue_items_created
  );
END;
$$;


ALTER FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text" DEFAULT NULL::"text", "p_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_notification_id uuid;
  v_device_token record;
  v_notifications_created int := 0;
  v_queue_items_created int := 0;
  v_notification_pref text;
  v_pref_key text;
BEGIN
  -- Map notification type to preference key
  v_pref_key := CASE p_type
    WHEN 'visual_audit_task' THEN 'gorevler'
    WHEN 'visual_audit_photo' THEN 'gorevler'
    WHEN 'visual_audit_comment' THEN 'gorevler'
    WHEN 'visual_audit_completed' THEN 'gorevler'
    WHEN 'task_assigned' THEN 'gorevler'
    WHEN 'task_completed' THEN 'gorevler'
    WHEN 'task_approved' THEN 'gorevler'
    WHEN 'announcement' THEN 'duyurular'
    WHEN 'survey' THEN 'duyurular'
    WHEN 'skt_warning' THEN 'skt'
    WHEN 'depot_transfer' THEN 'depo'
    ELSE 'general'
  END;

  -- Process each user
  FOREACH v_user_id IN ARRAY p_user_ids
  LOOP
    -- Check user notification preferences
    SELECT raw_user_meta_data->'notification_preferences'->>v_pref_key
    INTO v_notification_pref
    FROM auth.users
    WHERE id = v_user_id;

    -- Skip if user disabled this notification type (null = enabled by default)
    IF v_notification_pref = 'false' THEN
      CONTINUE;
    END IF;

    -- Create notification record
    INSERT INTO notifications (tenant_id, user_id, type, title, body, data)
    VALUES (p_tenant_id, v_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO v_notification_id;
    
    v_notifications_created := v_notifications_created + 1;

    -- Queue FCM notification for each device
    FOR v_device_token IN
      SELECT id, token, platform
      FROM device_tokens
      WHERE user_id = v_user_id
        AND updated_at > now() - interval '30 days'  -- Only active devices
    LOOP
      INSERT INTO notification_queue (device_token_id, notification_id, title, body, data)
      VALUES (
        v_device_token.id,
        v_notification_id,
        p_title,
        p_body,
        jsonb_build_object(
          'type', p_type::text,
          'notification_id', v_notification_id
        ) || p_data
      );
      
      v_queue_items_created := v_queue_items_created + 1;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_created', v_notifications_created,
    'queue_items_created', v_queue_items_created
  );
END;
$$;


ALTER FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") IS 'Belirtilen kullan─▒c─▒lara bildirim g├Ânderir';



CREATE OR REPLACE FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_roles" "text"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_roles" "text"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text" DEFAULT NULL::"text", "p_data" "jsonb" DEFAULT '{}'::"jsonb", "p_roles" "text"[] DEFAULT ARRAY['sube_muduru'::"text", 'personel'::"text"]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "public"."notification_type", "p_title" "text", "p_body" "text" DEFAULT NULL::"text", "p_data" "jsonb" DEFAULT '{}'::"jsonb", "p_roles" "text"[] DEFAULT ARRAY['sube_muduru'::"text", 'personel'::"text"]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_ids uuid[];
BEGIN
  -- Get users in this branch with specified roles
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


ALTER FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) IS 'Bir ┼şubedeki belirtilen rollere bildirim g├Ânderir';



CREATE OR REPLACE FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.store_scoring_sessions s
    WHERE s.id = p_session_id
      AND branch_belongs_to_current_tenant(s.branch_id)
  );
$$;


ALTER FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_break_session_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_break_session_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_break_session"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS "public"."break_sessions"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user record;
  v_active break_sessions;
BEGIN
  SELECT id, tenant_id, branch_id INTO v_user
  FROM users
  WHERE id = p_user_id;

  IF v_user.id IS NULL THEN
    RAISE EXCEPTION 'Kullan─▒c─▒ bulunamad─▒';
  END IF;

  SELECT * INTO v_active
  FROM break_sessions
  WHERE user_id = v_user.id AND ended_at IS NULL
  LIMIT 1;

  IF v_active.id IS NOT NULL THEN
    RETURN v_active; -- zaten a├ğ─▒k, ayn─▒s─▒n─▒ d├Ând├╝r
  END IF;

  INSERT INTO break_sessions (tenant_id, branch_id, user_id)
  VALUES (v_user.tenant_id, v_user.branch_id, v_user.id)
  RETURNING * INTO v_active;

  RETURN v_active;
END;
$$;


ALTER FUNCTION "public"."start_break_session"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_survey_response"("p_announcement_id" "uuid", "p_answers" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_response_id uuid;
  v_answer jsonb;
  v_question_id uuid;
BEGIN
  -- Check if already responded
  IF EXISTS (
    SELECT 1 FROM public.survey_responses 
    WHERE announcement_id = p_announcement_id AND user_id = v_user_id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu ankete zaten kat─▒ld─▒n─▒z');
  END IF;
  
  -- Create response
  INSERT INTO public.survey_responses (announcement_id, user_id)
  VALUES (p_announcement_id, v_user_id)
  RETURNING id INTO v_response_id;
  
  -- Insert answers
  FOR v_answer IN SELECT * FROM jsonb_array_elements(p_answers)
  LOOP
    v_question_id := (v_answer->>'question_id')::uuid;
    
    INSERT INTO public.survey_answers (
      response_id,
      question_id,
      answer_text,
      answer_options,
      answer_rating,
      answer_boolean
    ) VALUES (
      v_response_id,
      v_question_id,
      v_answer->>'answer_text',
      COALESCE(v_answer->'answer_options', '[]'::jsonb),
      (v_answer->>'answer_rating')::integer,
      (v_answer->>'answer_boolean')::boolean
    );
  END LOOP;
  
  -- Also mark as read
  INSERT INTO public.announcement_reads (announcement_id, user_id)
  VALUES (p_announcement_id, v_user_id)
  ON CONFLICT (announcement_id, user_id) DO NOTHING;
  
  RETURN jsonb_build_object('success', true, 'response_id', v_response_id);
END;
$$;


ALTER FUNCTION "public"."submit_survey_response"("p_announcement_id" "uuid", "p_answers" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_is_core BOOLEAN;
BEGIN
  -- Sadece grand admin ├ğa─ş─▒rabilir
  IF current_user_role() != 'grand_admin' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bu i┼şlem i├ğin Grand Admin yetkisi gerekli'
    );
  END IF;
  
  -- Core mod├╝l m├╝ kontrol et
  SELECT is_core INTO v_is_core FROM modules WHERE code = p_module_code;
  
  IF v_is_core AND NOT p_is_enabled THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Temel mod├╝ller kapat─▒lamaz'
    );
  END IF;
  
  -- Mod├╝l kayd─▒n─▒ ekle veya g├╝ncelle
  INSERT INTO tenant_modules (tenant_id, module_code, is_enabled, enabled_by)
  VALUES (p_tenant_id, p_module_code, p_is_enabled, current_user_id())
  ON CONFLICT (tenant_id, module_code)
  DO UPDATE SET 
    is_enabled = p_is_enabled,
    enabled_at = NOW(),
    enabled_by = current_user_id();
  
  RETURN jsonb_build_object(
    'success', true,
    'tenant_id', p_tenant_id,
    'module_code', p_module_code,
    'is_enabled', p_is_enabled
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;


ALTER FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_generate_tasks_on_template_create"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_branch_id UUID;
  v_section_id UUID;
  v_time TEXT;
  v_branches UUID[];
  v_sections UUID[];
  v_day_of_week INTEGER;
  v_should_create BOOLEAN := FALSE;
BEGIN
  v_day_of_week := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
  
  IF NEW.recurrence = 'daily' THEN
    v_should_create := TRUE;
  ELSIF NEW.recurrence = 'weekly' AND NEW.weekly_days IS NOT NULL THEN
    v_should_create := v_day_of_week = ANY(NEW.weekly_days);
  ELSIF NEW.recurrence = 'monthly' AND NEW.monthly_days IS NOT NULL THEN
    v_should_create := EXTRACT(DAY FROM CURRENT_DATE)::INTEGER = ANY(NEW.monthly_days);
  END IF;
  
  IF NOT v_should_create THEN
    RETURN NEW;
  END IF;
  
  SELECT ARRAY_AGG(ts.section_id) INTO v_sections
  FROM visual_audit_template_sections ts
  WHERE ts.template_id = NEW.id;
  
  SELECT ARRAY_AGG(tb.branch_id) INTO v_branches
  FROM visual_audit_template_branches tb
  WHERE tb.template_id = NEW.id;
  
  -- FIX: is_active instead of active
  IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
    SELECT ARRAY_AGG(b.id) INTO v_branches
    FROM branches b
    WHERE b.tenant_id = NEW.tenant_id AND b.is_active = true;
  END IF;
  
  IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
    RETURN NEW;
  END IF;
  
  IF v_branches IS NOT NULL THEN
    FOREACH v_branch_id IN ARRAY v_branches
    LOOP
      FOREACH v_section_id IN ARRAY v_sections
      LOOP
        FOREACH v_time IN ARRAY NEW.scheduled_times
        LOOP
          INSERT INTO visual_audit_tasks (
            tenant_id, template_id, branch_id, section_id,
            scheduled_date, scheduled_time, deadline_at, min_photos
          )
          VALUES (
            NEW.tenant_id, NEW.id, v_branch_id, v_section_id,
            CURRENT_DATE, v_time::TIME,
            (CURRENT_DATE + v_time::TIME) + (NEW.deadline_minutes || ' minutes')::INTERVAL,
            NEW.min_photos
          )
          ON CONFLICT (template_id, branch_id, section_id, scheduled_date, scheduled_time) DO NOTHING;
        END LOOP;
      END LOOP;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_generate_tasks_on_template_create"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_bug_report"("p_report_id" "uuid", "p_status" "text" DEFAULT NULL::"text", "p_priority" "text" DEFAULT NULL::"text", "p_admin_notes" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID;
    v_role TEXT;
    v_old_status TEXT;
BEGIN
    v_user_id := auth.uid();
    
    SELECT role INTO v_role
    FROM public.users
    WHERE id = v_user_id;
    
    IF v_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu i┼şlem i├ğin yetkiniz yok';
    END IF;
    
    -- Mevcut durumu al (bildirim i├ğin)
    SELECT status INTO v_old_status
    FROM public.bug_reports
    WHERE id = p_report_id;
    
    -- G├╝ncelleme yap
    UPDATE public.bug_reports
    SET 
        status = COALESCE(p_status, status),
        priority = COALESCE(p_priority, priority),
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        resolved_by = CASE WHEN p_status = 'closed' THEN v_user_id ELSE resolved_by END,
        resolved_at = CASE WHEN p_status = 'closed' AND resolved_at IS NULL THEN NOW() ELSE resolved_at END,
        updated_at = NOW()
    WHERE id = p_report_id;
    
    -- Durum de─şi┼ştiyse bildirim g├Ânder
    IF p_status IS NOT NULL AND p_status != v_old_status AND p_status IN ('in_progress', 'closed') THEN
        PERFORM public.notify_bug_report_status_change(p_report_id, p_status, NULL);
    END IF;
    
    RETURN FOUND;
END;
$$;


ALTER FUNCTION "public"."update_bug_report"("p_report_id" "uuid", "p_status" "text", "p_priority" "text", "p_admin_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_task_completion"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  total_items INTEGER;
  completed_items INTEGER;
  task_uuid UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    task_uuid = OLD.task_id;
  ELSE
    task_uuid = NEW.task_id;
  END IF;

  SELECT COUNT(*) INTO total_items
  FROM task_items
  WHERE task_id = task_uuid;

  SELECT COUNT(*) INTO completed_items
  FROM task_items
  WHERE task_id = task_uuid AND completed = true;

  IF total_items > 0 THEN
    UPDATE tasks
    SET completion_percentage = (completed_items::FLOAT / total_items::FLOAT * 100)::INTEGER
    WHERE id = task_uuid;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;


ALTER FUNCTION "public"."update_task_completion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  INSERT INTO user_module_preferences (user_id, module_code, display_order)
  VALUES (current_user_id(), p_module_code, p_display_order)
  ON CONFLICT (user_id, module_code)
  DO UPDATE SET 
    display_order = p_display_order,
    updated_at = NOW();
  
  RETURN jsonb_build_object(
    'success', true,
    'module_code', p_module_code,
    'display_order', p_display_order
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$$;


ALTER FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_visual_audit_plan"("p_plan_id" "uuid", "p_name" "text" DEFAULT NULL::"text", "p_section_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_branch_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_scheduled_hour" integer DEFAULT NULL::integer, "p_deadline_minutes" integer DEFAULT NULL::integer, "p_min_photos" integer DEFAULT NULL::integer, "p_notes" "text" DEFAULT NULL::"text", "p_recurrence" "text" DEFAULT NULL::"text", "p_recurrence_days" integer[] DEFAULT NULL::integer[], "p_end_date" "date" DEFAULT NULL::"date", "p_is_active" boolean DEFAULT NULL::boolean) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
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
        RETURN json_build_object('success', false, 'error', 'Plan bulunamad─▒');
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


ALTER FUNCTION "public"."update_visual_audit_plan"("p_plan_id" "uuid", "p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_end_date" "date", "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_visual_audit_template"("p_id" "uuid", "p_name" "text" DEFAULT NULL::"text", "p_description" "text" DEFAULT NULL::"text", "p_section_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_branch_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_recurrence" "public"."visual_audit_recurrence" DEFAULT NULL::"public"."visual_audit_recurrence", "p_weekly_days" integer[] DEFAULT NULL::integer[], "p_scheduled_times" "text"[] DEFAULT NULL::"text"[], "p_deadline_minutes" integer DEFAULT NULL::integer, "p_min_photos" integer DEFAULT NULL::integer, "p_is_active" boolean DEFAULT NULL::boolean) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_role TEXT;
  v_tenant_id UUID;
  v_section_id UUID;
  v_branch_id UUID;
  v_order INTEGER := 0;
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  -- ┼Şablonun var oldu─şunu ve tenant'a ait oldu─şunu kontrol et
  IF v_role = 'grand_admin' THEN
    SELECT tenant_id INTO v_tenant_id FROM visual_audit_templates WHERE id = p_id;
  ELSE
    v_tenant_id := current_tenant_id();
    IF NOT EXISTS (SELECT 1 FROM visual_audit_templates WHERE id = p_id AND tenant_id = v_tenant_id) THEN
      RAISE EXCEPTION '┼Şablon bulunamad─▒';
    END IF;
  END IF;
  
  -- Temel alanlar─▒ g├╝ncelle
  UPDATE visual_audit_templates SET
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    recurrence = COALESCE(p_recurrence, recurrence),
    weekly_days = COALESCE(p_weekly_days, weekly_days),
    scheduled_times = COALESCE(p_scheduled_times, scheduled_times),
    deadline_minutes = COALESCE(p_deadline_minutes, deadline_minutes),
    min_photos = COALESCE(p_min_photos, min_photos),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = NOW()
  WHERE id = p_id;
  
  -- B├Âl├╝mler de─şi┼ştiyse g├╝ncelle
  IF p_section_ids IS NOT NULL THEN
    DELETE FROM visual_audit_template_sections WHERE template_id = p_id;
    FOREACH v_section_id IN ARRAY p_section_ids
    LOOP
      INSERT INTO visual_audit_template_sections (template_id, section_id, display_order)
      VALUES (p_id, v_section_id, v_order);
      v_order := v_order + 1;
    END LOOP;
  END IF;
  
  -- ┼Şubeler de─şi┼ştiyse g├╝ncelle
  IF p_branch_ids IS NOT NULL THEN
    DELETE FROM visual_audit_template_branches WHERE template_id = p_id;
    IF array_length(p_branch_ids, 1) > 0 THEN
      FOREACH v_branch_id IN ARRAY p_branch_ids
      LOOP
        INSERT INTO visual_audit_template_branches (template_id, branch_id)
        VALUES (p_id, v_branch_id);
      END LOOP;
    ELSE
      -- Bo┼ş array = t├╝m ┼şubeler, hi├ğ kay─▒t ekleme (fonksiyon t├╝m ┼şubeleri alacak)
      NULL;
    END IF;
  END IF;
  
  RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."update_visual_audit_template"("p_id" "uuid", "p_name" "text", "p_description" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_scheduled_times" "text"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_is_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_visual_audit_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_visual_audit_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upload_visual_audit_photo"("p_task_id" "uuid", "p_photo_url" "text", "p_caption" "text" DEFAULT NULL::"text", "p_thumbnail_url" "text" DEFAULT NULL::"text", "p_latitude" double precision DEFAULT NULL::double precision, "p_longitude" double precision DEFAULT NULL::double precision) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_id UUID;
  v_task RECORD;
  v_photo_count INTEGER;
BEGIN
  -- G├Ârevi al (template JOIN yok - art─▒k gerekli de─şil)
  SELECT * INTO v_task
  FROM visual_audit_tasks
  WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'G├Ârev bulunamad─▒';
  END IF;
  
  -- Foto─şraf ekle
  INSERT INTO visual_audit_photos (
    tenant_id, task_id, uploaded_by, photo_url, thumbnail_url, caption, latitude, longitude
  )
  VALUES (
    v_task.tenant_id, p_task_id, current_user_id(), p_photo_url, p_thumbnail_url, p_caption, p_latitude, p_longitude
  )
  RETURNING id INTO v_id;
  
  -- Foto─şraf say─▒s─▒n─▒ kontrol et
  SELECT COUNT(*) INTO v_photo_count FROM visual_audit_photos WHERE task_id = p_task_id;
  
  -- Durumu g├╝ncelle
  IF v_task.status = 'pending' THEN
    UPDATE visual_audit_tasks 
    SET status = 'in_progress', updated_at = now()
    WHERE id = p_task_id;
  END IF;
  
  -- Minimum foto─şraf say─▒s─▒na ula┼ş─▒ld─▒ysa tamamla
  -- min_photos art─▒k tasks tablosunda, COALESCE ile varsay─▒lan 1
  IF v_photo_count >= COALESCE(v_task.min_photos, 1) AND v_task.status NOT IN ('completed', 'approved') THEN
    UPDATE visual_audit_tasks 
    SET status = 'completed', completed_by = current_user_id(), completed_at = now(), updated_at = now()
    WHERE id = p_task_id;
  END IF;
  
  RETURN v_id;
END;
$$;


ALTER FUNCTION "public"."upload_visual_audit_photo"("p_task_id" "uuid", "p_photo_url" "text", "p_caption" "text", "p_thumbnail_url" "text", "p_latitude" double precision, "p_longitude" double precision) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."upload_visual_audit_photo"("p_task_id" "uuid", "p_photo_url" "text", "p_caption" "text", "p_thumbnail_url" "text", "p_latitude" double precision, "p_longitude" double precision) IS 'Visual audit g├Ârevi i├ğin foto─şraf y├╝kler. template_id NULL olabilir.';



CREATE OR REPLACE FUNCTION "public"."validate_products_alt_barcodes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
declare
  alt_code text;
  distinct_count integer;
begin
  -- null ise sorun yok
  if new.alt_barcodes is null then
    return new;
  end if;

  -- trim + bo┼ş de─şer kontrol├╝
  new.alt_barcodes := array(
    select trim(b)
      from unnest(new.alt_barcodes) as b
     where trim(b) <> ''
  );

  if cardinality(new.alt_barcodes) > 10 then
    raise exception 'En fazla 10 alt barkod ekleyebilirsiniz';
  end if;

  select count(*) into distinct_count
    from (select distinct unnest(new.alt_barcodes)) t;

  if distinct_count <> cardinality(new.alt_barcodes) then
    raise exception 'Alt barkod listesinde tekrar eden de─şerler var';
  end if;

  foreach alt_code in array new.alt_barcodes loop
    -- ana barkodla ayn─▒ olamaz
    if alt_code = new.barcode then
      raise exception 'Alt barkod ana barkod ile ayn─▒ olamaz (%).', alt_code;
    end if;

    -- ayn─▒ tenantÔÇÖta ba┼şka ├╝r├╝nlerin alt/ana barkodlar─▒yla ├ğak─▒┼şma kontrol├╝
    if exists (
      select 1
        from public.products p
       where p.tenant_id = new.tenant_id
         and p.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
         and (
              p.barcode = alt_code
              or (p.alt_barcodes @> array[alt_code])
         )
    ) then
      raise exception 'Alt barkod ba┼şka bir ├╝r├╝nle ├ğak─▒┼ş─▒yor (%).', alt_code;
    end if;
  end loop;

  return new;
end;
$$;


ALTER FUNCTION "public"."validate_products_alt_barcodes"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."announcement_reads" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "announcement_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "read_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."announcement_reads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."announcements" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "content" "text" NOT NULL,
    "target_branches" "uuid"[],
    "target_roles" "text"[],
    "published_by" "uuid" NOT NULL,
    "published_at" timestamp with time zone DEFAULT "now"(),
    "expires_at" timestamp with time zone,
    "is_active" boolean DEFAULT true,
    "type" "public"."announcement_type" DEFAULT 'announcement'::"public"."announcement_type",
    "target_scope" "public"."target_scope" DEFAULT 'all_branches'::"public"."target_scope",
    "include_region_managers" boolean DEFAULT false,
    "managers_only" boolean DEFAULT false,
    "priority" integer DEFAULT 0,
    "pinned" boolean DEFAULT false,
    "created_by_role" "public"."user_role",
    "cover_image_url" "text",
    "summary" "text",
    "target_regions" "uuid"[],
    "pinned_at" timestamp with time zone
);


ALTER TABLE "public"."announcements" OWNER TO "postgres";


COMMENT ON COLUMN "public"."announcements"."pinned_at" IS 'Timestamp when the announcement was pinned. Used for ordering pinned items (most recently pinned first).';



CREATE TABLE IF NOT EXISTS "public"."attendance" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "check_in_time" timestamp with time zone NOT NULL,
    "check_in_latitude" numeric(10,8),
    "check_in_longitude" numeric(11,8),
    "check_out_time" timestamp with time zone,
    "check_out_latitude" numeric(10,8),
    "check_out_longitude" numeric(11,8),
    "total_minutes" integer,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."attendance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branch_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" DEFAULT "public"."current_tenant_id"() NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "created_by" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "category" "public"."request_category" NOT NULL,
    "status" "public"."request_status" DEFAULT 'pending'::"public"."request_status" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "payload" "jsonb",
    "target_department" "text",
    "target_user_id" "uuid",
    "resolved_by" "uuid",
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."branch_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branch_scores" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "evaluation_period" "text" NOT NULL,
    "score" integer NOT NULL,
    "skt_compliance_score" integer,
    "task_completion_score" integer,
    "customer_satisfaction_score" integer,
    "notes" "text",
    "evaluated_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "branch_scores_score_check" CHECK ((("score" >= 0) AND ("score" <= 100)))
);


ALTER TABLE "public"."branch_scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branches" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "region_id" "uuid",
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "address" "text",
    "city" "text",
    "district" "text",
    "latitude" numeric(10,8),
    "longitude" numeric(11,8),
    "geofence_radius" integer DEFAULT 100,
    "manager_id" "uuid",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."branches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."break_logs" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "break_start" timestamp with time zone NOT NULL,
    "break_end" timestamp with time zone,
    "duration_minutes" integer,
    "break_type" "text" DEFAULT 'normal'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."break_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bug_report_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "bug_report_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" character varying(200) NOT NULL,
    "message" "text" NOT NULL,
    "notification_type" character varying(50) NOT NULL,
    "is_read" boolean DEFAULT false,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "bug_report_notifications_notification_type_check" CHECK ((("notification_type")::"text" = ANY ((ARRAY['status_change'::character varying, 'admin_message'::character varying, 'resolved'::character varying])::"text"[])))
);


ALTER TABLE "public"."bug_report_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bug_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid",
    "user_id" "uuid" NOT NULL,
    "title" character varying(200) NOT NULL,
    "description" "text" NOT NULL,
    "device_info" "jsonb" DEFAULT '{}'::"jsonb",
    "app_version" character varying(50),
    "status" character varying(20) DEFAULT 'open'::character varying,
    "priority" character varying(20) DEFAULT 'normal'::character varying,
    "admin_notes" "text",
    "resolved_by" "uuid",
    "resolved_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "bug_reports_priority_check" CHECK ((("priority")::"text" = ANY ((ARRAY['low'::character varying, 'normal'::character varying, 'high'::character varying, 'critical'::character varying])::"text"[]))),
    CONSTRAINT "bug_reports_status_check" CHECK ((("status")::"text" = ANY ((ARRAY['open'::character varying, 'in_progress'::character varying, 'resolved'::character varying, 'closed'::character varying])::"text"[])))
);


ALTER TABLE "public"."bug_reports" OWNER TO "postgres";


COMMENT ON TABLE "public"."bug_reports" IS 'Kullan─▒c─▒lardan gelen hata bildirimleri';



CREATE TABLE IF NOT EXISTS "public"."depot_notice_offers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "notice_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "offered_by" "uuid" NOT NULL,
    "quantity" integer NOT NULL,
    "status" "public"."depot_offer_status" DEFAULT 'pending'::"public"."depot_offer_status" NOT NULL,
    "decision_by" "uuid",
    "decision_at" timestamp with time zone,
    "message" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "branch_name" "text",
    CONSTRAINT "depot_notice_offers_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."depot_notice_offers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."depot_notices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "product_name" "text" NOT NULL,
    "quantity" integer NOT NULL,
    "unit" "text" DEFAULT 'adet'::"text" NOT NULL,
    "type" "public"."depot_notice_type" NOT NULL,
    "status" "public"."depot_notice_status" DEFAULT 'open'::"public"."depot_notice_status" NOT NULL,
    "note" "text",
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "branch_name" "text",
    CONSTRAINT "depot_notices_quantity_check" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."depot_notices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."device_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "token" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_seen_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "device_tokens_platform_check" CHECK (("platform" = ANY (ARRAY['android'::"text", 'ios'::"text", 'other'::"text"])))
);


ALTER TABLE "public"."device_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."employee_scores" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "evaluation_period" "text" NOT NULL,
    "score" integer NOT NULL,
    "punctuality_score" integer,
    "quality_score" integer,
    "teamwork_score" integer,
    "notes" "text",
    "evaluated_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "employee_scores_score_check" CHECK ((("score" >= 0) AND ("score" <= 100)))
);


ALTER TABLE "public"."employee_scores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."form_submissions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "form_template_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "responses" "jsonb" NOT NULL,
    "submitted_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."form_submissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."form_templates" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "category" "text",
    "fields" "jsonb" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."form_templates" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."health_reports" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "report_date" "date" NOT NULL,
    "report_duration_days" integer NOT NULL,
    "file_url" "text" NOT NULL,
    "file_name" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."health_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."leave_requests" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "leave_type" "public"."leave_type" NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "reason" "text",
    "status" "public"."leave_status" DEFAULT 'beklemede'::"public"."leave_status",
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "review_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."leave_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."malfunction_reports" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "reported_by" "uuid" NOT NULL,
    "category" "public"."malfunction_category" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "priority" "public"."malfunction_priority" DEFAULT 'orta'::"public"."malfunction_priority",
    "status" "public"."malfunction_status" DEFAULT 'acik'::"public"."malfunction_status",
    "assigned_to" "uuid",
    "target_resolution_date" "date",
    "resolution_notes" "text",
    "resolved_at" timestamp with time zone,
    "photo_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."malfunction_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."merch_people" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "created_by" "uuid",
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "company_name" "text" NOT NULL,
    "phone_number" "text" NOT NULL,
    "rank" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone
);

ALTER TABLE ONLY "public"."merch_people" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."merch_people" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."modules" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "icon" "text" NOT NULL,
    "description" "text",
    "is_core" boolean DEFAULT false,
    "display_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."modules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_queue" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_token_id" "uuid" NOT NULL,
    "notification_id" "uuid",
    "title" "text" NOT NULL,
    "body" "text",
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "status" "text" DEFAULT 'pending'::"text",
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "sent_at" timestamp with time zone,
    CONSTRAINT "notification_queue_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'sent'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."notification_queue" OWNER TO "postgres";


COMMENT ON TABLE "public"."notification_queue" IS 'FCM bildirim kuyru─şu - Edge Function taraf─▒ndan i┼şlenir';



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "message" "text",
    "type" "text" NOT NULL,
    "related_id" "uuid",
    "related_table" "text",
    "is_read" boolean DEFAULT false,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "body" "text",
    "data" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


COMMENT ON TABLE "public"."notifications" IS 'Bildirim ge├ğmi┼şi - kullan─▒c─▒ bazl─▒ bildirimler';



CREATE TABLE IF NOT EXISTS "public"."payrolls" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "period" "text" NOT NULL,
    "gross_salary" numeric(10,2) NOT NULL,
    "deductions" numeric(10,2) DEFAULT 0,
    "net_salary" numeric(10,2) NOT NULL,
    "file_url" "text",
    "uploaded_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."payrolls" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_issues" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "reported_by" "uuid" NOT NULL,
    "issue_type" "text" NOT NULL,
    "description" "text",
    "batch_number" "text",
    "expiry_date" "date",
    "quantity" integer DEFAULT 1,
    "status" "public"."product_issue_status" DEFAULT 'acik'::"public"."product_issue_status",
    "photo_url" "text",
    "resolved_at" timestamp with time zone,
    "resolution_notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."product_issues" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "barcode" "text" NOT NULL,
    "name" "text" NOT NULL,
    "brand" "text",
    "category" "text",
    "supplier" "text",
    "unit" "text" DEFAULT 'adet'::"text",
    "price" numeric(10,2),
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "alt_barcodes" "text"[] DEFAULT '{}'::"text"[],
    CONSTRAINT "products_alt_barcodes_limit" CHECK ((COALESCE("cardinality"("alt_barcodes"), 0) <= 10))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."regions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "manager_id" "uuid",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."regions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shift_pattern_drafts" (
    "user_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "patterns" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shift_pattern_drafts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shifts" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "week_start_date" "date" NOT NULL,
    "week_end_date" "date" NOT NULL,
    "shift_data" "jsonb" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."shifts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."skt_alarm_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "record_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "type" "public"."skt_alarm_type" NOT NULL,
    "scheduled_for" timestamp with time zone NOT NULL,
    "sent_at" timestamp with time zone,
    "seen_at" timestamp with time zone,
    "payload" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."skt_alarm_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."skt_records" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "expiry_date" "date" NOT NULL,
    "quantity" integer DEFAULT 1 NOT NULL,
    "alarm_days_before" integer DEFAULT 7,
    "alarm_date" "date",
    "alarm_sent" boolean DEFAULT false,
    "status" "public"."skt_status" DEFAULT 'normal'::"public"."skt_status",
    "product_status" "text",
    "photo_url" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "deleted_at" timestamp with time zone,
    "deleted_by" "uuid",
    "deleted_reason" "text",
    "alarm_warn_sent" boolean DEFAULT false NOT NULL,
    "alarm_warn_sent_at" timestamp with time zone,
    "alarm_due_sent" boolean DEFAULT false NOT NULL,
    "alarm_due_sent_at" timestamp with time zone
);


ALTER TABLE "public"."skt_records" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stockout_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "stockout_list_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "requested_quantity" integer NOT NULL,
    "notes" "text",
    "added_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."stockout_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stockout_lists" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."stockout_lists" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_scoring_form_versions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "form_id" "uuid" NOT NULL,
    "version" integer NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "published_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid" NOT NULL
);


ALTER TABLE "public"."store_scoring_form_versions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_scoring_forms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "visible_roles" "text"[] DEFAULT ARRAY['grand_admin'::"text", 'firma_admin'::"text", 'bolge_muduru'::"text", 'sube_muduru'::"text", 'personel'::"text"] NOT NULL
);


ALTER TABLE "public"."store_scoring_forms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_scoring_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "section_id" "uuid" NOT NULL,
    "label" "text" NOT NULL,
    "positive_points" numeric(6,2) DEFAULT 0 NOT NULL,
    "negative_points" numeric(6,2) DEFAULT 0 NOT NULL,
    "order_index" integer DEFAULT 0 NOT NULL,
    "is_required" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL
);


ALTER TABLE "public"."store_scoring_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_scoring_sections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "form_version_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "order_index" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."store_scoring_sections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_scoring_session_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "item_id" "uuid" NOT NULL,
    "result" "public"."store_scoring_item_result" NOT NULL,
    "points_awarded" numeric(6,2) DEFAULT 0 NOT NULL,
    "comment" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."store_scoring_session_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."store_scoring_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "form_version_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "evaluator_id" "uuid" NOT NULL,
    "total_positive" numeric(8,2) DEFAULT 0 NOT NULL,
    "total_negative" numeric(8,2) DEFAULT 0 NOT NULL,
    "total_possible" numeric(8,2) DEFAULT 0 NOT NULL,
    "notes" "text",
    "scored_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "evaluated_user_id" "uuid"
);


ALTER TABLE "public"."store_scoring_sessions" OWNER TO "postgres";


COMMENT ON COLUMN "public"."store_scoring_sessions"."evaluated_user_id" IS 'De─şerlendirilen personelin ID''si';



CREATE TABLE IF NOT EXISTS "public"."survey_answers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "response_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "answer_text" "text",
    "answer_options" "jsonb" DEFAULT '[]'::"jsonb",
    "answer_rating" integer,
    "answer_boolean" boolean,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."survey_answers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."survey_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "announcement_id" "uuid" NOT NULL,
    "question_text" "text" NOT NULL,
    "question_type" "public"."survey_question_type" DEFAULT 'single_choice'::"public"."survey_question_type" NOT NULL,
    "options" "jsonb" DEFAULT '[]'::"jsonb",
    "required" boolean DEFAULT true,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."survey_questions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."survey_responses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "announcement_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "submitted_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."survey_responses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_assignees" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_assignees" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_attachments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "file_url" "text" NOT NULL,
    "file_name" "text" NOT NULL,
    "file_type" "text",
    "file_size" integer,
    "uploaded_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_attachments" OWNER TO "postgres";


COMMENT ON TABLE "public"."task_attachments" IS 'G├Ârev ekleri (foto─şraf, dosya)';



COMMENT ON COLUMN "public"."task_attachments"."file_url" IS 'Dosyan─▒n storage URL''i';



COMMENT ON COLUMN "public"."task_attachments"."file_type" IS 'MIME tipi';



COMMENT ON COLUMN "public"."task_attachments"."file_size" IS 'Dosya boyutu (bytes)';



CREATE TABLE IF NOT EXISTS "public"."task_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "completed" boolean DEFAULT false,
    "completed_by" "uuid",
    "completed_at" timestamp with time zone,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "title" "text" NOT NULL,
    "description" "text",
    "created_by" "uuid" NOT NULL,
    "priority" "public"."malfunction_priority" DEFAULT 'orta'::"public"."malfunction_priority",
    "status" "public"."task_status" DEFAULT 'atandi'::"public"."task_status",
    "due_date" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "completion_percentage" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "parent_task_id" "uuid",
    "sort_order" integer DEFAULT 0,
    "is_archived" boolean DEFAULT false,
    "source_task_id" "uuid",
    "approved_at" timestamp with time zone,
    "approved_by" "uuid"
);


ALTER TABLE "public"."tasks" OWNER TO "postgres";


COMMENT ON COLUMN "public"."tasks"."is_archived" IS 'G├Ârev ar┼şivlendi mi';



COMMENT ON COLUMN "public"."tasks"."source_task_id" IS '─░letilen g├Ârevin orijinal kaynak g├Ârevi';



COMMENT ON COLUMN "public"."tasks"."approved_at" IS 'G├Ârevin onayland─▒─ş─▒ tarih';



COMMENT ON COLUMN "public"."tasks"."approved_by" IS 'G├Ârevi onaylayan kullan─▒c─▒';



CREATE TABLE IF NOT EXISTS "public"."tenant_modules" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "module_code" "text" NOT NULL,
    "is_enabled" boolean DEFAULT true,
    "enabled_at" timestamp with time zone DEFAULT "now"(),
    "enabled_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tenant_modules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "logo_url" "text",
    "module_skt" boolean DEFAULT true,
    "module_tasks" boolean DEFAULT true,
    "module_attendance" boolean DEFAULT true,
    "module_shifts" boolean DEFAULT true,
    "module_forms" boolean DEFAULT true,
    "module_malfunctions" boolean DEFAULT true,
    "module_transfers" boolean DEFAULT true,
    "module_performance" boolean DEFAULT true,
    "module_payroll" boolean DEFAULT true,
    "sap_integration_active" boolean DEFAULT false,
    "sap_api_url" "text",
    "sap_api_key" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);

ALTER TABLE ONLY "public"."tenants" FORCE ROW LEVEL SECURITY;


ALTER TABLE "public"."tenants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."todos" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "owner_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "status" "public"."manager_todo_status" DEFAULT 'pending'::"public"."manager_todo_status" NOT NULL,
    "parent_id" "uuid",
    "description" "text",
    "sort_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."todos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_module_preferences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "module_code" "text" NOT NULL,
    "display_order" integer DEFAULT 0 NOT NULL,
    "is_visible" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_module_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "phone" "text",
    "employee_code" "text",
    "role" "public"."user_role" DEFAULT 'personel'::"public"."user_role",
    "position" "text",
    "hire_date" "date",
    "annual_leave_days" integer DEFAULT 14,
    "used_leave_days" integer DEFAULT 0,
    "avatar_url" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_active_skt_alarms" WITH ("security_invoker"='true') AS
 SELECT "s"."id",
    "s"."tenant_id",
    "s"."branch_id",
    "s"."product_id",
    "s"."user_id",
    "s"."expiry_date",
    "s"."quantity",
    "s"."alarm_days_before",
    "s"."alarm_date",
    "s"."alarm_sent",
    "s"."status",
    "s"."product_status",
    "s"."photo_url",
    "s"."notes",
    "s"."created_at",
    "s"."updated_at",
    "p"."name" AS "product_name",
    "p"."barcode",
    "b"."name" AS "branch_name",
    (("u"."first_name" || ' '::"text") || "u"."last_name") AS "user_name"
   FROM ((("public"."skt_records" "s"
     JOIN "public"."products" "p" ON (("s"."product_id" = "p"."id")))
     JOIN "public"."branches" "b" ON (("s"."branch_id" = "b"."id")))
     JOIN "public"."users" "u" ON (("s"."user_id" = "u"."id")))
  WHERE (("s"."alarm_date" <= CURRENT_DATE) AND ("s"."alarm_sent" = false) AND ("s"."status" = ANY (ARRAY['yaklasan'::"public"."skt_status", 'gecmis'::"public"."skt_status"])));


ALTER VIEW "public"."v_active_skt_alarms" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_pending_leave_requests" WITH ("security_invoker"='true') AS
 SELECT "lr"."id",
    "lr"."tenant_id",
    "lr"."branch_id",
    "lr"."user_id",
    "lr"."leave_type",
    "lr"."start_date",
    "lr"."end_date",
    "lr"."reason",
    "lr"."status",
    "lr"."reviewed_by",
    "lr"."reviewed_at",
    "lr"."review_notes",
    "lr"."created_at",
    "lr"."updated_at",
    (("u"."first_name" || ' '::"text") || "u"."last_name") AS "user_name",
    "b"."name" AS "branch_name"
   FROM (("public"."leave_requests" "lr"
     JOIN "public"."users" "u" ON (("lr"."user_id" = "u"."id")))
     JOIN "public"."branches" "b" ON (("lr"."branch_id" = "b"."id")))
  WHERE ("lr"."status" = 'beklemede'::"public"."leave_status");


ALTER VIEW "public"."v_pending_leave_requests" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_store_scoring_published_forms" WITH ("security_invoker"='true', "security_barrier"='true') AS
 WITH "actor" AS (
         SELECT COALESCE("auth"."uid"(), (NULLIF("current_setting"('request.jwt.claim.sub'::"text", true), ''::"text"))::"uuid") AS "user_id",
            COALESCE("current_setting"('request.jwt.claim.role'::"text", true), "public"."current_user_role"(), ( SELECT ("u"."role")::"text" AS "role"
                   FROM "public"."users" "u"
                  WHERE ("u"."id" = COALESCE("auth"."uid"(), (NULLIF("current_setting"('request.jwt.claim.sub'::"text", true), ''::"text"))::"uuid"))), "auth"."role"(), 'anonymous'::"text") AS "effective_role",
            COALESCE("current_setting"('request.jwt.claim.role'::"text", true), "auth"."role"(), 'anonymous'::"text") AS "raw_auth_role"
        )
 SELECT "fv"."id" AS "form_version_id",
    "f"."id" AS "form_id",
    "f"."tenant_id",
    "f"."code",
    "f"."title",
    "f"."description",
    "fv"."version",
    "fv"."published_at",
    "a"."effective_role" AS "debug_effective_role",
    "a"."raw_auth_role" AS "debug_auth_role",
    "auth"."uid"() AS "debug_user_id",
    "f"."visible_roles",
    "jsonb_agg"("jsonb_build_object"('sectionId', "s"."id", 'title', "s"."title", 'order', "s"."order_index", 'items', ( SELECT "jsonb_agg"("jsonb_build_object"('itemId', "i"."id", 'label', "i"."label", 'positivePoints', "i"."positive_points", 'negativePoints', "i"."negative_points", 'order', "i"."order_index", 'isRequired', "i"."is_required", 'hasBinaryChoice', COALESCE((("i"."metadata" ->> 'hasBinaryChoice'::"text"))::boolean, true), 'allowComment', COALESCE((("i"."metadata" ->> 'allowComment'::"text"))::boolean, false)) ORDER BY "i"."order_index") AS "jsonb_agg"
           FROM "public"."store_scoring_items" "i"
          WHERE ("i"."section_id" = "s"."id"))) ORDER BY "s"."order_index") AS "sections"
   FROM ((("public"."store_scoring_form_versions" "fv"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
     JOIN "public"."store_scoring_sections" "s" ON (("s"."form_version_id" = "fv"."id")))
     CROSS JOIN "actor" "a")
  WHERE (("fv"."status" = 'published'::"text") AND (("auth"."role"() = 'service_role'::"text") OR (COALESCE("array_length"("f"."visible_roles", 1), 0) = 0) OR ("a"."effective_role" = ANY ("f"."visible_roles"))))
  GROUP BY "fv"."id", "f"."id", "f"."tenant_id", "f"."code", "f"."title", "f"."description", "fv"."version", "fv"."published_at", "f"."visible_roles", "a"."effective_role", "a"."raw_auth_role", ("auth"."uid"());


ALTER VIEW "public"."v_store_scoring_published_forms" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_survey_statistics" AS
SELECT
    NULL::"uuid" AS "announcement_id",
    NULL::"text" AS "title",
    NULL::"uuid" AS "tenant_id",
    NULL::timestamp with time zone AS "published_at",
    NULL::bigint AS "total_responses",
    NULL::bigint AS "target_audience_count";


ALTER VIEW "public"."v_survey_statistics" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."visual_audit_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "comment_type" "public"."visual_audit_comment_type" DEFAULT 'comment'::"public"."visual_audit_comment_type" NOT NULL,
    "message" "text" NOT NULL,
    "photo_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."visual_audit_comments" OWNER TO "postgres";


COMMENT ON TABLE "public"."visual_audit_comments" IS 'G├Ârev yorumlar─▒ ve ileti┼şim';



CREATE TABLE IF NOT EXISTS "public"."visual_audit_photos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "task_id" "uuid" NOT NULL,
    "uploaded_by" "uuid" NOT NULL,
    "photo_url" "text" NOT NULL,
    "thumbnail_url" "text",
    "file_name" "text",
    "file_size" integer,
    "mime_type" "text" DEFAULT 'image/jpeg'::"text",
    "caption" "text",
    "latitude" double precision,
    "longitude" double precision,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."visual_audit_photos" OWNER TO "postgres";


COMMENT ON TABLE "public"."visual_audit_photos" IS 'Y├╝klenen denetim foto─şraflar─▒';



CREATE TABLE IF NOT EXISTS "public"."visual_audit_sections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "icon" "text" DEFAULT 'store'::"text",
    "color" "text" DEFAULT '#3B82F6'::"text",
    "display_order" integer DEFAULT 0,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."visual_audit_sections" OWNER TO "postgres";


COMMENT ON TABLE "public"."visual_audit_sections" IS 'G├Ârsel denetim b├Âl├╝mleri (Manav, ┼Şark├╝teri vb.)';



CREATE TABLE IF NOT EXISTS "public"."visual_audit_task_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "section_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "branch_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "scheduled_hour" integer DEFAULT 9 NOT NULL,
    "deadline_minutes" integer DEFAULT 60 NOT NULL,
    "min_photos" integer DEFAULT 1 NOT NULL,
    "notes" "text",
    "recurrence" "text" DEFAULT 'daily'::"text" NOT NULL,
    "recurrence_days" integer[] DEFAULT '{}'::integer[] NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_run_at" timestamp with time zone,
    CONSTRAINT "visual_audit_task_plans_recurrence_check" CHECK (("recurrence" = ANY (ARRAY['daily'::"text", 'weekly'::"text"])))
);


ALTER TABLE "public"."visual_audit_task_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."visual_audit_tasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "template_id" "uuid",
    "branch_id" "uuid" NOT NULL,
    "section_id" "uuid" NOT NULL,
    "scheduled_date" "date" NOT NULL,
    "scheduled_time" time without time zone NOT NULL,
    "deadline_at" timestamp with time zone NOT NULL,
    "status" "public"."visual_audit_task_status" DEFAULT 'pending'::"public"."visual_audit_task_status" NOT NULL,
    "completed_by" "uuid",
    "completed_at" timestamp with time zone,
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "review_note" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "min_photos" integer DEFAULT 1 NOT NULL,
    "created_by" "uuid",
    "notes" "text",
    "plan_id" "uuid",
    "title" "text"
);


ALTER TABLE "public"."visual_audit_tasks" OWNER TO "postgres";


COMMENT ON TABLE "public"."visual_audit_tasks" IS 'G├╝nl├╝k olu┼şan g├Ârsel denetim g├Ârevleri';



CREATE TABLE IF NOT EXISTS "public"."visual_audit_template_branches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "template_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."visual_audit_template_branches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."visual_audit_template_sections" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "template_id" "uuid" NOT NULL,
    "section_id" "uuid" NOT NULL,
    "display_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."visual_audit_template_sections" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."visual_audit_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "section_ids" "uuid"[],
    "branch_ids" "uuid"[],
    "recurrence" "public"."visual_audit_recurrence" DEFAULT 'daily'::"public"."visual_audit_recurrence" NOT NULL,
    "scheduled_times" "text"[] DEFAULT ARRAY['10:00'::"text"] NOT NULL,
    "weekly_days" integer[] DEFAULT ARRAY[1, 2, 3, 4, 5],
    "monthly_days" integer[],
    "deadline_minutes" integer DEFAULT 60,
    "min_photos" integer DEFAULT 1,
    "is_active" boolean DEFAULT true,
    "starts_at" "date" DEFAULT CURRENT_DATE,
    "ends_at" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."visual_audit_templates" OWNER TO "postgres";


COMMENT ON TABLE "public"."visual_audit_templates" IS 'G├Ârsel denetim ┼şablonlar─▒ - hangi b├Âl├╝mler, hangi saatler';



ALTER TABLE ONLY "public"."announcement_reads"
    ADD CONSTRAINT "announcement_reads_announcement_id_user_id_key" UNIQUE ("announcement_id", "user_id");



ALTER TABLE ONLY "public"."announcement_reads"
    ADD CONSTRAINT "announcement_reads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."branch_requests"
    ADD CONSTRAINT "branch_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."branch_scores"
    ADD CONSTRAINT "branch_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."branch_scores"
    ADD CONSTRAINT "branch_scores_tenant_id_branch_id_evaluation_period_key" UNIQUE ("tenant_id", "branch_id", "evaluation_period");



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_tenant_id_code_key" UNIQUE ("tenant_id", "code");



ALTER TABLE ONLY "public"."break_logs"
    ADD CONSTRAINT "break_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."break_sessions"
    ADD CONSTRAINT "break_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bug_report_notifications"
    ADD CONSTRAINT "bug_report_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bug_reports"
    ADD CONSTRAINT "bug_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."depot_notice_offers"
    ADD CONSTRAINT "depot_notice_offers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."depot_notices"
    ADD CONSTRAINT "depot_notices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_token_key" UNIQUE ("token");



ALTER TABLE ONLY "public"."employee_scores"
    ADD CONSTRAINT "employee_scores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."form_submissions"
    ADD CONSTRAINT "form_submissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."form_templates"
    ADD CONSTRAINT "form_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."health_reports"
    ADD CONSTRAINT "health_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."leave_requests"
    ADD CONSTRAINT "leave_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."malfunction_reports"
    ADD CONSTRAINT "malfunction_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."merch_people"
    ADD CONSTRAINT "merch_people_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."modules"
    ADD CONSTRAINT "modules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_queue"
    ADD CONSTRAINT "notification_queue_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payrolls"
    ADD CONSTRAINT "payrolls_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payrolls"
    ADD CONSTRAINT "payrolls_tenant_id_user_id_period_key" UNIQUE ("tenant_id", "user_id", "period");



ALTER TABLE ONLY "public"."product_issues"
    ADD CONSTRAINT "product_issues_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_tenant_id_barcode_key" UNIQUE ("tenant_id", "barcode");



ALTER TABLE ONLY "public"."regions"
    ADD CONSTRAINT "regions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."regions"
    ADD CONSTRAINT "regions_tenant_id_code_key" UNIQUE ("tenant_id", "code");



ALTER TABLE ONLY "public"."shift_pattern_drafts"
    ADD CONSTRAINT "shift_pattern_drafts_pkey" PRIMARY KEY ("user_id", "tenant_id");



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_tenant_id_branch_id_week_start_date_key" UNIQUE ("tenant_id", "branch_id", "week_start_date");



ALTER TABLE ONLY "public"."skt_alarm_notifications"
    ADD CONSTRAINT "skt_alarm_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."skt_records"
    ADD CONSTRAINT "skt_records_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stockout_items"
    ADD CONSTRAINT "stockout_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stockout_lists"
    ADD CONSTRAINT "stockout_lists_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_scoring_form_versions"
    ADD CONSTRAINT "store_scoring_form_versions_form_id_version_key" UNIQUE ("form_id", "version");



ALTER TABLE ONLY "public"."store_scoring_form_versions"
    ADD CONSTRAINT "store_scoring_form_versions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_scoring_forms"
    ADD CONSTRAINT "store_scoring_forms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_scoring_forms"
    ADD CONSTRAINT "store_scoring_forms_tenant_id_code_key" UNIQUE ("tenant_id", "code");



ALTER TABLE ONLY "public"."store_scoring_items"
    ADD CONSTRAINT "store_scoring_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_scoring_sections"
    ADD CONSTRAINT "store_scoring_sections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_scoring_session_items"
    ADD CONSTRAINT "store_scoring_session_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."store_scoring_session_items"
    ADD CONSTRAINT "store_scoring_session_items_session_id_item_id_key" UNIQUE ("session_id", "item_id");



ALTER TABLE ONLY "public"."store_scoring_sessions"
    ADD CONSTRAINT "store_scoring_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."survey_answers"
    ADD CONSTRAINT "survey_answers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."survey_questions"
    ADD CONSTRAINT "survey_questions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."survey_responses"
    ADD CONSTRAINT "survey_responses_announcement_id_user_id_key" UNIQUE ("announcement_id", "user_id");



ALTER TABLE ONLY "public"."survey_responses"
    ADD CONSTRAINT "survey_responses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_task_id_user_id_key" UNIQUE ("task_id", "user_id");



ALTER TABLE ONLY "public"."task_attachments"
    ADD CONSTRAINT "task_attachments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_tenant_id_module_code_key" UNIQUE ("tenant_id", "module_code");



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."todos"
    ADD CONSTRAINT "todos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_module_preferences"
    ADD CONSTRAINT "user_module_preferences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_module_preferences"
    ADD CONSTRAINT "user_module_preferences_user_module_unique" UNIQUE ("user_id", "module_code");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_tenant_id_employee_code_key" UNIQUE ("tenant_id", "employee_code");



ALTER TABLE ONLY "public"."visual_audit_comments"
    ADD CONSTRAINT "visual_audit_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visual_audit_photos"
    ADD CONSTRAINT "visual_audit_photos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visual_audit_sections"
    ADD CONSTRAINT "visual_audit_sections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visual_audit_sections"
    ADD CONSTRAINT "visual_audit_sections_tenant_id_name_key" UNIQUE ("tenant_id", "name");



ALTER TABLE ONLY "public"."visual_audit_task_plans"
    ADD CONSTRAINT "visual_audit_task_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_template_id_branch_id_section_id_schedul_key" UNIQUE ("template_id", "branch_id", "section_id", "scheduled_date", "scheduled_time");



ALTER TABLE ONLY "public"."visual_audit_template_branches"
    ADD CONSTRAINT "visual_audit_template_branches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visual_audit_template_branches"
    ADD CONSTRAINT "visual_audit_template_branches_template_id_branch_id_key" UNIQUE ("template_id", "branch_id");



ALTER TABLE ONLY "public"."visual_audit_template_sections"
    ADD CONSTRAINT "visual_audit_template_sections_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."visual_audit_template_sections"
    ADD CONSTRAINT "visual_audit_template_sections_template_id_section_id_key" UNIQUE ("template_id", "section_id");



ALTER TABLE ONLY "public"."visual_audit_templates"
    ADD CONSTRAINT "visual_audit_templates_pkey" PRIMARY KEY ("id");



CREATE INDEX "break_sessions_branch_started_idx" ON "public"."break_sessions" USING "btree" ("branch_id", "started_at" DESC);



CREATE INDEX "break_sessions_user_open_idx" ON "public"."break_sessions" USING "btree" ("user_id") WHERE ("ended_at" IS NULL);



CREATE INDEX "depot_notice_offers_notice_idx" ON "public"."depot_notice_offers" USING "btree" ("notice_id", "status");



CREATE UNIQUE INDEX "depot_notice_offers_unique_pending" ON "public"."depot_notice_offers" USING "btree" ("notice_id", "branch_id") WHERE ("status" = 'pending'::"public"."depot_offer_status");



CREATE INDEX "depot_notices_tenant_branch_idx" ON "public"."depot_notices" USING "btree" ("tenant_id", "branch_id", "status");



CREATE INDEX "device_tokens_token_idx" ON "public"."device_tokens" USING "btree" ("token");



CREATE INDEX "device_tokens_user_idx" ON "public"."device_tokens" USING "btree" ("user_id");



CREATE INDEX "idx_announcement_reads_user_id" ON "public"."announcement_reads" USING "btree" ("user_id");



CREATE INDEX "idx_announcements_pinned" ON "public"."announcements" USING "btree" ("pinned") WHERE ("pinned" = true);



CREATE INDEX "idx_announcements_pinned_at" ON "public"."announcements" USING "btree" ("pinned_at" DESC NULLS LAST);



CREATE INDEX "idx_announcements_priority" ON "public"."announcements" USING "btree" ("priority" DESC);



CREATE INDEX "idx_announcements_published" ON "public"."announcements" USING "btree" ("published_at");



CREATE INDEX "idx_announcements_published_by" ON "public"."announcements" USING "btree" ("published_by");



CREATE INDEX "idx_announcements_target_scope" ON "public"."announcements" USING "btree" ("target_scope");



CREATE INDEX "idx_announcements_tenant" ON "public"."announcements" USING "btree" ("tenant_id");



CREATE INDEX "idx_announcements_type" ON "public"."announcements" USING "btree" ("type");



CREATE INDEX "idx_attendance_branch_id" ON "public"."attendance" USING "btree" ("branch_id");



CREATE INDEX "idx_attendance_date" ON "public"."attendance" USING "btree" ("check_in_time");



CREATE INDEX "idx_attendance_tenant_branch" ON "public"."attendance" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_attendance_user" ON "public"."attendance" USING "btree" ("user_id");



CREATE INDEX "idx_branch_requests_branch" ON "public"."branch_requests" USING "btree" ("branch_id");



CREATE INDEX "idx_branch_requests_category" ON "public"."branch_requests" USING "btree" ("category");



CREATE INDEX "idx_branch_requests_created_by" ON "public"."branch_requests" USING "btree" ("created_by");



CREATE INDEX "idx_branch_requests_resolved_by" ON "public"."branch_requests" USING "btree" ("resolved_by");



CREATE INDEX "idx_branch_requests_status" ON "public"."branch_requests" USING "btree" ("status");



CREATE INDEX "idx_branch_requests_target_user_id" ON "public"."branch_requests" USING "btree" ("target_user_id");



CREATE INDEX "idx_branch_score_tenant_branch" ON "public"."branch_scores" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_branch_scores_branch_id" ON "public"."branch_scores" USING "btree" ("branch_id");



CREATE INDEX "idx_branch_scores_evaluated_by" ON "public"."branch_scores" USING "btree" ("evaluated_by");



CREATE INDEX "idx_branches_region" ON "public"."branches" USING "btree" ("region_id");



CREATE INDEX "idx_branches_tenant" ON "public"."branches" USING "btree" ("tenant_id");



CREATE INDEX "idx_break_logs_branch_id" ON "public"."break_logs" USING "btree" ("branch_id");



CREATE INDEX "idx_break_sessions_tenant_id" ON "public"."break_sessions" USING "btree" ("tenant_id");



CREATE INDEX "idx_break_tenant_branch" ON "public"."break_logs" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_break_user" ON "public"."break_logs" USING "btree" ("user_id");



CREATE INDEX "idx_bug_report_notifications_bug_report_id" ON "public"."bug_report_notifications" USING "btree" ("bug_report_id");



CREATE INDEX "idx_bug_report_notifications_created_at" ON "public"."bug_report_notifications" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_bug_report_notifications_is_read" ON "public"."bug_report_notifications" USING "btree" ("is_read");



CREATE INDEX "idx_bug_report_notifications_user_id" ON "public"."bug_report_notifications" USING "btree" ("user_id");



CREATE INDEX "idx_bug_reports_created_at" ON "public"."bug_reports" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_bug_reports_status" ON "public"."bug_reports" USING "btree" ("status");



CREATE INDEX "idx_bug_reports_tenant_id" ON "public"."bug_reports" USING "btree" ("tenant_id");



CREATE INDEX "idx_bug_reports_user_id" ON "public"."bug_reports" USING "btree" ("user_id");



CREATE INDEX "idx_depot_notice_offers_branch_id" ON "public"."depot_notice_offers" USING "btree" ("branch_id");



CREATE INDEX "idx_depot_notice_offers_decision_by" ON "public"."depot_notice_offers" USING "btree" ("decision_by");



CREATE INDEX "idx_depot_notice_offers_offered_by" ON "public"."depot_notice_offers" USING "btree" ("offered_by");



CREATE INDEX "idx_depot_notice_offers_tenant_id" ON "public"."depot_notice_offers" USING "btree" ("tenant_id");



CREATE INDEX "idx_depot_notices_branch_id" ON "public"."depot_notices" USING "btree" ("branch_id");



CREATE INDEX "idx_depot_notices_created_by" ON "public"."depot_notices" USING "btree" ("created_by");



CREATE INDEX "idx_employee_score_period" ON "public"."employee_scores" USING "btree" ("evaluation_period");



CREATE INDEX "idx_employee_score_tenant_user" ON "public"."employee_scores" USING "btree" ("tenant_id", "user_id");



CREATE INDEX "idx_employee_scores_evaluated_by" ON "public"."employee_scores" USING "btree" ("evaluated_by");



CREATE INDEX "idx_employee_scores_user_id" ON "public"."employee_scores" USING "btree" ("user_id");



CREATE INDEX "idx_form_submissions_branch_id" ON "public"."form_submissions" USING "btree" ("branch_id");



CREATE INDEX "idx_form_submissions_template" ON "public"."form_submissions" USING "btree" ("form_template_id");



CREATE INDEX "idx_form_submissions_tenant_branch" ON "public"."form_submissions" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_form_submissions_user_id" ON "public"."form_submissions" USING "btree" ("user_id");



CREATE INDEX "idx_form_templates_created_by" ON "public"."form_templates" USING "btree" ("created_by");



CREATE INDEX "idx_form_templates_tenant" ON "public"."form_templates" USING "btree" ("tenant_id");



CREATE INDEX "idx_health_reports_branch_id" ON "public"."health_reports" USING "btree" ("branch_id");



CREATE INDEX "idx_health_reports_tenant_id" ON "public"."health_reports" USING "btree" ("tenant_id");



CREATE INDEX "idx_health_reports_user_id" ON "public"."health_reports" USING "btree" ("user_id");



CREATE INDEX "idx_leave_dates" ON "public"."leave_requests" USING "btree" ("start_date", "end_date");



CREATE INDEX "idx_leave_requests_branch_id" ON "public"."leave_requests" USING "btree" ("branch_id");



CREATE INDEX "idx_leave_requests_reviewed_by" ON "public"."leave_requests" USING "btree" ("reviewed_by");



CREATE INDEX "idx_leave_status" ON "public"."leave_requests" USING "btree" ("status");



CREATE INDEX "idx_leave_tenant_branch" ON "public"."leave_requests" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_leave_user" ON "public"."leave_requests" USING "btree" ("user_id");



CREATE INDEX "idx_malfunction_assigned" ON "public"."malfunction_reports" USING "btree" ("assigned_to");



CREATE INDEX "idx_malfunction_reports_branch_id" ON "public"."malfunction_reports" USING "btree" ("branch_id");



CREATE INDEX "idx_malfunction_reports_reported_by" ON "public"."malfunction_reports" USING "btree" ("reported_by");



CREATE INDEX "idx_malfunction_status" ON "public"."malfunction_reports" USING "btree" ("status");



CREATE INDEX "idx_malfunction_tenant_branch" ON "public"."malfunction_reports" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_merch_people_created_by" ON "public"."merch_people" USING "btree" ("created_by");



CREATE INDEX "idx_merch_people_tenant_id" ON "public"."merch_people" USING "btree" ("tenant_id");



CREATE INDEX "idx_notification_queue_device" ON "public"."notification_queue" USING "btree" ("device_token_id");



CREATE INDEX "idx_notification_queue_status" ON "public"."notification_queue" USING "btree" ("status") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_notifications_created" ON "public"."notifications" USING "btree" ("created_at");



CREATE INDEX "idx_notifications_created_at" ON "public"."notifications" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_notifications_data" ON "public"."notifications" USING "gin" ("data");



CREATE INDEX "idx_notifications_read" ON "public"."notifications" USING "btree" ("is_read");



CREATE INDEX "idx_notifications_tenant_id" ON "public"."notifications" USING "btree" ("tenant_id");



CREATE INDEX "idx_notifications_tenant_user" ON "public"."notifications" USING "btree" ("tenant_id", "user_id");



CREATE INDEX "idx_notifications_unread" ON "public"."notifications" USING "btree" ("user_id") WHERE ("read_at" IS NULL);



CREATE INDEX "idx_notifications_user_id" ON "public"."notifications" USING "btree" ("user_id");



CREATE INDEX "idx_payroll_period" ON "public"."payrolls" USING "btree" ("period");



CREATE INDEX "idx_payroll_tenant_user" ON "public"."payrolls" USING "btree" ("tenant_id", "user_id");



CREATE INDEX "idx_payrolls_uploaded_by" ON "public"."payrolls" USING "btree" ("uploaded_by");



CREATE INDEX "idx_payrolls_user_id" ON "public"."payrolls" USING "btree" ("user_id");



CREATE INDEX "idx_product_issue_status" ON "public"."product_issues" USING "btree" ("status");



CREATE INDEX "idx_product_issue_tenant_branch" ON "public"."product_issues" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_product_issues_branch_id" ON "public"."product_issues" USING "btree" ("branch_id");



CREATE INDEX "idx_product_issues_product_id" ON "public"."product_issues" USING "btree" ("product_id");



CREATE INDEX "idx_product_issues_reported_by" ON "public"."product_issues" USING "btree" ("reported_by");



CREATE INDEX "idx_products_alt_barcodes" ON "public"."products" USING "gin" ("alt_barcodes");



CREATE INDEX "idx_products_barcode" ON "public"."products" USING "btree" ("tenant_id", "barcode");



CREATE INDEX "idx_products_name_trgm" ON "public"."products" USING "gin" ("name" "extensions"."gin_trgm_ops");



CREATE INDEX "idx_products_tenant" ON "public"."products" USING "btree" ("tenant_id");



CREATE INDEX "idx_regions_tenant" ON "public"."regions" USING "btree" ("tenant_id");



CREATE INDEX "idx_shift_pattern_drafts_tenant_user" ON "public"."shift_pattern_drafts" USING "btree" ("tenant_id", "user_id");



CREATE INDEX "idx_shifts_branch_id" ON "public"."shifts" USING "btree" ("branch_id");



CREATE INDEX "idx_shifts_created_by" ON "public"."shifts" USING "btree" ("created_by");



CREATE INDEX "idx_shifts_tenant_branch" ON "public"."shifts" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_shifts_week" ON "public"."shifts" USING "btree" ("week_start_date");



CREATE INDEX "idx_skt_alarm_date" ON "public"."skt_records" USING "btree" ("alarm_date") WHERE ("alarm_sent" = false);



CREATE INDEX "idx_skt_alarm_notifications_record_id" ON "public"."skt_alarm_notifications" USING "btree" ("record_id");



CREATE INDEX "idx_skt_alarm_notifications_user_id" ON "public"."skt_alarm_notifications" USING "btree" ("user_id");



CREATE INDEX "idx_skt_expiry_date" ON "public"."skt_records" USING "btree" ("expiry_date");



CREATE INDEX "idx_skt_product" ON "public"."skt_records" USING "btree" ("product_id");



CREATE INDEX "idx_skt_records_branch_id" ON "public"."skt_records" USING "btree" ("branch_id");



CREATE INDEX "idx_skt_records_deleted_by" ON "public"."skt_records" USING "btree" ("deleted_by");



CREATE INDEX "idx_skt_records_user_id" ON "public"."skt_records" USING "btree" ("user_id");



CREATE INDEX "idx_skt_status" ON "public"."skt_records" USING "btree" ("status");



CREATE INDEX "idx_skt_tenant_branch" ON "public"."skt_records" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_stockout_items_list" ON "public"."stockout_items" USING "btree" ("stockout_list_id");



CREATE INDEX "idx_stockout_items_product_id" ON "public"."stockout_items" USING "btree" ("product_id");



CREATE INDEX "idx_stockout_lists_branch_id" ON "public"."stockout_lists" USING "btree" ("branch_id");



CREATE INDEX "idx_stockout_lists_created_by" ON "public"."stockout_lists" USING "btree" ("created_by");



CREATE INDEX "idx_stockout_lists_tenant_branch" ON "public"."stockout_lists" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_store_scoring_form_versions_created_by" ON "public"."store_scoring_form_versions" USING "btree" ("created_by");



CREATE INDEX "idx_store_scoring_forms_created_by" ON "public"."store_scoring_forms" USING "btree" ("created_by");



CREATE INDEX "idx_store_scoring_session_items_item_id" ON "public"."store_scoring_session_items" USING "btree" ("item_id");



CREATE INDEX "idx_store_scoring_sessions_evaluated_user_id" ON "public"."store_scoring_sessions" USING "btree" ("evaluated_user_id");



CREATE INDEX "idx_store_scoring_sessions_form_version_id" ON "public"."store_scoring_sessions" USING "btree" ("form_version_id");



CREATE INDEX "idx_survey_answers_question" ON "public"."survey_answers" USING "btree" ("question_id");



CREATE INDEX "idx_survey_answers_response" ON "public"."survey_answers" USING "btree" ("response_id");



CREATE INDEX "idx_survey_questions_announcement" ON "public"."survey_questions" USING "btree" ("announcement_id");



CREATE INDEX "idx_survey_questions_sort" ON "public"."survey_questions" USING "btree" ("announcement_id", "sort_order");



CREATE INDEX "idx_survey_responses_announcement" ON "public"."survey_responses" USING "btree" ("announcement_id");



CREATE INDEX "idx_survey_responses_user" ON "public"."survey_responses" USING "btree" ("user_id");



CREATE INDEX "idx_task_assignees_user" ON "public"."task_assignees" USING "btree" ("user_id");



CREATE INDEX "idx_task_attachments_task_id" ON "public"."task_attachments" USING "btree" ("task_id");



CREATE INDEX "idx_task_attachments_uploaded_by" ON "public"."task_attachments" USING "btree" ("uploaded_by");



CREATE INDEX "idx_task_items_completed_by" ON "public"."task_items" USING "btree" ("completed_by");



CREATE INDEX "idx_task_items_task_id" ON "public"."task_items" USING "btree" ("task_id");



CREATE INDEX "idx_tasks_approved_by" ON "public"."tasks" USING "btree" ("approved_by");



CREATE INDEX "idx_tasks_branch_id" ON "public"."tasks" USING "btree" ("branch_id");



CREATE INDEX "idx_tasks_created_by" ON "public"."tasks" USING "btree" ("created_by");



CREATE INDEX "idx_tasks_due_date" ON "public"."tasks" USING "btree" ("due_date");



CREATE INDEX "idx_tasks_is_archived" ON "public"."tasks" USING "btree" ("is_archived");



CREATE INDEX "idx_tasks_parent_sort" ON "public"."tasks" USING "btree" ("parent_task_id", "sort_order");



CREATE INDEX "idx_tasks_parent_task" ON "public"."tasks" USING "btree" ("parent_task_id");



CREATE INDEX "idx_tasks_source_task_id" ON "public"."tasks" USING "btree" ("source_task_id");



CREATE INDEX "idx_tasks_status" ON "public"."tasks" USING "btree" ("status");



CREATE INDEX "idx_tasks_tenant_branch" ON "public"."tasks" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_tenant_modules_enabled_by" ON "public"."tenant_modules" USING "btree" ("enabled_by");



CREATE INDEX "idx_tenant_modules_module_code" ON "public"."tenant_modules" USING "btree" ("module_code");



CREATE INDEX "idx_todos_owner_id" ON "public"."todos" USING "btree" ("owner_id");



CREATE INDEX "idx_todos_parent_id" ON "public"."todos" USING "btree" ("parent_id");



CREATE INDEX "idx_todos_tenant" ON "public"."todos" USING "btree" ("tenant_id");



CREATE INDEX "idx_users_branch_id" ON "public"."users" USING "btree" ("branch_id");



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_role" ON "public"."users" USING "btree" ("role");



CREATE INDEX "idx_users_tenant" ON "public"."users" USING "btree" ("tenant_id");



CREATE INDEX "idx_users_tenant_role" ON "public"."users" USING "btree" ("tenant_id", "role");



CREATE INDEX "idx_visual_audit_comments_task" ON "public"."visual_audit_comments" USING "btree" ("task_id");



CREATE INDEX "idx_visual_audit_comments_user" ON "public"."visual_audit_comments" USING "btree" ("user_id");



CREATE INDEX "idx_visual_audit_photos_task" ON "public"."visual_audit_photos" USING "btree" ("task_id");



CREATE INDEX "idx_visual_audit_photos_tenant" ON "public"."visual_audit_photos" USING "btree" ("tenant_id");



CREATE INDEX "idx_visual_audit_photos_uploaded_by" ON "public"."visual_audit_photos" USING "btree" ("uploaded_by");



CREATE INDEX "idx_visual_audit_sections_active" ON "public"."visual_audit_sections" USING "btree" ("tenant_id", "is_active");



CREATE INDEX "idx_visual_audit_sections_tenant" ON "public"."visual_audit_sections" USING "btree" ("tenant_id");



CREATE INDEX "idx_visual_audit_task_plans_active" ON "public"."visual_audit_task_plans" USING "btree" ("is_active");



CREATE INDEX "idx_visual_audit_task_plans_tenant" ON "public"."visual_audit_task_plans" USING "btree" ("tenant_id");



CREATE INDEX "idx_visual_audit_tasks_branch" ON "public"."visual_audit_tasks" USING "btree" ("branch_id");



CREATE INDEX "idx_visual_audit_tasks_date" ON "public"."visual_audit_tasks" USING "btree" ("scheduled_date");



CREATE INDEX "idx_visual_audit_tasks_pending" ON "public"."visual_audit_tasks" USING "btree" ("branch_id", "status", "scheduled_date") WHERE ("status" = ANY (ARRAY['pending'::"public"."visual_audit_task_status", 'in_progress'::"public"."visual_audit_task_status", 'rejected'::"public"."visual_audit_task_status"]));



CREATE INDEX "idx_visual_audit_tasks_plan" ON "public"."visual_audit_tasks" USING "btree" ("plan_id");



CREATE UNIQUE INDEX "idx_visual_audit_tasks_plan_unique" ON "public"."visual_audit_tasks" USING "btree" ("plan_id", "branch_id", "section_id", "scheduled_date", "scheduled_time") WHERE ("plan_id" IS NOT NULL);



CREATE INDEX "idx_visual_audit_tasks_section" ON "public"."visual_audit_tasks" USING "btree" ("section_id");



CREATE INDEX "idx_visual_audit_tasks_status" ON "public"."visual_audit_tasks" USING "btree" ("status");



CREATE INDEX "idx_visual_audit_tasks_template" ON "public"."visual_audit_tasks" USING "btree" ("template_id");



CREATE INDEX "idx_visual_audit_tasks_tenant" ON "public"."visual_audit_tasks" USING "btree" ("tenant_id");



CREATE INDEX "idx_visual_audit_template_branches_branch" ON "public"."visual_audit_template_branches" USING "btree" ("branch_id");



CREATE INDEX "idx_visual_audit_template_branches_template" ON "public"."visual_audit_template_branches" USING "btree" ("template_id");



CREATE INDEX "idx_visual_audit_templates_active" ON "public"."visual_audit_templates" USING "btree" ("tenant_id", "is_active");



CREATE INDEX "idx_visual_audit_templates_created_by" ON "public"."visual_audit_templates" USING "btree" ("created_by");



CREATE INDEX "idx_visual_audit_templates_tenant" ON "public"."visual_audit_templates" USING "btree" ("tenant_id");



CREATE INDEX "skt_records_deleted_at_idx" ON "public"."skt_records" USING "btree" ("deleted_at") WHERE ("deleted_at" IS NOT NULL);



CREATE INDEX "store_scoring_form_versions_form_idx" ON "public"."store_scoring_form_versions" USING "btree" ("form_id");



CREATE INDEX "store_scoring_forms_tenant_idx" ON "public"."store_scoring_forms" USING "btree" ("tenant_id");



CREATE INDEX "store_scoring_items_section_idx" ON "public"."store_scoring_items" USING "btree" ("section_id");



CREATE INDEX "store_scoring_sections_version_idx" ON "public"."store_scoring_sections" USING "btree" ("form_version_id");



CREATE INDEX "store_scoring_session_items_session_idx" ON "public"."store_scoring_session_items" USING "btree" ("session_id");



CREATE INDEX "store_scoring_sessions_branch_idx" ON "public"."store_scoring_sessions" USING "btree" ("branch_id");



CREATE INDEX "store_scoring_sessions_evaluator_idx" ON "public"."store_scoring_sessions" USING "btree" ("evaluator_id");



CREATE OR REPLACE VIEW "public"."v_survey_statistics" AS
 SELECT "a"."id" AS "announcement_id",
    "a"."title",
    "a"."tenant_id",
    "a"."published_at",
    "count"(DISTINCT "sr"."user_id") AS "total_responses",
    ( SELECT "count"(DISTINCT "u"."id") AS "count"
           FROM "public"."users" "u"
          WHERE (("u"."tenant_id" = "a"."tenant_id") AND ("u"."is_active" = true) AND (("a"."target_scope" = 'all_branches'::"public"."target_scope") OR (("a"."target_scope" = 'selected_branches'::"public"."target_scope") AND ("u"."branch_id" = ANY ("a"."target_branches"))) OR (("a"."target_scope" = 'region_managers_only'::"public"."target_scope") AND ("u"."role" = 'bolge_muduru'::"public"."user_role"))) AND ((NOT "a"."managers_only") OR ("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'firma_admin'::"public"."user_role"]))))) AS "target_audience_count"
   FROM ("public"."announcements" "a"
     LEFT JOIN "public"."survey_responses" "sr" ON (("sr"."announcement_id" = "a"."id")))
  WHERE ("a"."type" = 'survey'::"public"."announcement_type")
  GROUP BY "a"."id";



CREATE OR REPLACE TRIGGER "attendance_minutes_calculation" BEFORE UPDATE ON "public"."attendance" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_attendance_minutes"();



CREATE OR REPLACE TRIGGER "break_duration_calculation" BEFORE UPDATE ON "public"."break_logs" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_break_duration"();



CREATE OR REPLACE TRIGGER "depot_notice_offers_after_update" AFTER UPDATE ON "public"."depot_notice_offers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_offer_cancellation"();



CREATE OR REPLACE TRIGGER "depot_notice_offers_branch_name" BEFORE INSERT OR UPDATE ON "public"."depot_notice_offers" FOR EACH ROW EXECUTE FUNCTION "public"."depot_set_branch_name"();



CREATE OR REPLACE TRIGGER "depot_notice_offers_set_updated_at" BEFORE UPDATE ON "public"."depot_notice_offers" FOR EACH ROW EXECUTE FUNCTION "public"."depot_touch_updated_at"();



CREATE OR REPLACE TRIGGER "depot_notices_branch_name" BEFORE INSERT OR UPDATE ON "public"."depot_notices" FOR EACH ROW EXECUTE FUNCTION "public"."depot_set_branch_name"();



CREATE OR REPLACE TRIGGER "depot_notices_set_updated_at" BEFORE UPDATE ON "public"."depot_notices" FOR EACH ROW EXECUTE FUNCTION "public"."depot_touch_updated_at"();



CREATE OR REPLACE TRIGGER "set_bug_reports_updated_at" BEFORE UPDATE ON "public"."bug_reports" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_set_updated_at"();



CREATE OR REPLACE TRIGGER "skt_alarm_calculation" BEFORE INSERT OR UPDATE ON "public"."skt_records" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_skt_alarm_date"();



CREATE OR REPLACE TRIGGER "task_item_completion_update" AFTER INSERT OR DELETE OR UPDATE ON "public"."task_items" FOR EACH ROW EXECUTE FUNCTION "public"."update_task_completion"();



CREATE OR REPLACE TRIGGER "trg_branch_requests_updated_at" BEFORE UPDATE ON "public"."branch_requests" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trg_break_sessions_updated_at" BEFORE UPDATE ON "public"."break_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."set_break_session_updated_at"();



CREATE OR REPLACE TRIGGER "trg_notify_announcement_published" AFTER INSERT OR UPDATE ON "public"."announcements" FOR EACH ROW EXECUTE FUNCTION "public"."notify_announcement_published"();



CREATE OR REPLACE TRIGGER "trg_notify_visual_audit_comment_added" AFTER INSERT ON "public"."visual_audit_comments" FOR EACH ROW EXECUTE FUNCTION "public"."notify_visual_audit_comment_added"();



CREATE OR REPLACE TRIGGER "trg_notify_visual_audit_photo_uploaded" AFTER INSERT ON "public"."visual_audit_photos" FOR EACH ROW EXECUTE FUNCTION "public"."notify_visual_audit_photo_uploaded"();



CREATE OR REPLACE TRIGGER "trg_notify_visual_audit_task_completed" AFTER UPDATE OF "status" ON "public"."visual_audit_tasks" FOR EACH ROW EXECUTE FUNCTION "public"."notify_visual_audit_task_completed"();



CREATE OR REPLACE TRIGGER "trg_notify_visual_audit_task_created" AFTER INSERT ON "public"."visual_audit_tasks" FOR EACH ROW EXECUTE FUNCTION "public"."notify_visual_audit_task_created"();



CREATE OR REPLACE TRIGGER "trg_products_alt_barcodes" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."validate_products_alt_barcodes"();



CREATE OR REPLACE TRIGGER "trigger_notify_announcement_published" AFTER INSERT OR UPDATE OF "is_active" ON "public"."announcements" FOR EACH ROW EXECUTE FUNCTION "public"."notify_announcement_published"();



CREATE OR REPLACE TRIGGER "update_branches_updated_at" BEFORE UPDATE ON "public"."branches" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_products_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_regions_updated_at" BEFORE UPDATE ON "public"."regions" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_skt_records_updated_at" BEFORE UPDATE ON "public"."skt_records" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_tenants_updated_at" BEFORE UPDATE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "visual_audit_sections_updated_at" BEFORE UPDATE ON "public"."visual_audit_sections" FOR EACH ROW EXECUTE FUNCTION "public"."update_visual_audit_updated_at"();



CREATE OR REPLACE TRIGGER "visual_audit_tasks_updated_at" BEFORE UPDATE ON "public"."visual_audit_tasks" FOR EACH ROW EXECUTE FUNCTION "public"."update_visual_audit_updated_at"();



CREATE OR REPLACE TRIGGER "visual_audit_templates_updated_at" BEFORE UPDATE ON "public"."visual_audit_templates" FOR EACH ROW EXECUTE FUNCTION "public"."update_visual_audit_updated_at"();



ALTER TABLE ONLY "public"."announcement_reads"
    ADD CONSTRAINT "announcement_reads_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "public"."announcements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."announcement_reads"
    ADD CONSTRAINT "announcement_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_published_by_fkey" FOREIGN KEY ("published_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."branch_requests"
    ADD CONSTRAINT "branch_requests_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."branch_requests"
    ADD CONSTRAINT "branch_requests_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."branch_requests"
    ADD CONSTRAINT "branch_requests_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."branch_requests"
    ADD CONSTRAINT "branch_requests_target_user_id_fkey" FOREIGN KEY ("target_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."branch_scores"
    ADD CONSTRAINT "branch_scores_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."branch_scores"
    ADD CONSTRAINT "branch_scores_evaluated_by_fkey" FOREIGN KEY ("evaluated_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."branch_scores"
    ADD CONSTRAINT "branch_scores_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_region_id_fkey" FOREIGN KEY ("region_id") REFERENCES "public"."regions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."break_logs"
    ADD CONSTRAINT "break_logs_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."break_logs"
    ADD CONSTRAINT "break_logs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."break_logs"
    ADD CONSTRAINT "break_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."break_sessions"
    ADD CONSTRAINT "break_sessions_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id");



ALTER TABLE ONLY "public"."break_sessions"
    ADD CONSTRAINT "break_sessions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."break_sessions"
    ADD CONSTRAINT "break_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."bug_report_notifications"
    ADD CONSTRAINT "bug_report_notifications_bug_report_id_fkey" FOREIGN KEY ("bug_report_id") REFERENCES "public"."bug_reports"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bug_report_notifications"
    ADD CONSTRAINT "bug_report_notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bug_reports"
    ADD CONSTRAINT "bug_reports_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."bug_reports"
    ADD CONSTRAINT "bug_reports_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bug_reports"
    ADD CONSTRAINT "bug_reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."depot_notice_offers"
    ADD CONSTRAINT "depot_notice_offers_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."depot_notice_offers"
    ADD CONSTRAINT "depot_notice_offers_decision_by_fkey" FOREIGN KEY ("decision_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."depot_notice_offers"
    ADD CONSTRAINT "depot_notice_offers_notice_id_fkey" FOREIGN KEY ("notice_id") REFERENCES "public"."depot_notices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."depot_notice_offers"
    ADD CONSTRAINT "depot_notice_offers_offered_by_fkey" FOREIGN KEY ("offered_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."depot_notice_offers"
    ADD CONSTRAINT "depot_notice_offers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."depot_notices"
    ADD CONSTRAINT "depot_notices_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."depot_notices"
    ADD CONSTRAINT "depot_notices_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."depot_notices"
    ADD CONSTRAINT "depot_notices_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."device_tokens"
    ADD CONSTRAINT "device_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."employee_scores"
    ADD CONSTRAINT "employee_scores_evaluated_by_fkey" FOREIGN KEY ("evaluated_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."employee_scores"
    ADD CONSTRAINT "employee_scores_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."employee_scores"
    ADD CONSTRAINT "employee_scores_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_submissions"
    ADD CONSTRAINT "form_submissions_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_submissions"
    ADD CONSTRAINT "form_submissions_form_template_id_fkey" FOREIGN KEY ("form_template_id") REFERENCES "public"."form_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_submissions"
    ADD CONSTRAINT "form_submissions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_submissions"
    ADD CONSTRAINT "form_submissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."form_templates"
    ADD CONSTRAINT "form_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."form_templates"
    ADD CONSTRAINT "form_templates_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_reports"
    ADD CONSTRAINT "health_reports_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_reports"
    ADD CONSTRAINT "health_reports_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."health_reports"
    ADD CONSTRAINT "health_reports_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leave_requests"
    ADD CONSTRAINT "leave_requests_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leave_requests"
    ADD CONSTRAINT "leave_requests_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."leave_requests"
    ADD CONSTRAINT "leave_requests_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."leave_requests"
    ADD CONSTRAINT "leave_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."malfunction_reports"
    ADD CONSTRAINT "malfunction_reports_assigned_to_fkey" FOREIGN KEY ("assigned_to") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."malfunction_reports"
    ADD CONSTRAINT "malfunction_reports_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."malfunction_reports"
    ADD CONSTRAINT "malfunction_reports_reported_by_fkey" FOREIGN KEY ("reported_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."malfunction_reports"
    ADD CONSTRAINT "malfunction_reports_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."merch_people"
    ADD CONSTRAINT "merch_people_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."merch_people"
    ADD CONSTRAINT "merch_people_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."notification_queue"
    ADD CONSTRAINT "notification_queue_device_token_id_fkey" FOREIGN KEY ("device_token_id") REFERENCES "public"."device_tokens"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_queue"
    ADD CONSTRAINT "notification_queue_notification_id_fkey" FOREIGN KEY ("notification_id") REFERENCES "public"."notifications"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payrolls"
    ADD CONSTRAINT "payrolls_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payrolls"
    ADD CONSTRAINT "payrolls_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."payrolls"
    ADD CONSTRAINT "payrolls_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_issues"
    ADD CONSTRAINT "product_issues_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_issues"
    ADD CONSTRAINT "product_issues_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_issues"
    ADD CONSTRAINT "product_issues_reported_by_fkey" FOREIGN KEY ("reported_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_issues"
    ADD CONSTRAINT "product_issues_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."regions"
    ADD CONSTRAINT "regions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_pattern_drafts"
    ADD CONSTRAINT "shift_pattern_drafts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shift_pattern_drafts"
    ADD CONSTRAINT "shift_pattern_drafts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."shifts"
    ADD CONSTRAINT "shifts_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skt_alarm_notifications"
    ADD CONSTRAINT "skt_alarm_notifications_record_id_fkey" FOREIGN KEY ("record_id") REFERENCES "public"."skt_records"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skt_alarm_notifications"
    ADD CONSTRAINT "skt_alarm_notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skt_records"
    ADD CONSTRAINT "skt_records_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skt_records"
    ADD CONSTRAINT "skt_records_deleted_by_fkey" FOREIGN KEY ("deleted_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."skt_records"
    ADD CONSTRAINT "skt_records_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skt_records"
    ADD CONSTRAINT "skt_records_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."skt_records"
    ADD CONSTRAINT "skt_records_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stockout_items"
    ADD CONSTRAINT "stockout_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stockout_items"
    ADD CONSTRAINT "stockout_items_stockout_list_id_fkey" FOREIGN KEY ("stockout_list_id") REFERENCES "public"."stockout_lists"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stockout_lists"
    ADD CONSTRAINT "stockout_lists_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stockout_lists"
    ADD CONSTRAINT "stockout_lists_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."stockout_lists"
    ADD CONSTRAINT "stockout_lists_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_scoring_form_versions"
    ADD CONSTRAINT "store_scoring_form_versions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."store_scoring_form_versions"
    ADD CONSTRAINT "store_scoring_form_versions_form_id_fkey" FOREIGN KEY ("form_id") REFERENCES "public"."store_scoring_forms"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_scoring_forms"
    ADD CONSTRAINT "store_scoring_forms_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."store_scoring_forms"
    ADD CONSTRAINT "store_scoring_forms_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_scoring_items"
    ADD CONSTRAINT "store_scoring_items_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "public"."store_scoring_sections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_scoring_sections"
    ADD CONSTRAINT "store_scoring_sections_form_version_id_fkey" FOREIGN KEY ("form_version_id") REFERENCES "public"."store_scoring_form_versions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_scoring_session_items"
    ADD CONSTRAINT "store_scoring_session_items_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."store_scoring_items"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."store_scoring_session_items"
    ADD CONSTRAINT "store_scoring_session_items_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."store_scoring_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."store_scoring_sessions"
    ADD CONSTRAINT "store_scoring_sessions_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."store_scoring_sessions"
    ADD CONSTRAINT "store_scoring_sessions_evaluated_user_id_fkey" FOREIGN KEY ("evaluated_user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."store_scoring_sessions"
    ADD CONSTRAINT "store_scoring_sessions_evaluator_id_fkey" FOREIGN KEY ("evaluator_id") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."store_scoring_sessions"
    ADD CONSTRAINT "store_scoring_sessions_form_version_id_fkey" FOREIGN KEY ("form_version_id") REFERENCES "public"."store_scoring_form_versions"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."survey_answers"
    ADD CONSTRAINT "survey_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."survey_questions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."survey_answers"
    ADD CONSTRAINT "survey_answers_response_id_fkey" FOREIGN KEY ("response_id") REFERENCES "public"."survey_responses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."survey_questions"
    ADD CONSTRAINT "survey_questions_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "public"."announcements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."survey_responses"
    ADD CONSTRAINT "survey_responses_announcement_id_fkey" FOREIGN KEY ("announcement_id") REFERENCES "public"."announcements"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."survey_responses"
    ADD CONSTRAINT "survey_responses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_attachments"
    ADD CONSTRAINT "task_attachments_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_attachments"
    ADD CONSTRAINT "task_attachments_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_parent_task_id_fkey" FOREIGN KEY ("parent_task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_source_task_id_fkey" FOREIGN KEY ("source_task_id") REFERENCES "public"."tasks"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_enabled_by_fkey" FOREIGN KEY ("enabled_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_module_code_fkey" FOREIGN KEY ("module_code") REFERENCES "public"."modules"("code") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."todos"
    ADD CONSTRAINT "todos_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."todos"
    ADD CONSTRAINT "todos_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."todos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."todos"
    ADD CONSTRAINT "todos_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_module_preferences"
    ADD CONSTRAINT "user_module_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_comments"
    ADD CONSTRAINT "visual_audit_comments_photo_id_fkey" FOREIGN KEY ("photo_id") REFERENCES "public"."visual_audit_photos"("id");



ALTER TABLE ONLY "public"."visual_audit_comments"
    ADD CONSTRAINT "visual_audit_comments_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."visual_audit_tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_comments"
    ADD CONSTRAINT "visual_audit_comments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_comments"
    ADD CONSTRAINT "visual_audit_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."visual_audit_photos"
    ADD CONSTRAINT "visual_audit_photos_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."visual_audit_tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_photos"
    ADD CONSTRAINT "visual_audit_photos_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_photos"
    ADD CONSTRAINT "visual_audit_photos_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."visual_audit_sections"
    ADD CONSTRAINT "visual_audit_sections_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_task_plans"
    ADD CONSTRAINT "visual_audit_task_plans_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."visual_audit_task_plans"
    ADD CONSTRAINT "visual_audit_task_plans_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_plan_id_fkey" FOREIGN KEY ("plan_id") REFERENCES "public"."visual_audit_task_plans"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "public"."visual_audit_sections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."visual_audit_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_tasks"
    ADD CONSTRAINT "visual_audit_tasks_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_template_branches"
    ADD CONSTRAINT "visual_audit_template_branches_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_template_branches"
    ADD CONSTRAINT "visual_audit_template_branches_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."visual_audit_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_template_sections"
    ADD CONSTRAINT "visual_audit_template_sections_section_id_fkey" FOREIGN KEY ("section_id") REFERENCES "public"."visual_audit_sections"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_template_sections"
    ADD CONSTRAINT "visual_audit_template_sections_template_id_fkey" FOREIGN KEY ("template_id") REFERENCES "public"."visual_audit_templates"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."visual_audit_templates"
    ADD CONSTRAINT "visual_audit_templates_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."visual_audit_templates"
    ADD CONSTRAINT "visual_audit_templates_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



CREATE POLICY "Users can delete own module preferences" ON "public"."user_module_preferences" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can insert own module preferences" ON "public"."user_module_preferences" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update own module preferences" ON "public"."user_module_preferences" FOR UPDATE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view own module preferences" ON "public"."user_module_preferences" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "alarm_notifications_service" ON "public"."skt_alarm_notifications" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "alarm_notifications_user_select" ON "public"."skt_alarm_notifications" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "alarm_notifications_user_update" ON "public"."skt_alarm_notifications" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."announcement_reads" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "announcement_reads_owner" ON "public"."announcement_reads" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM ("public"."announcements" "a"
     JOIN "public"."users" "u" ON (("u"."id" = "auth"."uid"())))
  WHERE (("a"."id" = "announcement_reads"."announcement_id") AND ("a"."tenant_id" = "u"."tenant_id") AND (("a"."target_branches" IS NULL) OR ("array_length"("a"."target_branches", 1) IS NULL) OR ("u"."branch_id" = ANY ("a"."target_branches"))) AND (("a"."target_roles" IS NULL) OR ("array_length"("a"."target_roles", 1) IS NULL) OR (("u"."role")::"text" = ANY ("a"."target_roles"))))))));



CREATE POLICY "announcement_reads_owner_write" ON "public"."announcement_reads" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM ("public"."announcements" "a"
     JOIN "public"."users" "u" ON (("u"."id" = "auth"."uid"())))
  WHERE (("a"."id" = "announcement_reads"."announcement_id") AND ("a"."tenant_id" = "u"."tenant_id") AND (("a"."target_branches" IS NULL) OR ("array_length"("a"."target_branches", 1) IS NULL) OR ("u"."branch_id" = ANY ("a"."target_branches"))) AND (("a"."target_roles" IS NULL) OR ("array_length"("a"."target_roles", 1) IS NULL) OR (("u"."role")::"text" = ANY ("a"."target_roles"))))))));



CREATE POLICY "announcement_reads_select" ON "public"."announcement_reads" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
   FROM ("public"."users" "u"
     JOIN "public"."announcements" "a" ON (("a"."id" = "announcement_reads"."announcement_id")))
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."tenant_id" = "a"."tenant_id") AND ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])))))));



CREATE POLICY "announcement_reads_service_all" ON "public"."announcement_reads" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "announcements_admin_write" ON "public"."announcements" FOR INSERT TO "authenticated" WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "announcements"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"]))))) OR "public"."is_service_role"()));



CREATE POLICY "announcements_admin_write_delete" ON "public"."announcements" FOR DELETE TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "announcements"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"]))))) OR "public"."is_service_role"()));



CREATE POLICY "announcements_admin_write_update" ON "public"."announcements" FOR UPDATE TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "announcements"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"]))))) OR "public"."is_service_role"())) WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "announcements"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"]))))) OR "public"."is_service_role"()));



CREATE POLICY "announcements_audience_read" ON "public"."announcements" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "announcements"."tenant_id") AND (("announcements"."target_branches" IS NULL) OR ("array_length"("announcements"."target_branches", 1) IS NULL) OR ("ctx"."branch_id" = ANY ("announcements"."target_branches"))) AND (("announcements"."target_roles" IS NULL) OR ("array_length"("announcements"."target_roles", 1) IS NULL) OR (("ctx"."role")::"text" = ANY ("announcements"."target_roles")))))) OR "public"."is_service_role"()));



CREATE POLICY "announcements_service_all" ON "public"."announcements" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."attendance" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "attendance_service_all" ON "public"."attendance" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "attendance_tenant_scoped_read" ON "public"."attendance" FOR SELECT TO "authenticated" USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "attendance"."tenant_id") AND (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."role" = 'firma_admin'::"public"."user_role") OR (("ctx"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "attendance"."branch_id") AND ("r"."manager_id" = "ctx"."id") AND ("r"."tenant_id" = "ctx"."tenant_id"))))) OR (("ctx"."role" = 'sube_muduru'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id")) OR (("ctx"."role" = 'personel'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id") AND ("attendance"."user_id" = "ctx"."id"))))))));



CREATE POLICY "attendance_tenant_scoped_update" ON "public"."attendance" FOR UPDATE TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "attendance"."tenant_id") AND (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."role" = 'firma_admin'::"public"."user_role") OR (("ctx"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "attendance"."branch_id") AND ("r"."manager_id" = "ctx"."id") AND ("r"."tenant_id" = "ctx"."tenant_id"))))) OR (("ctx"."role" = 'sube_muduru'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id")) OR (("ctx"."role" = 'personel'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id") AND ("attendance"."user_id" = "ctx"."id")))))) OR "public"."is_service_role"())) WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "attendance"."tenant_id") AND (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."role" = 'firma_admin'::"public"."user_role") OR (("ctx"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "attendance"."branch_id") AND ("r"."manager_id" = "ctx"."id") AND ("r"."tenant_id" = "ctx"."tenant_id"))))) OR (("ctx"."role" = 'sube_muduru'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id")) OR (("ctx"."role" = 'personel'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id") AND ("attendance"."user_id" = "ctx"."id")))))) OR "public"."is_service_role"()));



CREATE POLICY "attendance_tenant_scoped_write" ON "public"."attendance" FOR INSERT TO "authenticated" WITH CHECK (((EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "attendance"."tenant_id") AND (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."role" = 'firma_admin'::"public"."user_role") OR (("ctx"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "attendance"."branch_id") AND ("r"."manager_id" = "ctx"."id") AND ("r"."tenant_id" = "ctx"."tenant_id"))))) OR (("ctx"."role" = 'sube_muduru'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id")) OR (("ctx"."role" = 'personel'::"public"."user_role") AND ("ctx"."branch_id" = "attendance"."branch_id") AND ("attendance"."user_id" = "ctx"."id")))))) OR "public"."is_service_role"()));



ALTER TABLE "public"."branch_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "branch_requests_insert" ON "public"."branch_requests" FOR INSERT WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "public"."current_user_id"()) AND ("u"."tenant_id" = "branch_requests"."tenant_id") AND ("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])))))));



CREATE POLICY "branch_requests_select" ON "public"."branch_requests" FOR SELECT USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "public"."current_user_id"()) AND ("u"."tenant_id" = "branch_requests"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "branch_requests"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("u"."branch_id" = "branch_requests"."branch_id"))))))));



CREATE POLICY "branch_requests_update" ON "public"."branch_requests" FOR UPDATE USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "public"."current_user_id"()) AND ("u"."tenant_id" = "branch_requests"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "branch_requests"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("u"."branch_id" = "branch_requests"."branch_id"))))))));



ALTER TABLE "public"."branch_scores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."branches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "branches_select" ON "public"."branches" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "branches"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM "public"."regions" "r"
          WHERE (("r"."id" = "branches"."region_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "branches"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("u"."branch_id" = "branches"."id"))))))))));



ALTER TABLE "public"."break_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."break_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "break_sessions_select" ON "public"."break_sessions" FOR SELECT USING ((("public"."current_user_id"() = "user_id") OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "break_sessions"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("ctx"."role" = 'bolge_muduru'::"public"."user_role") OR ("ctx"."branch_id" = "break_sessions"."branch_id")))))));



CREATE POLICY "break_user_modify_own" ON "public"."break_sessions" FOR INSERT WITH CHECK (("public"."current_user_id"() = "user_id"));



CREATE POLICY "break_user_update_own" ON "public"."break_sessions" FOR UPDATE USING (("public"."current_user_id"() = "user_id")) WITH CHECK (("public"."current_user_id"() = "user_id"));



ALTER TABLE "public"."bug_report_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bug_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."depot_notice_offers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "depot_notice_offers_insert" ON "public"."depot_notice_offers" FOR INSERT WITH CHECK ((("tenant_id" = "public"."current_tenant_id"()) AND ("branch_id" = ( SELECT "users"."branch_id"
   FROM "public"."users"
  WHERE ("users"."id" = "public"."current_user_id"()))) AND ("notice_id" IN ( SELECT "depot_notices"."id"
   FROM "public"."depot_notices"
  WHERE ("depot_notices"."tenant_id" = "public"."current_tenant_id"())))));



CREATE POLICY "depot_notice_offers_select" ON "public"."depot_notice_offers" FOR SELECT USING ((("tenant_id" = "public"."current_tenant_id"()) AND (("branch_id" = ( SELECT "users"."branch_id"
   FROM "public"."users"
  WHERE ("users"."id" = "public"."current_user_id"()))) OR ("notice_id" IN ( SELECT "depot_notices"."id"
   FROM "public"."depot_notices"
  WHERE ("depot_notices"."created_by" = "public"."current_user_id"()))))));



CREATE POLICY "depot_notice_offers_update" ON "public"."depot_notice_offers" FOR UPDATE USING ((("tenant_id" = "public"."current_tenant_id"()) AND (("notice_id" IN ( SELECT "depot_notices"."id"
   FROM "public"."depot_notices"
  WHERE ("depot_notices"."created_by" = "public"."current_user_id"()))) OR ("offered_by" = "public"."current_user_id"())))) WITH CHECK ((("tenant_id" = "public"."current_tenant_id"()) AND (("notice_id" IN ( SELECT "depot_notices"."id"
   FROM "public"."depot_notices"
  WHERE ("depot_notices"."created_by" = "public"."current_user_id"()))) OR ("offered_by" = "public"."current_user_id"()))));



ALTER TABLE "public"."depot_notices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "depot_notices_delete" ON "public"."depot_notices" FOR DELETE USING ((("tenant_id" = "public"."current_tenant_id"()) AND (("created_by" = "public"."current_user_id"()) OR ("public"."current_user_role"() = ANY (ARRAY['sube_muduru'::"text", 'firma_admin'::"text", 'grand_admin'::"text"])))));



CREATE POLICY "depot_notices_insert" ON "public"."depot_notices" FOR INSERT WITH CHECK ((("tenant_id" = "public"."current_tenant_id"()) AND ("branch_id" = ( SELECT "users"."branch_id"
   FROM "public"."users"
  WHERE ("users"."id" = "public"."current_user_id"())))));



CREATE POLICY "depot_notices_select" ON "public"."depot_notices" FOR SELECT USING (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "depot_notices_update" ON "public"."depot_notices" FOR UPDATE USING ((("tenant_id" = "public"."current_tenant_id"()) AND (("created_by" = "public"."current_user_id"()) OR ("public"."current_user_role"() = ANY (ARRAY['sube_muduru'::"text", 'firma_admin'::"text", 'grand_admin'::"text"]))))) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."device_tokens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "device_tokens_service_all" ON "public"."device_tokens" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "device_tokens_user_insert" ON "public"."device_tokens" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "device_tokens_user_select" ON "public"."device_tokens" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "device_tokens_user_update" ON "public"."device_tokens" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."employee_scores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "firma_admin_view_tenant_bug_reports" ON "public"."bug_reports" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'firma_admin'::"public"."user_role") AND ("u"."tenant_id" = "bug_reports"."tenant_id")))));



ALTER TABLE "public"."form_submissions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_submissions_select" ON "public"."form_submissions" FOR SELECT TO "authenticated" USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "public"."current_user_id"()) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "form_submissions"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("u"."branch_id" = "form_submissions"."branch_id") OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "form_submissions"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id")))))) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "form_submissions"."user_id"))))))))));



ALTER TABLE "public"."form_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_templates_all" ON "public"."form_templates" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "form_templates"."tenant_id") AND ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'sube_muduru'::"public"."user_role"]))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "form_templates"."tenant_id") AND ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'sube_muduru'::"public"."user_role"])))))))));



CREATE POLICY "grand_admin_insert_notifications" ON "public"."bug_report_notifications" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'grand_admin'::"public"."user_role")))));



CREATE POLICY "grand_admin_update_bug_reports" ON "public"."bug_reports" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'grand_admin'::"public"."user_role")))));



CREATE POLICY "grand_admin_view_all_bug_reports" ON "public"."bug_reports" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'grand_admin'::"public"."user_role")))));



ALTER TABLE "public"."health_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_reports_all" ON "public"."health_reports" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "health_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("u"."branch_id" = "health_reports"."branch_id") OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "health_reports"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id")))))) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "health_reports"."user_id")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "health_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR ("u"."role" = 'sube_muduru'::"public"."user_role") OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "health_reports"."user_id"))))))))));



ALTER TABLE "public"."leave_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "leave_requests_insert" ON "public"."leave_requests" FOR INSERT WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "leave_requests"."tenant_id") AND ((("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "leave_requests"."user_id")) OR ("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'firma_admin'::"public"."user_role"]))))))))));



CREATE POLICY "leave_requests_select" ON "public"."leave_requests" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "leave_requests"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("u"."branch_id" = "leave_requests"."branch_id") OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "leave_requests"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id")))))) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "leave_requests"."user_id"))))))))));



CREATE POLICY "leave_requests_update" ON "public"."leave_requests" FOR UPDATE USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "leave_requests"."tenant_id") AND (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "leave_requests"."user_id")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "leave_requests"."tenant_id") AND (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "leave_requests"."user_id"))))))))));



ALTER TABLE "public"."malfunction_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "malfunction_reports_all" ON "public"."malfunction_reports" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "malfunction_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("u"."branch_id" = "malfunction_reports"."branch_id") OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "malfunction_reports"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id")))))) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "malfunction_reports"."reported_by")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "malfunction_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR ("u"."role" = 'sube_muduru'::"public"."user_role") OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "malfunction_reports"."reported_by"))))))))));



ALTER TABLE "public"."merch_people" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "merch_people_delete" ON "public"."merch_people" FOR DELETE USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"]))))))));



CREATE POLICY "merch_people_insert" ON "public"."merch_people" FOR INSERT WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"]))))))));



CREATE POLICY "merch_people_select" ON "public"."merch_people" FOR SELECT USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"]))))))));



CREATE POLICY "merch_people_update" ON "public"."merch_people" FOR UPDATE USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"]))))))));



ALTER TABLE "public"."modules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "modules_select" ON "public"."modules" FOR SELECT USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'authenticated'::"text") OR (COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'anon'::"text")));



ALTER TABLE "public"."notification_queue" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notification_queue_policy" ON "public"."notification_queue" USING (false);



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_all" ON "public"."notifications" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "notifications"."tenant_id") AND (("u"."id" = "notifications"."user_id") OR ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "notifications"."tenant_id") AND ("u"."id" = "notifications"."user_id"))))))));



CREATE POLICY "notifications_insert_policy" ON "public"."notifications" FOR INSERT WITH CHECK (true);



CREATE POLICY "notifications_select_policy" ON "public"."notifications" FOR SELECT USING (("user_id" = "auth"."uid"()));



CREATE POLICY "notifications_update_policy" ON "public"."notifications" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."payrolls" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_issues" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_select" ON "public"."products" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."tenant_id" = "products"."tenant_id"))))));



ALTER TABLE "public"."regions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "regions_select_for_managers" ON "public"."regions" FOR SELECT USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."tenant_id" = "regions"."tenant_id") AND (("ctx"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("ctx"."role" = 'bolge_muduru'::"public"."user_role") AND ("regions"."manager_id" = "ctx"."id"))))))));



ALTER TABLE "public"."shift_pattern_drafts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shift_pattern_drafts_owner_delete" ON "public"."shift_pattern_drafts" FOR DELETE USING ((("user_id" = "public"."current_user_id"()) AND ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "shift_pattern_drafts_owner_insert" ON "public"."shift_pattern_drafts" FOR INSERT WITH CHECK ((("user_id" = "public"."current_user_id"()) AND ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "shift_pattern_drafts_owner_select" ON "public"."shift_pattern_drafts" FOR SELECT USING ((("user_id" = "public"."current_user_id"()) AND ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "shift_pattern_drafts_owner_update" ON "public"."shift_pattern_drafts" FOR UPDATE USING ((("user_id" = "public"."current_user_id"()) AND ("tenant_id" = "public"."current_tenant_id"()))) WITH CHECK ((("user_id" = "public"."current_user_id"()) AND ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "shift_pattern_drafts_service_all" ON "public"."shift_pattern_drafts" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."shifts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shifts_insert" ON "public"."shifts" FOR INSERT WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "shifts"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "shifts"."branch_id"))))))))));



CREATE POLICY "shifts_select" ON "public"."shifts" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "shifts"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM "public"."regions" "r"
          WHERE (("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id") AND (EXISTS ( SELECT 1
                   FROM "public"."branches" "b"
                  WHERE (("b"."id" = "shifts"."branch_id") AND ("b"."region_id" = "r"."id")))))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("u"."branch_id" = "shifts"."branch_id"))))))))));



CREATE POLICY "shifts_update" ON "public"."shifts" FOR UPDATE USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "shifts"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "shifts"."branch_id")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "shifts"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "shifts"."branch_id"))))))))));



ALTER TABLE "public"."skt_alarm_notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "skt_delete_branch_staff" ON "public"."skt_records" FOR DELETE USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."role" = ANY ('{sube_muduru,personel}'::"public"."user_role"[])) AND ("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."branch_id" = "skt_records"."branch_id"))))));



CREATE POLICY "skt_insert_branch_staff" ON "public"."skt_records" FOR INSERT WITH CHECK (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."role" = ANY ('{sube_muduru,personel}'::"public"."user_role"[])) AND ("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."branch_id" = "skt_records"."branch_id") AND ("skt_records"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



ALTER TABLE "public"."skt_records" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "skt_select_core" ON "public"."skt_records" FOR SELECT USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."role" = 'firma_admin'::"public"."user_role")) OR (("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "skt_records"."branch_id") AND ("b"."tenant_id" = "skt_records"."tenant_id") AND ("r"."manager_id" = "u"."id"))))) OR (("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "skt_records"."branch_id") AND (("skt_records"."deleted_at" IS NULL) OR ("skt_records"."deleted_at" >= ("now"() - '1 mon'::interval)))) OR (("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."role" = 'personel'::"public"."user_role") AND ("u"."branch_id" = "skt_records"."branch_id") AND ("skt_records"."deleted_at" IS NULL))))))));



CREATE POLICY "skt_update_branch_staff" ON "public"."skt_records" FOR UPDATE USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."role" = ANY ('{sube_muduru,personel}'::"public"."user_role"[])) AND ("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."branch_id" = "skt_records"."branch_id")))))) WITH CHECK (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."role" = ANY ('{sube_muduru,personel}'::"public"."user_role"[])) AND ("u"."tenant_id" = "skt_records"."tenant_id") AND ("u"."branch_id" = "skt_records"."branch_id")))) AND (("deleted_at" IS NULL) OR ("deleted_by" = ( SELECT "auth"."uid"() AS "uid"))))));



ALTER TABLE "public"."stockout_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stockout_lists" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "store_form_versions_access_v2" ON "public"."store_scoring_form_versions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."store_scoring_forms" "f"
  WHERE (("f"."id" = "store_scoring_form_versions"."form_id") AND ("f"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id"))))));



CREATE POLICY "store_forms_access_v2" ON "public"."store_scoring_forms" FOR SELECT TO "authenticated" USING (("tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")));



ALTER TABLE "public"."store_scoring_form_versions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_scoring_forms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_scoring_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "store_scoring_items_select" ON "public"."store_scoring_items" FOR SELECT TO "authenticated" USING (("public"."is_service_role"() OR ("public"."current_user_role"() = 'grand_admin'::"text") OR (EXISTS ( SELECT 1
   FROM (("public"."store_scoring_sections" "s"
     JOIN "public"."store_scoring_form_versions" "fv" ON (("fv"."id" = "s"."form_version_id")))
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
  WHERE (("s"."id" = "store_scoring_items"."section_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))));



ALTER TABLE "public"."store_scoring_sections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "store_scoring_sections_select" ON "public"."store_scoring_sections" FOR SELECT TO "authenticated" USING (("public"."is_service_role"() OR ("public"."current_user_role"() = 'grand_admin'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "fv"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
  WHERE (("fv"."id" = "store_scoring_sections"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))));



ALTER TABLE "public"."store_scoring_session_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "store_scoring_session_items_manage" ON "public"."store_scoring_session_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."store_scoring_sessions" "s"
  WHERE (("s"."id" = "store_scoring_session_items"."session_id") AND (("public"."current_user_role"() = 'grand_admin'::"text") OR (("public"."current_user_role"() = 'firma_admin'::"text") AND ("s"."branch_id" IN ( SELECT "b"."id"
           FROM "public"."branches" "b"
          WHERE ("b"."tenant_id" = "public"."current_tenant_id"())))) OR (("public"."current_user_role"() = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
           FROM "public"."regions" "r"
          WHERE (("r"."id" = ( SELECT "b"."region_id"
                   FROM "public"."branches" "b"
                  WHERE ("b"."id" = "s"."branch_id"))) AND ("r"."manager_id" = "public"."current_user_id"()) AND ("r"."tenant_id" = "public"."current_tenant_id"()))))) OR (("public"."current_user_role"() = 'sube_muduru'::"text") AND ("s"."branch_id" = ( SELECT "u"."branch_id"
           FROM "public"."users" "u"
          WHERE ("u"."id" = "public"."current_user_id"())))) OR (("public"."current_user_role"() = 'personel'::"text") AND ("s"."evaluator_id" = "public"."current_user_id"()))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."store_scoring_sessions" "s"
  WHERE (("s"."id" = "store_scoring_session_items"."session_id") AND (("public"."current_user_role"() = 'grand_admin'::"text") OR (("public"."current_user_role"() = 'firma_admin'::"text") AND ("s"."branch_id" IN ( SELECT "b"."id"
           FROM "public"."branches" "b"
          WHERE ("b"."tenant_id" = "public"."current_tenant_id"())))) OR (("public"."current_user_role"() = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
           FROM "public"."regions" "r"
          WHERE (("r"."id" = ( SELECT "b"."region_id"
                   FROM "public"."branches" "b"
                  WHERE ("b"."id" = "s"."branch_id"))) AND ("r"."manager_id" = "public"."current_user_id"()) AND ("r"."tenant_id" = "public"."current_tenant_id"()))))) OR (("public"."current_user_role"() = 'sube_muduru'::"text") AND ("s"."branch_id" = ( SELECT "u"."branch_id"
           FROM "public"."users" "u"
          WHERE ("u"."id" = "public"."current_user_id"())))) OR (("public"."current_user_role"() = 'personel'::"text") AND ("s"."evaluator_id" = "public"."current_user_id"())))))));



ALTER TABLE "public"."store_scoring_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "store_scoring_sessions_delete" ON "public"."store_scoring_sessions" FOR DELETE TO "authenticated" USING ((("public"."current_user_role"() = ANY (ARRAY['grand_admin'::"text", 'firma_admin'::"text"])) OR (("public"."current_user_role"() = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."branches" "b"
     JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
  WHERE (("b"."id" = "store_scoring_sessions"."branch_id") AND ("r"."manager_id" = "public"."current_user_id"()) AND ("r"."tenant_id" = "public"."current_tenant_id"()))))) OR "public"."is_service_role"()));



CREATE POLICY "store_scoring_sessions_insert_v2" ON "public"."store_scoring_sessions" FOR INSERT TO "authenticated" WITH CHECK (((( SELECT "public"."current_user_role"() AS "current_user_role") = 'grand_admin'::"text") OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."store_scoring_forms" "f"
  WHERE (("f"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."branches" "b"
     JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
  WHERE (("b"."id" = "store_scoring_sessions"."branch_id") AND ("r"."manager_id" = ( SELECT "public"."current_user_id"() AS "current_user_id")) AND ("r"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ( SELECT "public"."is_service_role"() AS "is_service_role")));



COMMENT ON POLICY "store_scoring_sessions_insert_v2" ON "public"."store_scoring_sessions" IS 'Consolidated insert policy with optimized auth calls - fixes auth_rls_initplan and multiple_permissive warnings';



CREATE POLICY "store_scoring_sessions_select_v2" ON "public"."store_scoring_sessions" FOR SELECT TO "authenticated" USING (((( SELECT "public"."current_user_role"() AS "current_user_role") = 'grand_admin'::"text") OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."branches" "b"
     JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
  WHERE (("b"."id" = "store_scoring_sessions"."branch_id") AND ("r"."manager_id" = ( SELECT "public"."current_user_id"() AS "current_user_id")) AND ("r"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = ANY (ARRAY['sube_muduru'::"text", 'personel'::"text"])) AND ("evaluator_id" = ( SELECT "public"."current_user_id"() AS "current_user_id"))) OR ( SELECT "public"."is_service_role"() AS "is_service_role")));



COMMENT ON POLICY "store_scoring_sessions_select_v2" ON "public"."store_scoring_sessions" IS 'Consolidated select policy with optimized auth calls - fixes auth_rls_initplan warning';



CREATE POLICY "store_scoring_sessions_update_v2" ON "public"."store_scoring_sessions" FOR UPDATE TO "authenticated" USING (((( SELECT "public"."current_user_role"() AS "current_user_role") = 'grand_admin'::"text") OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."branches" "b"
     JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
  WHERE (("b"."id" = "store_scoring_sessions"."branch_id") AND ("r"."manager_id" = ( SELECT "public"."current_user_id"() AS "current_user_id")) AND ("r"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ( SELECT "public"."is_service_role"() AS "is_service_role"))) WITH CHECK (((( SELECT "public"."current_user_role"() AS "current_user_role") = 'grand_admin'::"text") OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ((( SELECT "public"."current_user_role"() AS "current_user_role") = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."branches" "b"
     JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
  WHERE (("b"."id" = "store_scoring_sessions"."branch_id") AND ("r"."manager_id" = ( SELECT "public"."current_user_id"() AS "current_user_id")) AND ("r"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))) OR ( SELECT "public"."is_service_role"() AS "is_service_role")));



COMMENT ON POLICY "store_scoring_sessions_update_v2" ON "public"."store_scoring_sessions" IS 'Consolidated update policy with optimized auth calls - fixes auth_rls_initplan and multiple_permissive warnings';



ALTER TABLE "public"."survey_answers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "survey_answers_insert" ON "public"."survey_answers" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."survey_responses" "sr"
  WHERE (("sr"."id" = "survey_answers"."response_id") AND ("sr"."user_id" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "survey_answers_select" ON "public"."survey_answers" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."survey_responses" "sr"
  WHERE (("sr"."id" = "survey_answers"."response_id") AND (("sr"."user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
           FROM "public"."announcements" "a"
          WHERE (("a"."id" = "sr"."announcement_id") AND ("a"."published_by" = ( SELECT "auth"."uid"() AS "uid"))))) OR (( SELECT "public"."current_user_role"() AS "current_user_role") = ANY (ARRAY['firma_admin'::"text", 'grand_admin'::"text"])))))));



ALTER TABLE "public"."survey_questions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "survey_questions_delete" ON "public"."survey_questions" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."announcements" "a"
  WHERE (("a"."id" = "survey_questions"."announcement_id") AND ("a"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")) AND ("a"."published_by" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "survey_questions_insert" ON "public"."survey_questions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."announcements" "a"
  WHERE (("a"."id" = "survey_questions"."announcement_id") AND ("a"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")) AND ("a"."published_by" = ( SELECT "auth"."uid"() AS "uid"))))));



CREATE POLICY "survey_questions_select" ON "public"."survey_questions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."announcements" "a"
  WHERE (("a"."id" = "survey_questions"."announcement_id") AND ("a"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id"))))));



CREATE POLICY "survey_questions_update" ON "public"."survey_questions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."announcements" "a"
  WHERE (("a"."id" = "survey_questions"."announcement_id") AND ("a"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")) AND ("a"."published_by" = ( SELECT "auth"."uid"() AS "uid"))))));



ALTER TABLE "public"."survey_responses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "survey_responses_insert" ON "public"."survey_responses" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "survey_responses_select" ON "public"."survey_responses" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
   FROM "public"."announcements" "a"
  WHERE (("a"."id" = "survey_responses"."announcement_id") AND ("a"."published_by" = ( SELECT "auth"."uid"() AS "uid"))))) OR (( SELECT "public"."current_user_role"() AS "current_user_role") = ANY (ARRAY['firma_admin'::"text", 'grand_admin'::"text"]))));



ALTER TABLE "public"."task_assignees" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "task_assignees_all" ON "public"."task_assignees" USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."users" "u" ON (("u"."id" = "public"."current_user_id"())))
  WHERE (("t"."id" = "task_assignees"."task_id") AND ("t"."tenant_id" = "u"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "t"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND (("t"."branch_id" = "u"."branch_id") OR ("task_assignees"."user_id" = "u"."id"))))))))) WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."users" "u" ON (("u"."id" = "public"."current_user_id"())))
  WHERE (("t"."id" = "task_assignees"."task_id") AND ("t"."tenant_id" = "u"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "t"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND (("t"."branch_id" = "u"."branch_id") OR ("task_assignees"."user_id" = "u"."id")))))))));



ALTER TABLE "public"."task_attachments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "task_attachments_delete_v2" ON "public"."task_attachments" FOR DELETE TO "authenticated" USING ((("uploaded_by" = ( SELECT "auth"."uid"() AS "uid")) OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND ("u"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")) AND ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role"])))))));



COMMENT ON POLICY "task_attachments_delete_v2" ON "public"."task_attachments" IS 'Optimized delete policy - fixes auth_rls_initplan warning';



CREATE POLICY "task_attachments_insert_v2" ON "public"."task_attachments" FOR INSERT TO "authenticated" WITH CHECK ((("uploaded_by" = ( SELECT "auth"."uid"() AS "uid")) AND (EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_attachments"."task_id") AND ("t"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id")))))));



COMMENT ON POLICY "task_attachments_insert_v2" ON "public"."task_attachments" IS 'Optimized insert policy - fixes auth_rls_initplan warning';



CREATE POLICY "task_attachments_select_v2" ON "public"."task_attachments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."tasks" "t"
  WHERE (("t"."id" = "task_attachments"."task_id") AND ("t"."tenant_id" = ( SELECT "public"."current_tenant_id"() AS "current_tenant_id"))))));



COMMENT ON POLICY "task_attachments_select_v2" ON "public"."task_attachments" IS 'Optimized select policy - fixes auth_rls_initplan warning';



ALTER TABLE "public"."task_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "task_items_all" ON "public"."task_items" USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."users" "u" ON (("u"."id" = "public"."current_user_id"())))
  WHERE (("t"."id" = "task_items"."task_id") AND ("t"."tenant_id" = "u"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "t"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND (("t"."branch_id" = "u"."branch_id") OR (EXISTS ( SELECT 1
           FROM "public"."task_assignees" "ta"
          WHERE (("ta"."task_id" = "task_items"."task_id") AND ("ta"."user_id" = "u"."id")))))))))))) WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."users" "u" ON (("u"."id" = "public"."current_user_id"())))
  WHERE (("t"."id" = "task_items"."task_id") AND ("t"."tenant_id" = "u"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "t"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND (("t"."branch_id" = "u"."branch_id") OR (EXISTS ( SELECT 1
           FROM "public"."task_assignees" "ta"
          WHERE (("ta"."task_id" = "task_items"."task_id") AND ("ta"."user_id" = "u"."id"))))))))))));



ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tasks_delete" ON "public"."tasks" FOR DELETE USING (("public"."is_service_role"() OR (("created_by" = "public"."current_user_id"()) AND ("tenant_id" = COALESCE("public"."current_tenant_id"(), ( SELECT "u"."tenant_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = "public"."current_user_id"())))))));



CREATE POLICY "tasks_insert" ON "public"."tasks" FOR INSERT WITH CHECK (("public"."is_service_role"() OR (("created_by" = "public"."current_user_id"()) AND ("tenant_id" = COALESCE("public"."current_tenant_id"(), ( SELECT "u"."tenant_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = "public"."current_user_id"())))))));



CREATE POLICY "tasks_select" ON "public"."tasks" FOR SELECT USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "public"."current_user_id"()) AND ("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "tasks"."branch_id") AND ("b"."tenant_id" = "u"."tenant_id") AND ("r"."manager_id" = "u"."id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("tasks"."branch_id" = "u"."branch_id"))))))));



CREATE POLICY "tasks_update" ON "public"."tasks" FOR UPDATE USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "public"."current_user_id"()) AND ("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("tasks"."branch_id" = "u"."branch_id")))))))) WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "public"."current_user_id"()) AND ("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("tasks"."branch_id" = "u"."branch_id"))))))));



ALTER TABLE "public"."tenant_modules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tenant_modules_insert" ON "public"."tenant_modules" FOR INSERT WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."tenant_id" = "tenant_modules"."tenant_id"))))));



CREATE POLICY "tenant_modules_select" ON "public"."tenant_modules" FOR SELECT USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."tenant_id" = "tenant_modules"."tenant_id"))))));



CREATE POLICY "tenant_modules_update" ON "public"."tenant_modules" FOR UPDATE USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."tenant_id" = "tenant_modules"."tenant_id")))))) WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR ("ctx"."tenant_id" = "tenant_modules"."tenant_id"))))));



ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tenants_select_all" ON "public"."tenants" FOR SELECT USING ((("public"."current_user_role"() = 'grand_admin'::"text") OR "public"."is_service_role"() OR ("id" = "public"."current_tenant_id"())));



ALTER TABLE "public"."todos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "todos_delete_self" ON "public"."todos" FOR DELETE USING (("public"."is_service_role"() OR (("owner_id" = "public"."current_user_id"()) AND ("tenant_id" = COALESCE("public"."current_tenant_id"(), ( SELECT "u"."tenant_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = "public"."current_user_id"())))))));



CREATE POLICY "todos_insert_self" ON "public"."todos" FOR INSERT WITH CHECK (("public"."is_service_role"() OR (("owner_id" = "public"."current_user_id"()) AND ("tenant_id" = COALESCE("public"."current_tenant_id"(), ( SELECT "u"."tenant_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = "public"."current_user_id"())))))));



CREATE POLICY "todos_select_self" ON "public"."todos" FOR SELECT USING (("public"."is_service_role"() OR (("owner_id" = "public"."current_user_id"()) AND ("tenant_id" = COALESCE("public"."current_tenant_id"(), ( SELECT "u"."tenant_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = "public"."current_user_id"())))))));



CREATE POLICY "todos_update_self" ON "public"."todos" FOR UPDATE USING (("public"."is_service_role"() OR (("owner_id" = "public"."current_user_id"()) AND ("tenant_id" = COALESCE("public"."current_tenant_id"(), ( SELECT "u"."tenant_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = "public"."current_user_id"()))))))) WITH CHECK (("public"."is_service_role"() OR (("owner_id" = "public"."current_user_id"()) AND ("tenant_id" = COALESCE("public"."current_tenant_id"(), ( SELECT "u"."tenant_id"
   FROM "public"."users" "u"
  WHERE ("u"."id" = "public"."current_user_id"())))))));



ALTER TABLE "public"."user_module_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_insert_bug_reports" ON "public"."bug_reports" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "users_select_policy" ON "public"."users" FOR SELECT USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (( SELECT "auth"."uid"() AS "uid") = "id") OR (("tenant_id" = "public"."current_tenant_id"()) AND ((("public"."get_my_role"() = 'sube_muduru'::"text") AND ("branch_id" = "public"."get_my_branch_id"())) OR (("public"."get_my_role"() = 'bolge_muduru'::"text") AND ("branch_id" IN ( SELECT "public"."get_my_managed_branch_ids"() AS "get_my_managed_branch_ids"))) OR ("public"."get_my_role"() = ANY (ARRAY['firma_admin'::"text", 'grand_admin'::"text"]))))));



CREATE POLICY "users_update_own_notifications" ON "public"."bug_report_notifications" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_view_own_bug_reports" ON "public"."bug_reports" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "users_view_own_notifications" ON "public"."bug_report_notifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."visual_audit_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_comments_insert" ON "public"."visual_audit_comments" FOR INSERT WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "visual_audit_comments_select" ON "public"."visual_audit_comments" FOR SELECT USING ((("public"."current_user_role"() = 'grand_admin'::"text") OR ("tenant_id" = "public"."current_tenant_id"())));



ALTER TABLE "public"."visual_audit_photos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_photos_delete" ON "public"."visual_audit_photos" FOR DELETE USING ((("tenant_id" = "public"."current_tenant_id"()) AND (("uploaded_by" = "public"."current_user_id"()) OR ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text", 'sube_muduru'::"text"])))));



CREATE POLICY "visual_audit_photos_insert" ON "public"."visual_audit_photos" FOR INSERT WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "visual_audit_photos_select" ON "public"."visual_audit_photos" FOR SELECT USING ((("public"."current_user_role"() = 'grand_admin'::"text") OR ("tenant_id" = "public"."current_tenant_id"())));



ALTER TABLE "public"."visual_audit_sections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_sections_delete" ON "public"."visual_audit_sections" FOR DELETE USING ((("tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = 'firma_admin'::"text")));



CREATE POLICY "visual_audit_sections_insert" ON "public"."visual_audit_sections" FOR INSERT WITH CHECK ((("tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"]))));



CREATE POLICY "visual_audit_sections_select" ON "public"."visual_audit_sections" FOR SELECT USING ((("tenant_id" = "public"."current_tenant_id"()) OR ("public"."current_user_role"() = 'grand_admin'::"text")));



CREATE POLICY "visual_audit_sections_update" ON "public"."visual_audit_sections" FOR UPDATE USING ((("tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"]))));



ALTER TABLE "public"."visual_audit_task_plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_task_plans_delete" ON "public"."visual_audit_task_plans" FOR DELETE USING (("tenant_id" = ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))));



CREATE POLICY "visual_audit_task_plans_insert" ON "public"."visual_audit_task_plans" FOR INSERT WITH CHECK (("tenant_id" = ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))));



CREATE POLICY "visual_audit_task_plans_select" ON "public"."visual_audit_task_plans" FOR SELECT USING (("tenant_id" = ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))));



CREATE POLICY "visual_audit_task_plans_update" ON "public"."visual_audit_task_plans" FOR UPDATE USING (("tenant_id" = ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))));



ALTER TABLE "public"."visual_audit_tasks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_tasks_select" ON "public"."visual_audit_tasks" FOR SELECT USING ((("public"."current_user_role"() = 'grand_admin'::"text") OR ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "visual_audit_tasks_update" ON "public"."visual_audit_tasks" FOR UPDATE USING (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."visual_audit_template_branches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_template_branches_delete" ON "public"."visual_audit_template_branches" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."visual_audit_templates" "t"
  WHERE (("t"."id" = "visual_audit_template_branches"."template_id") AND ("t"."tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"]))))));



CREATE POLICY "visual_audit_template_branches_insert" ON "public"."visual_audit_template_branches" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."visual_audit_templates" "t"
  WHERE (("t"."id" = "visual_audit_template_branches"."template_id") AND ("t"."tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"]))))));



CREATE POLICY "visual_audit_template_branches_select" ON "public"."visual_audit_template_branches" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."visual_audit_templates" "t"
  WHERE (("t"."id" = "visual_audit_template_branches"."template_id") AND (("t"."tenant_id" = "public"."current_tenant_id"()) OR ("public"."current_user_role"() = 'grand_admin'::"text"))))));



ALTER TABLE "public"."visual_audit_template_sections" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_template_sections_insert" ON "public"."visual_audit_template_sections" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."visual_audit_templates" "t"
  WHERE (("t"."id" = "visual_audit_template_sections"."template_id") AND ("t"."tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"]))))));



CREATE POLICY "visual_audit_template_sections_select" ON "public"."visual_audit_template_sections" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."visual_audit_templates" "t"
  WHERE (("t"."id" = "visual_audit_template_sections"."template_id") AND (("t"."tenant_id" = "public"."current_tenant_id"()) OR ("public"."current_user_role"() = 'grand_admin'::"text"))))));



ALTER TABLE "public"."visual_audit_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "visual_audit_templates_delete" ON "public"."visual_audit_templates" FOR DELETE USING ((("tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"]))));



CREATE POLICY "visual_audit_templates_insert" ON "public"."visual_audit_templates" FOR INSERT WITH CHECK ((("tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text", 'sube_muduru'::"text"]))));



CREATE POLICY "visual_audit_templates_select" ON "public"."visual_audit_templates" FOR SELECT USING ((("tenant_id" = "public"."current_tenant_id"()) OR ("public"."current_user_role"() = 'grand_admin'::"text")));



CREATE POLICY "visual_audit_templates_update" ON "public"."visual_audit_templates" FOR UPDATE USING ((("tenant_id" = "public"."current_tenant_id"()) AND ("public"."current_user_role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text", 'sube_muduru'::"text"]))));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."depot_notice_offers";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."depot_notices";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."merch_people";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT USAGE ON SCHEMA "public" TO "supabase_auth_admin";











































































































































































































































































GRANT ALL ON FUNCTION "public"."add_personel"("p_employee_code" "text", "p_password" "text", "p_tenant_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."add_personel"("p_employee_code" "text", "p_password" "text", "p_tenant_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_personel"("p_employee_code" "text", "p_password" "text", "p_tenant_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_visual_audit_comment"("p_task_id" "uuid", "p_message" "text", "p_comment_type" "public"."visual_audit_comment_type", "p_photo_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."add_visual_audit_comment"("p_task_id" "uuid", "p_message" "text", "p_comment_type" "public"."visual_audit_comment_type", "p_photo_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_visual_audit_comment"("p_task_id" "uuid", "p_message" "text", "p_comment_type" "public"."visual_audit_comment_type", "p_photo_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."batch_update_module_order"("p_module_orders" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."batch_update_module_order"("p_module_orders" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."batch_update_module_order"("p_module_orders" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."branch_belongs_to_current_tenant"("p_branch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."branch_belongs_to_current_tenant"("p_branch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."branch_belongs_to_current_tenant"("p_branch_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_attendance_minutes"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_attendance_minutes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_attendance_minutes"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_break_duration"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_break_duration"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_break_duration"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calculate_skt_alarm_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."calculate_skt_alarm_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."calculate_skt_alarm_date"() TO "service_role";



GRANT ALL ON FUNCTION "public"."copy_visual_audit_plan"("p_plan_id" "uuid", "p_new_name" "text", "p_start_date" "date", "p_end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."copy_visual_audit_plan"("p_plan_id" "uuid", "p_new_name" "text", "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."copy_visual_audit_plan"("p_plan_id" "uuid", "p_new_name" "text", "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_announcement"("p_title" "text", "p_content" "text", "p_summary" "text", "p_cover_image_url" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_pinned" boolean, "p_priority" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_announcement"("p_title" "text", "p_content" "text", "p_summary" "text", "p_cover_image_url" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_pinned" boolean, "p_priority" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_announcement"("p_title" "text", "p_content" "text", "p_summary" "text", "p_cover_image_url" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_pinned" boolean, "p_priority" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_bug_report"("p_title" "text", "p_description" "text", "p_device_info" "jsonb", "p_app_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_bug_report"("p_title" "text", "p_description" "text", "p_device_info" "jsonb", "p_app_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_bug_report"("p_title" "text", "p_description" "text", "p_device_info" "jsonb", "p_app_version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_survey"("p_title" "text", "p_content" "text", "p_summary" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_questions" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."create_survey"("p_title" "text", "p_content" "text", "p_summary" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_questions" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_survey"("p_title" "text", "p_content" "text", "p_summary" "text", "p_target_scope" "public"."target_scope", "p_target_branches" "uuid"[], "p_target_regions" "uuid"[], "p_managers_only" boolean, "p_include_region_managers" boolean, "p_expires_at" timestamp with time zone, "p_questions" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_visual_audit_plan"("p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."create_visual_audit_plan"("p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_visual_audit_plan"("p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_visual_audit_section"("p_name" "text", "p_description" "text", "p_icon" "text", "p_color" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_visual_audit_section"("p_name" "text", "p_description" "text", "p_icon" "text", "p_color" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_visual_audit_section"("p_name" "text", "p_description" "text", "p_icon" "text", "p_color" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_visual_audit_task"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_note" "text", "p_scheduled_date" "date", "p_scheduled_hour" integer, "p_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."create_visual_audit_task"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_note" "text", "p_scheduled_date" "date", "p_scheduled_hour" integer, "p_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_visual_audit_task"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_note" "text", "p_scheduled_date" "date", "p_scheduled_hour" integer, "p_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_visual_audit_task_with_plan"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."create_visual_audit_task_with_plan"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_visual_audit_task_with_plan"("p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_start_date" "date", "p_end_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_visual_audit_template"("p_name" "text", "p_section_ids" "uuid"[], "p_scheduled_times" "text"[], "p_description" "text", "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_monthly_days" integer[], "p_deadline_minutes" integer, "p_min_photos" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_visual_audit_template"("p_name" "text", "p_section_ids" "uuid"[], "p_scheduled_times" "text"[], "p_description" "text", "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_monthly_days" integer[], "p_deadline_minutes" integer, "p_min_photos" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_visual_audit_template"("p_name" "text", "p_section_ids" "uuid"[], "p_scheduled_times" "text"[], "p_description" "text", "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_monthly_days" integer[], "p_deadline_minutes" integer, "p_min_photos" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."current_tenant_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_tenant_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_tenant_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_ctx"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_ctx"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_ctx"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "service_role";
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "supabase_auth_admin";



GRANT ALL ON FUNCTION "public"."delete_visual_audit_plan"("p_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_visual_audit_plan"("p_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_visual_audit_plan"("p_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_visual_audit_tasks"("p_task_ids" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."delete_visual_audit_tasks"("p_task_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_visual_audit_tasks"("p_task_ids" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_visual_audit_template"("p_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_visual_audit_template"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_visual_audit_template"("p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."depot_set_branch_name"() TO "anon";
GRANT ALL ON FUNCTION "public"."depot_set_branch_name"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."depot_set_branch_name"() TO "service_role";



GRANT ALL ON FUNCTION "public"."depot_touch_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."depot_touch_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."depot_touch_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."dispatch_skt_alarm_notifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."dispatch_skt_alarm_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."dispatch_skt_alarm_notifications"() TO "service_role";



GRANT ALL ON TABLE "public"."break_sessions" TO "anon";
GRANT ALL ON TABLE "public"."break_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."break_sessions" TO "service_role";



GRANT ALL ON FUNCTION "public"."end_break_session"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."end_break_session"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."end_break_session"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."execute_visual_audit_plan"("p_plan_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."execute_visual_audit_plan"("p_plan_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."execute_visual_audit_plan"("p_plan_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_tasks_for_template"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_tasks_for_template"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_tasks_for_template"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks_for_date"("p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks_for_date"("p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks_for_date"("p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks_for_templates"("p_template_ids" "uuid"[], "p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks_for_templates"("p_template_ids" "uuid"[], "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_visual_audit_tasks_for_templates"("p_template_ids" "uuid"[], "p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_personnel"("p_branch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_personnel"("p_branch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_personnel"("p_branch_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_bug_reports"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_bug_reports"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_bug_reports"("p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_current_user_profile"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_current_user_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_current_user_profile"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_depot_notice_offer_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_depot_notice_offer_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_depot_notice_offer_counts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_announcements"("p_type" "text", "p_include_expired" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_announcements"("p_type" "text", "p_include_expired" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_announcements"("p_type" "text", "p_include_expired" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_branch_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_branch_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_branch_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_managed_branch_ids"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_managed_branch_ids"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_managed_branch_ids"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_visual_audit_tasks"("p_date" "date", "p_status" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_visual_audit_tasks"("p_date" "date", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_visual_audit_tasks"("p_date" "date", "p_status" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_survey_results"("p_announcement_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_survey_results"("p_announcement_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_survey_results"("p_announcement_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tenant_branches"("p_tenant_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_tenant_branches"("p_tenant_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tenant_branches"("p_tenant_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tenant_regions"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_tenant_regions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tenant_regions"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unread_notification_count"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_unread_notification_count"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unread_notification_count"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_bug_notifications"("p_unread_only" boolean, "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_bug_notifications"("p_unread_only" boolean, "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_bug_notifications"("p_unread_only" boolean, "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_modules"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_modules"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_modules"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_comments"("p_task_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_comments"("p_task_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_comments"("p_task_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_plans"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_plans"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_plans"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_sections"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_sections"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_sections"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_stats"("p_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_stats"("p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_stats"("p_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_task_photos"("p_task_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_task_photos"("p_task_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_task_photos"("p_task_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_tasks"("p_date" "date", "p_status" "text", "p_branch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_tasks"("p_date" "date", "p_status" "text", "p_branch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_tasks"("p_date" "date", "p_status" "text", "p_branch_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_tasks_for_manager"("p_date" "date", "p_branch_id" "uuid", "p_section_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_tasks_for_manager"("p_date" "date", "p_branch_id" "uuid", "p_section_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_tasks_for_manager"("p_date" "date", "p_branch_id" "uuid", "p_section_id" "uuid", "p_status" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_template_detail"("p_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_template_detail"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_template_detail"("p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_for_manager"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_for_manager"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_for_manager"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_list"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_list"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_visual_audit_templates_list"() TO "service_role";



GRANT ALL ON FUNCTION "public"."grand_admin_list_tenants"() TO "anon";
GRANT ALL ON FUNCTION "public"."grand_admin_list_tenants"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."grand_admin_list_tenants"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_offer_cancellation"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_offer_cancellation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_offer_cancellation"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_service_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_service_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_service_role"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_edge_functions"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_edge_functions"() TO "anon";
GRANT ALL ON FUNCTION "public"."list_edge_functions"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_edge_functions"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_rls_policies"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_rls_policies"() TO "anon";
GRANT ALL ON FUNCTION "public"."list_rls_policies"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_rls_policies"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_all_bug_notifications_read"() TO "anon";
GRANT ALL ON FUNCTION "public"."mark_all_bug_notifications_read"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_all_bug_notifications_read"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_all_notifications_read"() TO "anon";
GRANT ALL ON FUNCTION "public"."mark_all_notifications_read"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_all_notifications_read"() TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_bug_notification_read"("p_notification_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_bug_notification_read"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_bug_notification_read"("p_notification_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_notification_read"("p_notification_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_announcement_published"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_announcement_published"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_announcement_published"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_bug_report_status_change"("p_report_id" "uuid", "p_new_status" "text", "p_admin_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."notify_bug_report_status_change"("p_report_id" "uuid", "p_new_status" "text", "p_admin_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_bug_report_status_change"("p_report_id" "uuid", "p_new_status" "text", "p_admin_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_visual_audit_comment_added"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_comment_added"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_comment_added"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_visual_audit_completed"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_completed"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_completed"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_visual_audit_photo_uploaded"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_photo_uploaded"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_photo_uploaded"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_visual_audit_task_completed"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_task_completed"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_task_completed"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_visual_audit_task_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_task_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_visual_audit_task_created"() TO "service_role";



GRANT ALL ON FUNCTION "public"."region_manager_create_personnel"("p_branch_id" "uuid", "p_employee_code" "text", "p_password" "text", "p_first_name" "text", "p_last_name" "text", "p_role" "public"."user_role", "p_email" "text", "p_phone" "text", "p_position" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."region_manager_create_personnel"("p_branch_id" "uuid", "p_employee_code" "text", "p_password" "text", "p_first_name" "text", "p_last_name" "text", "p_role" "public"."user_role", "p_email" "text", "p_phone" "text", "p_position" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."region_manager_create_personnel"("p_branch_id" "uuid", "p_employee_code" "text", "p_password" "text", "p_first_name" "text", "p_last_name" "text", "p_role" "public"."user_role", "p_email" "text", "p_phone" "text", "p_position" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."region_manager_get_branch_personnel"("p_branch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."region_manager_get_branch_personnel"("p_branch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."region_manager_get_branch_personnel"("p_branch_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."region_manager_remove_personnel"("p_personnel_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."region_manager_remove_personnel"("p_personnel_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."region_manager_remove_personnel"("p_personnel_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."region_manager_update_personnel_role"("p_personnel_id" "uuid", "p_role" "public"."user_role") TO "anon";
GRANT ALL ON FUNCTION "public"."region_manager_update_personnel_role"("p_personnel_id" "uuid", "p_role" "public"."user_role") TO "authenticated";
GRANT ALL ON FUNCTION "public"."region_manager_update_personnel_role"("p_personnel_id" "uuid", "p_role" "public"."user_role") TO "service_role";



GRANT ALL ON FUNCTION "public"."register_device_token"("p_user_id" "uuid", "p_tenant_id" "uuid", "p_token" "text", "p_platform" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."register_device_token"("p_user_id" "uuid", "p_tenant_id" "uuid", "p_token" "text", "p_platform" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_device_token"("p_user_id" "uuid", "p_tenant_id" "uuid", "p_token" "text", "p_platform" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_bug_report_message"("p_report_id" "uuid", "p_message" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."send_bug_report_message"("p_report_id" "uuid", "p_message" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_bug_report_message"("p_report_id" "uuid", "p_message" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_notification"("p_tenant_id" "uuid", "p_user_ids" "uuid"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_roles" "text"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_roles" "text"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_roles" "text"[], "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "text", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."send_notification_to_branch"("p_tenant_id" "uuid", "p_branch_id" "uuid", "p_type" "public"."notification_type", "p_title" "text", "p_body" "text", "p_data" "jsonb", "p_roles" "text"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_break_session_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_break_session_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_break_session_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."start_break_session"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_break_session"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_break_session"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."submit_survey_response"("p_announcement_id" "uuid", "p_answers" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_survey_response"("p_announcement_id" "uuid", "p_answers" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."submit_survey_response"("p_announcement_id" "uuid", "p_answers" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_generate_tasks_on_template_create"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_generate_tasks_on_template_create"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_generate_tasks_on_template_create"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_set_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_bug_report"("p_report_id" "uuid", "p_status" "text", "p_priority" "text", "p_admin_notes" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_bug_report"("p_report_id" "uuid", "p_status" "text", "p_priority" "text", "p_admin_notes" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_bug_report"("p_report_id" "uuid", "p_status" "text", "p_priority" "text", "p_admin_notes" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_task_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_task_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_task_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_visual_audit_plan"("p_plan_id" "uuid", "p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_end_date" "date", "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_visual_audit_plan"("p_plan_id" "uuid", "p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_end_date" "date", "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_visual_audit_plan"("p_plan_id" "uuid", "p_name" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_scheduled_hour" integer, "p_deadline_minutes" integer, "p_min_photos" integer, "p_notes" "text", "p_recurrence" "text", "p_recurrence_days" integer[], "p_end_date" "date", "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_visual_audit_template"("p_id" "uuid", "p_name" "text", "p_description" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_scheduled_times" "text"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_is_active" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."update_visual_audit_template"("p_id" "uuid", "p_name" "text", "p_description" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_scheduled_times" "text"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_is_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_visual_audit_template"("p_id" "uuid", "p_name" "text", "p_description" "text", "p_section_ids" "uuid"[], "p_branch_ids" "uuid"[], "p_recurrence" "public"."visual_audit_recurrence", "p_weekly_days" integer[], "p_scheduled_times" "text"[], "p_deadline_minutes" integer, "p_min_photos" integer, "p_is_active" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_visual_audit_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_visual_audit_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_visual_audit_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upload_visual_audit_photo"("p_task_id" "uuid", "p_photo_url" "text", "p_caption" "text", "p_thumbnail_url" "text", "p_latitude" double precision, "p_longitude" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."upload_visual_audit_photo"("p_task_id" "uuid", "p_photo_url" "text", "p_caption" "text", "p_thumbnail_url" "text", "p_latitude" double precision, "p_longitude" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upload_visual_audit_photo"("p_task_id" "uuid", "p_photo_url" "text", "p_caption" "text", "p_thumbnail_url" "text", "p_latitude" double precision, "p_longitude" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_products_alt_barcodes"() TO "anon";
GRANT ALL ON FUNCTION "public"."validate_products_alt_barcodes"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_products_alt_barcodes"() TO "service_role";
























GRANT ALL ON TABLE "public"."announcement_reads" TO "anon";
GRANT ALL ON TABLE "public"."announcement_reads" TO "authenticated";
GRANT ALL ON TABLE "public"."announcement_reads" TO "service_role";



GRANT ALL ON TABLE "public"."announcements" TO "anon";
GRANT ALL ON TABLE "public"."announcements" TO "authenticated";
GRANT ALL ON TABLE "public"."announcements" TO "service_role";



GRANT ALL ON TABLE "public"."attendance" TO "anon";
GRANT ALL ON TABLE "public"."attendance" TO "authenticated";
GRANT ALL ON TABLE "public"."attendance" TO "service_role";



GRANT ALL ON TABLE "public"."branch_requests" TO "anon";
GRANT ALL ON TABLE "public"."branch_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."branch_requests" TO "service_role";



GRANT ALL ON TABLE "public"."branch_scores" TO "anon";
GRANT ALL ON TABLE "public"."branch_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."branch_scores" TO "service_role";



GRANT ALL ON TABLE "public"."branches" TO "anon";
GRANT ALL ON TABLE "public"."branches" TO "authenticated";
GRANT ALL ON TABLE "public"."branches" TO "service_role";



GRANT ALL ON TABLE "public"."break_logs" TO "anon";
GRANT ALL ON TABLE "public"."break_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."break_logs" TO "service_role";



GRANT ALL ON TABLE "public"."bug_report_notifications" TO "anon";
GRANT ALL ON TABLE "public"."bug_report_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."bug_report_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."bug_reports" TO "anon";
GRANT ALL ON TABLE "public"."bug_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."bug_reports" TO "service_role";



GRANT ALL ON TABLE "public"."depot_notice_offers" TO "anon";
GRANT ALL ON TABLE "public"."depot_notice_offers" TO "authenticated";
GRANT ALL ON TABLE "public"."depot_notice_offers" TO "service_role";



GRANT ALL ON TABLE "public"."depot_notices" TO "anon";
GRANT ALL ON TABLE "public"."depot_notices" TO "authenticated";
GRANT ALL ON TABLE "public"."depot_notices" TO "service_role";



GRANT ALL ON TABLE "public"."device_tokens" TO "anon";
GRANT ALL ON TABLE "public"."device_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."device_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."employee_scores" TO "anon";
GRANT ALL ON TABLE "public"."employee_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."employee_scores" TO "service_role";



GRANT ALL ON TABLE "public"."form_submissions" TO "anon";
GRANT ALL ON TABLE "public"."form_submissions" TO "authenticated";
GRANT ALL ON TABLE "public"."form_submissions" TO "service_role";



GRANT ALL ON TABLE "public"."form_templates" TO "anon";
GRANT ALL ON TABLE "public"."form_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."form_templates" TO "service_role";



GRANT ALL ON TABLE "public"."health_reports" TO "anon";
GRANT ALL ON TABLE "public"."health_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."health_reports" TO "service_role";



GRANT ALL ON TABLE "public"."leave_requests" TO "anon";
GRANT ALL ON TABLE "public"."leave_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."leave_requests" TO "service_role";



GRANT ALL ON TABLE "public"."malfunction_reports" TO "anon";
GRANT ALL ON TABLE "public"."malfunction_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."malfunction_reports" TO "service_role";



GRANT ALL ON TABLE "public"."merch_people" TO "anon";
GRANT ALL ON TABLE "public"."merch_people" TO "authenticated";
GRANT ALL ON TABLE "public"."merch_people" TO "service_role";



GRANT ALL ON TABLE "public"."modules" TO "anon";
GRANT ALL ON TABLE "public"."modules" TO "authenticated";
GRANT ALL ON TABLE "public"."modules" TO "service_role";



GRANT ALL ON TABLE "public"."notification_queue" TO "anon";
GRANT ALL ON TABLE "public"."notification_queue" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_queue" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."payrolls" TO "anon";
GRANT ALL ON TABLE "public"."payrolls" TO "authenticated";
GRANT ALL ON TABLE "public"."payrolls" TO "service_role";



GRANT ALL ON TABLE "public"."product_issues" TO "anon";
GRANT ALL ON TABLE "public"."product_issues" TO "authenticated";
GRANT ALL ON TABLE "public"."product_issues" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."regions" TO "anon";
GRANT ALL ON TABLE "public"."regions" TO "authenticated";
GRANT ALL ON TABLE "public"."regions" TO "service_role";



GRANT ALL ON TABLE "public"."shift_pattern_drafts" TO "anon";
GRANT ALL ON TABLE "public"."shift_pattern_drafts" TO "authenticated";
GRANT ALL ON TABLE "public"."shift_pattern_drafts" TO "service_role";



GRANT ALL ON TABLE "public"."shifts" TO "anon";
GRANT ALL ON TABLE "public"."shifts" TO "authenticated";
GRANT ALL ON TABLE "public"."shifts" TO "service_role";



GRANT ALL ON TABLE "public"."skt_alarm_notifications" TO "anon";
GRANT ALL ON TABLE "public"."skt_alarm_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."skt_alarm_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."skt_records" TO "anon";
GRANT ALL ON TABLE "public"."skt_records" TO "authenticated";
GRANT ALL ON TABLE "public"."skt_records" TO "service_role";



GRANT ALL ON TABLE "public"."stockout_items" TO "anon";
GRANT ALL ON TABLE "public"."stockout_items" TO "authenticated";
GRANT ALL ON TABLE "public"."stockout_items" TO "service_role";



GRANT ALL ON TABLE "public"."stockout_lists" TO "anon";
GRANT ALL ON TABLE "public"."stockout_lists" TO "authenticated";
GRANT ALL ON TABLE "public"."stockout_lists" TO "service_role";



GRANT ALL ON TABLE "public"."store_scoring_form_versions" TO "anon";
GRANT ALL ON TABLE "public"."store_scoring_form_versions" TO "authenticated";
GRANT ALL ON TABLE "public"."store_scoring_form_versions" TO "service_role";



GRANT ALL ON TABLE "public"."store_scoring_forms" TO "anon";
GRANT ALL ON TABLE "public"."store_scoring_forms" TO "authenticated";
GRANT ALL ON TABLE "public"."store_scoring_forms" TO "service_role";



GRANT ALL ON TABLE "public"."store_scoring_items" TO "anon";
GRANT ALL ON TABLE "public"."store_scoring_items" TO "authenticated";
GRANT ALL ON TABLE "public"."store_scoring_items" TO "service_role";



GRANT ALL ON TABLE "public"."store_scoring_sections" TO "anon";
GRANT ALL ON TABLE "public"."store_scoring_sections" TO "authenticated";
GRANT ALL ON TABLE "public"."store_scoring_sections" TO "service_role";



GRANT ALL ON TABLE "public"."store_scoring_session_items" TO "anon";
GRANT ALL ON TABLE "public"."store_scoring_session_items" TO "authenticated";
GRANT ALL ON TABLE "public"."store_scoring_session_items" TO "service_role";



GRANT ALL ON TABLE "public"."store_scoring_sessions" TO "anon";
GRANT ALL ON TABLE "public"."store_scoring_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."store_scoring_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."survey_answers" TO "anon";
GRANT ALL ON TABLE "public"."survey_answers" TO "authenticated";
GRANT ALL ON TABLE "public"."survey_answers" TO "service_role";



GRANT ALL ON TABLE "public"."survey_questions" TO "anon";
GRANT ALL ON TABLE "public"."survey_questions" TO "authenticated";
GRANT ALL ON TABLE "public"."survey_questions" TO "service_role";



GRANT ALL ON TABLE "public"."survey_responses" TO "anon";
GRANT ALL ON TABLE "public"."survey_responses" TO "authenticated";
GRANT ALL ON TABLE "public"."survey_responses" TO "service_role";



GRANT ALL ON TABLE "public"."task_assignees" TO "anon";
GRANT ALL ON TABLE "public"."task_assignees" TO "authenticated";
GRANT ALL ON TABLE "public"."task_assignees" TO "service_role";



GRANT ALL ON TABLE "public"."task_attachments" TO "anon";
GRANT ALL ON TABLE "public"."task_attachments" TO "authenticated";
GRANT ALL ON TABLE "public"."task_attachments" TO "service_role";



GRANT ALL ON TABLE "public"."task_items" TO "anon";
GRANT ALL ON TABLE "public"."task_items" TO "authenticated";
GRANT ALL ON TABLE "public"."task_items" TO "service_role";



GRANT ALL ON TABLE "public"."tasks" TO "anon";
GRANT ALL ON TABLE "public"."tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."tasks" TO "service_role";



GRANT ALL ON TABLE "public"."tenant_modules" TO "anon";
GRANT ALL ON TABLE "public"."tenant_modules" TO "authenticated";
GRANT ALL ON TABLE "public"."tenant_modules" TO "service_role";



GRANT ALL ON TABLE "public"."tenants" TO "anon";
GRANT ALL ON TABLE "public"."tenants" TO "authenticated";
GRANT ALL ON TABLE "public"."tenants" TO "service_role";



GRANT ALL ON TABLE "public"."todos" TO "anon";
GRANT ALL ON TABLE "public"."todos" TO "authenticated";
GRANT ALL ON TABLE "public"."todos" TO "service_role";



GRANT ALL ON TABLE "public"."user_module_preferences" TO "anon";
GRANT ALL ON TABLE "public"."user_module_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."user_module_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."v_active_skt_alarms" TO "anon";
GRANT ALL ON TABLE "public"."v_active_skt_alarms" TO "authenticated";
GRANT ALL ON TABLE "public"."v_active_skt_alarms" TO "service_role";



GRANT ALL ON TABLE "public"."v_pending_leave_requests" TO "anon";
GRANT ALL ON TABLE "public"."v_pending_leave_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."v_pending_leave_requests" TO "service_role";



GRANT ALL ON TABLE "public"."v_store_scoring_published_forms" TO "anon";
GRANT ALL ON TABLE "public"."v_store_scoring_published_forms" TO "authenticated";
GRANT ALL ON TABLE "public"."v_store_scoring_published_forms" TO "service_role";



GRANT ALL ON TABLE "public"."v_survey_statistics" TO "anon";
GRANT ALL ON TABLE "public"."v_survey_statistics" TO "authenticated";
GRANT ALL ON TABLE "public"."v_survey_statistics" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_comments" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_comments" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_photos" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_photos" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_photos" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_sections" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_sections" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_sections" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_task_plans" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_task_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_task_plans" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_tasks" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_tasks" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_template_branches" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_template_branches" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_template_branches" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_template_sections" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_template_sections" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_template_sections" TO "service_role";



GRANT ALL ON TABLE "public"."visual_audit_templates" TO "anon";
GRANT ALL ON TABLE "public"."visual_audit_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."visual_audit_templates" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































