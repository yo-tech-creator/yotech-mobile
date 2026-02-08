-- Migration: Fix all active -> is_active column mismatches in functions
-- Date: 2026-02-02
-- Description: Updates all functions that still reference old 'active' column to use 'is_active'
-- Note: Functions with changed return types must be dropped first

-- =====================================================
-- DROP FUNCTIONS WITH CHANGED RETURN TYPES
-- =====================================================
DROP FUNCTION IF EXISTS public.get_all_tenants();
DROP FUNCTION IF EXISTS public.get_user_email_by_sicil(text);
DROP FUNCTION IF EXISTS public.grand_admin_list_tenants();
DROP FUNCTION IF EXISTS public.region_manager_get_branch_personnel(uuid);

-- =====================================================
-- 1. FIX: add_personel function (active -> is_active in INSERT)
-- =====================================================
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
    'Mağaza Personeli',
    CURRENT_DATE,
    TRUE
  );

  RETURN jsonb_build_object('success', TRUE, 'user_id', v_user_id, 'email', v_email);

EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- =====================================================
-- 2. FIX: create_visual_audit_plan function
-- =====================================================
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
        RETURN json_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
    END IF;
    
    IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'En az bir bölüm seçmelisiniz');
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

-- =====================================================
-- 3. FIX: create_visual_audit_template function
-- =====================================================
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
    RAISE EXCEPTION 'En az bir bölüm seçmelisiniz';
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

-- =====================================================
-- 4. FIX: generate_visual_audit_tasks_for_date function
-- =====================================================
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

-- =====================================================
-- 5. FIX: generate_visual_audit_tasks_for_templates function
-- =====================================================
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

-- =====================================================
-- 6. FIX: get_all_tenants function (RETURN TABLE + query)
-- =====================================================
CREATE OR REPLACE FUNCTION "public"."get_all_tenants"() RETURNS TABLE("id" "uuid", "code" "text", "name" "text", "is_active" boolean, "total_users" bigint, "active_modules" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF current_user_role() != 'grand_admin' THEN
    RAISE EXCEPTION 'Bu fonksiyonu sadece Grand Admin çağırabilir';
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

-- =====================================================
-- 7. FIX: get_my_announcements function
-- =====================================================
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

-- =====================================================
-- 8. FIX: get_tenant_modules function
-- =====================================================
CREATE OR REPLACE FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") RETURNS TABLE("module_code" "text", "module_name" "text", "module_icon" "text", "module_description" "text", "is_core" boolean, "is_enabled" boolean, "enabled_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF current_user_role() != 'grand_admin' AND current_tenant_id() != p_tenant_id THEN
    RAISE EXCEPTION 'Bu firmaya erişim yetkiniz yok';
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

-- =====================================================
-- 9. FIX: get_user_email_by_sicil function
-- =====================================================
CREATE OR REPLACE FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") RETURNS TABLE("email" "text", "is_active" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT email::TEXT, is_active FROM users WHERE employee_code = p_sicil_no LIMIT 1;
$$;

-- =====================================================
-- 10. FIX: get_user_modules function
-- =====================================================
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

-- =====================================================
-- 11. FIX: grand_admin_list_tenants function
-- =====================================================
CREATE OR REPLACE FUNCTION "public"."grand_admin_list_tenants"() RETURNS TABLE("id" "uuid", "name" "text", "code" "text", "is_active" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select id, name, code, is_active
  from public.tenants
  where is_active = true
  order by name;
$$;

-- =====================================================
-- 12. FIX: region_manager_create_personnel function
-- =====================================================
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
    RAISE EXCEPTION 'Kimlik doğrulaması gerekiyor';
  END IF;

  -- FIX: is_active instead of active
  SELECT b.id, b.tenant_id, b.region_id
    INTO v_branch
  FROM public.branches b
  WHERE b.id = p_branch_id AND b.is_active;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Şube bulunamadı veya aktif değil';
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_branch.region_id
    AND r.tenant_id = v_branch.tenant_id
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu şube üzerinde yetkiniz yok';
  END IF;

  IF p_role NOT IN ('personel', 'sube_muduru') THEN
    RAISE EXCEPTION 'Geçersiz rol: %', p_role;
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
    RAISE EXCEPTION 'Bu personel kodu zaten kullanılıyor';
  END IF;

  v_password := NULLIF(TRIM(p_password), '');
  IF v_password IS NULL OR LENGTH(v_password) < 6 THEN
    RAISE EXCEPTION 'Şifre en az 6 karakter olmalı';
  END IF;

  v_custom_email := NULLIF(TRIM(p_email), '');
  IF v_custom_email IS NOT NULL THEN
    PERFORM 1
      FROM auth.users au
     WHERE LOWER(au.email) = LOWER(v_custom_email)
     LIMIT 1;
    IF FOUND THEN
      RAISE EXCEPTION 'Bu e-posta adresi zaten kayıtlı';
    END IF;
  END IF;

  v_result := public.add_personel(v_employee_code, v_password, v_branch.tenant_id);

  IF COALESCE((v_result->>'success')::boolean, FALSE) IS FALSE THEN
    RAISE EXCEPTION 'Personel oluşturulamadı: %', v_result->>'error';
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

-- =====================================================
-- 13. FIX: region_manager_get_branch_personnel function
-- =====================================================
CREATE OR REPLACE FUNCTION "public"."region_manager_get_branch_personnel"("p_branch_id" "uuid") RETURNS TABLE("member_id" "uuid", "first_name" "text", "last_name" "text", "email" "text", "phone" "text", "employee_code" "text", "role" "public"."user_role", "position" "text", "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_branch RECORD;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik doğrulaması gerekiyor';
  END IF;

  SELECT b.id, b.tenant_id, b.region_id
    INTO v_branch
  FROM public.branches b
  WHERE b.id = p_branch_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Şube bulunamadı';
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_branch.region_id
    AND r.tenant_id = v_branch.tenant_id
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu şube üzerinde yetkiniz yok';
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

-- =====================================================
-- 14. FIX: region_manager_remove_personnel function
-- =====================================================
CREATE OR REPLACE FUNCTION "public"."region_manager_remove_personnel"("p_personnel_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_target RECORD;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik doğrulaması gerekiyor';
  END IF;

  SELECT u.*, b.region_id, b.tenant_id AS branch_tenant
    INTO v_target
  FROM public.users u
  LEFT JOIN public.branches b ON b.id = u.branch_id
  WHERE u.id = p_personnel_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Personel bulunamadı';
  END IF;

  IF v_target.branch_id IS NULL THEN
    RAISE NOTICE 'Personel zaten şubeye bağlı değil';
    RETURN;
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_target.region_id
    AND r.tenant_id = v_target.branch_tenant
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu personel üzerinde yetkiniz yok';
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

-- =====================================================
-- 15. FIX: trigger_generate_tasks_on_template_create function
-- =====================================================
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

-- =====================================================
-- 16. FIX: create_announcement function (active -> is_active)
-- =====================================================
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
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  
  IF v_user_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Duyuru oluşturma yetkiniz yok');
  END IF;
  
  IF v_user_role = 'sube_muduru' AND p_target_scope NOT IN ('my_branch') THEN
    p_target_scope := 'my_branch';
  END IF;
  
  IF v_user_role = 'bolge_muduru' AND p_target_scope = 'region_managers_only' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu hedef kitleyi seçme yetkiniz yok');
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

-- =====================================================
-- 17. FIX: create_survey function (active -> is_active)
-- =====================================================
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
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  
  IF v_user_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Anket oluşturma yetkiniz yok');
  END IF;
  
  IF v_user_role = 'sube_muduru' AND p_target_scope NOT IN ('my_branch') THEN
    p_target_scope := 'my_branch';
  END IF;
  
  IF v_user_role = 'bolge_muduru' AND p_target_scope = 'region_managers_only' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Bu hedef kitleyi seçme yetkiniz yok');
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

-- =====================================================
-- END OF MIGRATION
-- =====================================================
-- Summary of fixes:
-- 1. add_personel: active -> is_active in INSERT
-- 2. create_visual_audit_plan: b.active -> b.is_active
-- 3. create_visual_audit_template: active -> is_active
-- 4. generate_visual_audit_tasks_for_date: b.active -> b.is_active
-- 5. generate_visual_audit_tasks_for_templates: b.active -> b.is_active
-- 6. get_all_tenants: RETURN TABLE and query active -> is_active
-- 7. get_my_announcements: a.active -> a.is_active
-- 8. get_tenant_modules: m.active -> m.is_active
-- 9. get_user_email_by_sicil: active -> is_active
-- 10. get_user_modules: m.active -> m.is_active
-- 11. grand_admin_list_tenants: t.active -> t.is_active
-- 12. region_manager_create_personnel: b.active, active -> is_active
-- 13. region_manager_get_branch_personnel: active -> is_active
-- 14. region_manager_remove_personnel: active -> is_active
-- 15. trigger_generate_tasks_on_template_create: b.active -> b.is_active
-- 16. create_announcement: active -> is_active
-- 17. create_survey: active -> is_active