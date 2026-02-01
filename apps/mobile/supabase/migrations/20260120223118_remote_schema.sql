


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






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






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
    'not_applicable'
);


ALTER TYPE "public"."store_scoring_item_result" OWNER TO "postgres";


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
    active
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


ALTER FUNCTION "public"."add_personel"("p_employee_code" "text", "p_password" "text", "p_tenant_id" "uuid") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
  select nullif(current_setting('request.jwt.claim.tenant_id', true), '')::uuid;
$$;


ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";


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
  -- 1 gün kala uyarıları
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
          'body', format('%s ürünü için SKT yaklaşıyor.', rec.product_name)
        )
      );
    end loop;

    update skt_records
      set alarm_warn_sent = true, alarm_warn_sent_at = now()
      where id = rec.record_id;
  end loop;

  -- Günü gelen uyarılar
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
          'body', format('%s ürünü bugün son kullanma tarihinde.', rec.product_name)
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
    RAISE EXCEPTION 'Aktif mola bulunamadı';
  END IF;

  UPDATE break_sessions
  SET ended_at = now()
  WHERE id = v_session.id
  RETURNING * INTO v_session;

  RETURN v_session;
END;
$$;


ALTER FUNCTION "public"."end_break_session"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_all_tenants"() RETURNS TABLE("id" "uuid", "code" "text", "name" "text", "active" boolean, "total_users" bigint, "active_modules" bigint)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Sadece grand admin çağırabilir
  IF current_user_role() != 'grand_admin' THEN
    RAISE EXCEPTION 'Bu fonksiyonu sadece Grand Admin çağırabilir';
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.code,
    t.name,
    t.active,
    COUNT(DISTINCT u.id) as total_users,
    COUNT(DISTINCT tm.module_code) FILTER (WHERE tm.is_enabled = true) as active_modules
  FROM tenants t
  LEFT JOIN users u ON u.tenant_id = t.id AND u.active = true
  LEFT JOIN tenant_modules tm ON tm.tenant_id = t.id
  WHERE t.code != 'SYSTEM' -- Sistem tenant'ını gösterme
  GROUP BY t.id, t.code, t.name, t.active
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
BEGIN
  SELECT * INTO v_mgr FROM users WHERE id = p_user_id;

  IF v_mgr.id IS NULL THEN
    RAISE EXCEPTION 'Kullanıcı bulunamadı';
  END IF;

  IF v_mgr.role = 'bolge_muduru'::user_role THEN
    RETURN QUERY
      SELECT bs.*
      FROM break_sessions bs
      JOIN branches b ON b.id = bs.branch_id
      WHERE b.region_id = v_mgr.region_id
        AND bs.tenant_id = v_mgr.tenant_id
      ORDER BY bs.started_at DESC;
  ELSIF v_mgr.role = 'sube_muduru'::user_role THEN
    RETURN QUERY
      SELECT bs.*
      FROM break_sessions bs
      WHERE bs.branch_id = v_mgr.branch_id
        AND bs.tenant_id = v_mgr.tenant_id
      ORDER BY bs.started_at DESC;
  ELSE
    RETURN QUERY
      SELECT * FROM break_sessions WHERE user_id = v_mgr.id;
  END IF;
END;
$$;


ALTER FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") OWNER TO "postgres";


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
    RAISE EXCEPTION 'Kimlik doğrulaması gerekiyor';
  END IF;

  SELECT u.branch_id, u.tenant_id
    INTO v_branch, v_tenant
  FROM users u
  WHERE u.id = p_user_id;

  IF v_branch IS NULL THEN
    RAISE EXCEPTION 'Bu kullanıcı herhangi bir şubeye bağlı değil';
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
      RAISE EXCEPTION 'Bu takım bilgisine erişim yetkiniz yok';
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


CREATE OR REPLACE FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") RETURNS TABLE("id" "uuid", "first_name" "text", "last_name" "text", "email" "text", "phone" "text", "position" "text", "role" "public"."user_role", "employee_code" "text", "hire_date" "date", "tenant_id" "uuid", "tenant_name" "text", "branch_id" "uuid", "branch_name" "text", "branch_code" "text", "branch_city" "text", "branch_district" "text", "branch_manager_id" "uuid", "branch_manager_first_name" "text", "branch_manager_last_name" "text", "branch_manager_phone" "text", "region_id" "uuid", "region_name" "text", "regional_manager_id" "uuid", "regional_manager_first_name" "text", "regional_manager_last_name" "text", "regional_manager_phone" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_requester uuid := auth.uid();
  v_target_tenant uuid;
BEGIN
  IF v_requester IS NULL THEN
    RAISE EXCEPTION 'Kimlik doğrulaması gerekiyor';
  END IF;

  SELECT u.tenant_id INTO v_target_tenant FROM users u WHERE u.id = p_user_id;
  IF v_target_tenant IS NULL THEN
    RAISE EXCEPTION 'Kullanıcı bulunamadı';
  END IF;

  -- Kendisi dışındaki profillere erişmek için ilgili tenant içinde
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
      RAISE EXCEPTION 'Bu profile erişim yetkiniz yok';
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


CREATE OR REPLACE FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") RETURNS TABLE("module_code" "text", "module_name" "text", "module_icon" "text", "module_description" "text", "is_core" boolean, "is_enabled" boolean, "enabled_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  -- Grand admin veya aynı tenant'taki kullanıcı çağırabilir
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
  WHERE m.active = true
  ORDER BY m.display_order;
END;
$$;


ALTER FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") RETURNS TABLE("email" "text", "active" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT email::TEXT, active FROM users WHERE employee_code = p_sicil_no LIMIT 1;
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
  WHERE m.active = true AND tm.is_enabled = true
  ORDER BY COALESCE(ump.display_order, m.display_order);
END;
$$;


ALTER FUNCTION "public"."get_user_modules"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grand_admin_list_tenants"() RETURNS TABLE("id" "uuid", "name" "text", "code" "text", "active" boolean)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select id, name, code, active
  from public.tenants
  where active = true
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

  SELECT b.id, b.tenant_id, b.region_id
    INTO v_branch
  FROM public.branches b
  WHERE b.id = p_branch_id AND b.active;

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

  UPDATE public.users
  SET first_name = v_first_name,
      last_name = v_last_name,
      email = v_final_email,
      phone = NULLIF(TRIM(p_phone), ''),
      "position" = NULLIF(TRIM(p_position), ''),
      branch_id = p_branch_id,
      role = p_role,
      active = TRUE,
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


CREATE OR REPLACE FUNCTION "public"."region_manager_get_branch_personnel"("p_branch_id" "uuid") RETURNS TABLE("member_id" "uuid", "first_name" "text", "last_name" "text", "email" "text", "phone" "text", "employee_code" "text", "role" "public"."user_role", "position" "text", "active" boolean)
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
    u.active
  FROM public.users u
  WHERE u.branch_id = p_branch_id
    AND u.tenant_id = v_branch.tenant_id
    AND u.active
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

  UPDATE public.users
  SET branch_id = NULL,
      active = FALSE,
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
    RAISE EXCEPTION 'Personel herhangi bir şubeye bağlı değil';
  END IF;

  IF p_role NOT IN ('personel', 'sube_muduru') THEN
    RAISE EXCEPTION 'Geçersiz rol: %', p_role;
  END IF;

  PERFORM 1
  FROM public.regions r
  WHERE r.id = v_target.region_id
    AND r.tenant_id = v_target.branch_tenant
    AND r.manager_id = v_requester;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bu personel üzerinde yetkiniz yok';
  END IF;

  UPDATE public.users
  SET role = p_role,
      updated_at = NOW()
  WHERE id = v_target.id;
END;
$$;


ALTER FUNCTION "public"."region_manager_update_personnel_role"("p_personnel_id" "uuid", "p_role" "public"."user_role") OWNER TO "postgres";


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
    RETURN jsonb_build_object('success', false, 'error', 'Kullanıcı bulunamadı');
  END IF;
  
  -- Şifreyi hash'le (bcrypt benzeri basit yöntem)
  v_hashed_password := crypt(p_new_password, gen_salt('bf'));
  
  -- Auth tablosunda güncelle
  UPDATE auth.users
  SET 
    encrypted_password = v_hashed_password,
    updated_at = NOW()
  WHERE id = v_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Şifre güncellendi'
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
        'Mağaza dış alanı; otopark temizliği ve düzeni, cam, sticker ve doğrama temizliği',
        'Mağazadan dış alana açılan kapı ve pencerelerde haşere–kemirgen girişini engelleyecek önlemlerin kontrolü',
        'Mağaza sıfır ürün sayısı (mağaza kaynaklı sıfır sayısı 10 adet üzeri ise puan verilmez)',
        'Müşteri arabası ve müşteri sepeti temizlik ve konumlandırma',
        'Kasa bölgesi standartları (etiket, poşet, optik okuyucular, kasa üstü teşhir)',
        'Macao dolap kırmızı çizgi, doluluk, etiket ve temizlik'
      )
    ),
    jsonb_build_object(
      'title', 'MANAV',
      'items', jsonb_build_array(
        'Manav bölümü doluluk ve RYS',
        'Manav bölümü tazelik ve bileşeleme (kalite standart temellendirilmeli)',
        'Manav bölümü eksik etiket ve künye',
        'Manav bölümü AHT etiket, doluluk, kırmızı çizgi ve temizlik',
        'Manav bölümü soğuk dolap (+4) temizlik, doluluk ve etiket',
        'Manav hazırlık odası ve soğuk oda temizlik, düzen ve kalite temelli kontrol (sıcaklık ve temizlik formu, tanımlı kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'UNLU',
      'items', jsonb_build_array(
        'Unlu servis/distriyel ekmek doluluk & RYS & SKT/RKS',
        'Unlu servis bölümü ekipman, doluluk ve RYS',
        'Unlu servis bölümü izlenebilirlik',
        'Unlu servis bölümü çözündürme, pişirme adetler ve üretim standardı kontrolü (fazla pişme, çiğ kalma, hamurlaşma)',
        'Unlu bölüm AHT etiket, doluluk, kırmızı çizgi ve temizlik',
        'Unlu hazırlık odası ve soğuk oda temizlik, düzen ve kalite temelli kontrol (sıcaklık ve temizlik formu, tanımlı kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'KASAP / ŞARKÜTERİ',
      'items', jsonb_build_array(
        'Kasap şarküteri bölümü tazelik, doluluk ve RYS',
        'Kasap şarküteri bölümü izlenebilirlik',
        'Kasap şarküteri bölümü kıyma mak. standart kullanım',
        'Kasap şarküteri bölümü SKT/RKS (elleçleme / 10 adet ürün)',
        'Kasap şarküteri bölümü AHT etiket, doluluk, kırmızı çizgi ve temizlik',
        'Kasap ve şarküteri hazırlık odası ve soğuk oda temizlik, düzen ve kalite temelli kontrol (sıcaklık ve temizlik formu, tanımlı kimyasallar)'
      )
    ),
    jsonb_build_object(
      'title', 'GENEL (DEVAM)',
      'items', jsonb_build_array(
        'İptal kartın muhafaza ve yönetiliş şekli & gider pusulası muhafaza ve yönetiliş şekli',
        'Personel dış görünüş, iş kıyafeti, yaka kartı ve kişisel hijyen',
        'Bölümlerde personel bulunurluğu',
        'Teşhir sepet sayısı, doluluğu, etiketleri ve konumlandırılması',
        'İçecek dolap FIFO, doluluk ve etiket',
        'Mağaza genel koli açılışları (perfora), ön yüz ve doluluk',
        'Genel depo düzen / mal kabul / karton kafes / sigara içme alanı yönetimi',
        'Atık, iade ve karantina alan standartları',
        'Sosyal alan standartları (mutfak, soyunma dolap, WC ve mescit)',
        'Mağaza genel SKT/RKS (elleçleme 10 ürün)',
        'Mağaza palet altı, raf ve reyon temizlik',
        'Bir önceki mağaza ziyareti tespit / aksiyon',
        'Haftalık ve aylık bülten uygulamaları',
        'Müşteri gözüyle mağaza kontrol formu'
      )
    )
  );
BEGIN
  IF p_tenant_id IS NULL OR p_admin_id IS NULL THEN
    RAISE EXCEPTION 'tenant ve admin kullanıcı kimliği zorunludur';
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
    'Mağaza Genel Denetim Formu',
    'Varsayılan mağaza kalite ve operasyon kontrol listesi',
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
    RAISE EXCEPTION 'Kullanıcı bulunamadı';
  END IF;

  SELECT * INTO v_active
  FROM break_sessions
  WHERE user_id = v_user.id AND ended_at IS NULL
  LIMIT 1;

  IF v_active.id IS NOT NULL THEN
    RETURN v_active; -- zaten açık, aynısını döndür
  END IF;

  INSERT INTO break_sessions (tenant_id, branch_id, user_id)
  VALUES (v_user.tenant_id, v_user.branch_id, v_user.id)
  RETURNING * INTO v_active;

  RETURN v_active;
END;
$$;


ALTER FUNCTION "public"."start_break_session"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_is_core BOOLEAN;
BEGIN
  -- Sadece grand admin çağırabilir
  IF current_user_role() != 'grand_admin' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Bu işlem için Grand Admin yetkisi gerekli'
    );
  END IF;
  
  -- Core modül mü kontrol et
  SELECT is_core INTO v_is_core FROM modules WHERE code = p_module_code;
  
  IF v_is_core AND NOT p_is_enabled THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Temel modüller kapatılamaz'
    );
  END IF;
  
  -- Modül kaydını ekle veya güncelle
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

  -- trim + boş değer kontrolü
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
    raise exception 'Alt barkod listesinde tekrar eden değerler var';
  end if;

  foreach alt_code in array new.alt_barcodes loop
    -- ana barkodla aynı olamaz
    if alt_code = new.barcode then
      raise exception 'Alt barkod ana barkod ile aynı olamaz (%).', alt_code;
    end if;

    -- aynı tenant’ta başka ürünlerin alt/ana barkodlarıyla çakışma kontrolü
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
      raise exception 'Alt barkod başka bir ürünle çakışıyor (%).', alt_code;
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
    "target_roles" "public"."user_role"[],
    "published_by" "uuid" NOT NULL,
    "published_at" timestamp with time zone DEFAULT "now"(),
    "expires_at" timestamp with time zone,
    "active" boolean DEFAULT true
);


ALTER TABLE "public"."announcements" OWNER TO "postgres";


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
    "active" boolean DEFAULT true,
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
    "active" boolean DEFAULT true,
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
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."modules" OWNER TO "postgres";


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
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


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
    "active" boolean DEFAULT true,
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
    "active" boolean DEFAULT true,
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
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."store_scoring_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."task_assignees" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "task_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "assigned_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."task_assignees" OWNER TO "postgres";


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
    "sort_order" integer DEFAULT 0
);


ALTER TABLE "public"."tasks" OWNER TO "postgres";


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
    "active" boolean DEFAULT true,
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
    "active" boolean DEFAULT true,
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



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_task_id_user_id_key" UNIQUE ("task_id", "user_id");



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



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_tenant_id_employee_code_key" UNIQUE ("tenant_id", "employee_code");



CREATE INDEX "break_sessions_branch_started_idx" ON "public"."break_sessions" USING "btree" ("branch_id", "started_at" DESC);



CREATE INDEX "break_sessions_user_open_idx" ON "public"."break_sessions" USING "btree" ("user_id") WHERE ("ended_at" IS NULL);



CREATE INDEX "depot_notice_offers_notice_idx" ON "public"."depot_notice_offers" USING "btree" ("notice_id", "status");



CREATE UNIQUE INDEX "depot_notice_offers_unique_pending" ON "public"."depot_notice_offers" USING "btree" ("notice_id", "branch_id") WHERE ("status" = 'pending'::"public"."depot_offer_status");



CREATE INDEX "depot_notices_tenant_branch_idx" ON "public"."depot_notices" USING "btree" ("tenant_id", "branch_id", "status");



CREATE INDEX "device_tokens_token_idx" ON "public"."device_tokens" USING "btree" ("token");



CREATE INDEX "device_tokens_user_idx" ON "public"."device_tokens" USING "btree" ("user_id");



CREATE INDEX "idx_announcement_reads_user_id" ON "public"."announcement_reads" USING "btree" ("user_id");



CREATE INDEX "idx_announcements_published" ON "public"."announcements" USING "btree" ("published_at");



CREATE INDEX "idx_announcements_published_by" ON "public"."announcements" USING "btree" ("published_by");



CREATE INDEX "idx_announcements_tenant" ON "public"."announcements" USING "btree" ("tenant_id");



CREATE INDEX "idx_attendance_branch_id" ON "public"."attendance" USING "btree" ("branch_id");



CREATE INDEX "idx_attendance_date" ON "public"."attendance" USING "btree" ("check_in_time");



CREATE INDEX "idx_attendance_tenant_branch" ON "public"."attendance" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_attendance_user" ON "public"."attendance" USING "btree" ("user_id");



CREATE INDEX "idx_branch_requests_branch" ON "public"."branch_requests" USING "btree" ("branch_id");



CREATE INDEX "idx_branch_requests_category" ON "public"."branch_requests" USING "btree" ("category");



CREATE INDEX "idx_branch_requests_created_by" ON "public"."branch_requests" USING "btree" ("created_by");



CREATE INDEX "idx_branch_requests_status" ON "public"."branch_requests" USING "btree" ("status");



CREATE INDEX "idx_branch_score_tenant_branch" ON "public"."branch_scores" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_branch_scores_branch_id" ON "public"."branch_scores" USING "btree" ("branch_id");



CREATE INDEX "idx_branch_scores_evaluated_by" ON "public"."branch_scores" USING "btree" ("evaluated_by");



CREATE INDEX "idx_branches_region" ON "public"."branches" USING "btree" ("region_id");



CREATE INDEX "idx_branches_tenant" ON "public"."branches" USING "btree" ("tenant_id");



CREATE INDEX "idx_break_logs_branch_id" ON "public"."break_logs" USING "btree" ("branch_id");



CREATE INDEX "idx_break_tenant_branch" ON "public"."break_logs" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_break_user" ON "public"."break_logs" USING "btree" ("user_id");



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



CREATE INDEX "idx_notifications_created" ON "public"."notifications" USING "btree" ("created_at");



CREATE INDEX "idx_notifications_read" ON "public"."notifications" USING "btree" ("is_read");



CREATE INDEX "idx_notifications_tenant_user" ON "public"."notifications" USING "btree" ("tenant_id", "user_id");



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



CREATE INDEX "idx_skt_expiry_date" ON "public"."skt_records" USING "btree" ("expiry_date");



CREATE INDEX "idx_skt_product" ON "public"."skt_records" USING "btree" ("product_id");



CREATE INDEX "idx_skt_records_branch_id" ON "public"."skt_records" USING "btree" ("branch_id");



CREATE INDEX "idx_skt_records_user_id" ON "public"."skt_records" USING "btree" ("user_id");



CREATE INDEX "idx_skt_status" ON "public"."skt_records" USING "btree" ("status");



CREATE INDEX "idx_skt_tenant_branch" ON "public"."skt_records" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_stockout_items_list" ON "public"."stockout_items" USING "btree" ("stockout_list_id");



CREATE INDEX "idx_stockout_items_product_id" ON "public"."stockout_items" USING "btree" ("product_id");



CREATE INDEX "idx_stockout_lists_branch_id" ON "public"."stockout_lists" USING "btree" ("branch_id");



CREATE INDEX "idx_stockout_lists_created_by" ON "public"."stockout_lists" USING "btree" ("created_by");



CREATE INDEX "idx_stockout_lists_tenant_branch" ON "public"."stockout_lists" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_task_assignees_user" ON "public"."task_assignees" USING "btree" ("user_id");



CREATE INDEX "idx_task_items_completed_by" ON "public"."task_items" USING "btree" ("completed_by");



CREATE INDEX "idx_task_items_task_id" ON "public"."task_items" USING "btree" ("task_id");



CREATE INDEX "idx_tasks_branch_id" ON "public"."tasks" USING "btree" ("branch_id");



CREATE INDEX "idx_tasks_created_by" ON "public"."tasks" USING "btree" ("created_by");



CREATE INDEX "idx_tasks_due_date" ON "public"."tasks" USING "btree" ("due_date");



CREATE INDEX "idx_tasks_parent_sort" ON "public"."tasks" USING "btree" ("parent_task_id", "sort_order");



CREATE INDEX "idx_tasks_parent_task" ON "public"."tasks" USING "btree" ("parent_task_id");



CREATE INDEX "idx_tasks_status" ON "public"."tasks" USING "btree" ("status");



CREATE INDEX "idx_tasks_tenant_branch" ON "public"."tasks" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_todos_owner_id" ON "public"."todos" USING "btree" ("owner_id");



CREATE INDEX "idx_todos_parent_id" ON "public"."todos" USING "btree" ("parent_id");



CREATE INDEX "idx_todos_tenant" ON "public"."todos" USING "btree" ("tenant_id");



CREATE INDEX "idx_users_branch" ON "public"."users" USING "btree" ("branch_id");



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_role" ON "public"."users" USING "btree" ("role");



CREATE INDEX "idx_users_tenant" ON "public"."users" USING "btree" ("tenant_id");



CREATE INDEX "skt_records_deleted_at_idx" ON "public"."skt_records" USING "btree" ("deleted_at") WHERE ("deleted_at" IS NOT NULL);



CREATE INDEX "store_scoring_form_versions_form_idx" ON "public"."store_scoring_form_versions" USING "btree" ("form_id");



CREATE INDEX "store_scoring_forms_tenant_idx" ON "public"."store_scoring_forms" USING "btree" ("tenant_id");



CREATE INDEX "store_scoring_items_section_idx" ON "public"."store_scoring_items" USING "btree" ("section_id");



CREATE INDEX "store_scoring_sections_version_idx" ON "public"."store_scoring_sections" USING "btree" ("form_version_id");



CREATE INDEX "store_scoring_session_items_session_idx" ON "public"."store_scoring_session_items" USING "btree" ("session_id");



CREATE INDEX "store_scoring_sessions_branch_idx" ON "public"."store_scoring_sessions" USING "btree" ("branch_id");



CREATE INDEX "store_scoring_sessions_evaluator_idx" ON "public"."store_scoring_sessions" USING "btree" ("evaluator_id");



CREATE OR REPLACE TRIGGER "attendance_minutes_calculation" BEFORE UPDATE ON "public"."attendance" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_attendance_minutes"();



CREATE OR REPLACE TRIGGER "break_duration_calculation" BEFORE UPDATE ON "public"."break_logs" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_break_duration"();



CREATE OR REPLACE TRIGGER "depot_notice_offers_after_update" AFTER UPDATE ON "public"."depot_notice_offers" FOR EACH ROW EXECUTE FUNCTION "public"."handle_offer_cancellation"();



CREATE OR REPLACE TRIGGER "depot_notice_offers_branch_name" BEFORE INSERT OR UPDATE ON "public"."depot_notice_offers" FOR EACH ROW EXECUTE FUNCTION "public"."depot_set_branch_name"();



CREATE OR REPLACE TRIGGER "depot_notice_offers_set_updated_at" BEFORE UPDATE ON "public"."depot_notice_offers" FOR EACH ROW EXECUTE FUNCTION "public"."depot_touch_updated_at"();



CREATE OR REPLACE TRIGGER "depot_notices_branch_name" BEFORE INSERT OR UPDATE ON "public"."depot_notices" FOR EACH ROW EXECUTE FUNCTION "public"."depot_set_branch_name"();



CREATE OR REPLACE TRIGGER "depot_notices_set_updated_at" BEFORE UPDATE ON "public"."depot_notices" FOR EACH ROW EXECUTE FUNCTION "public"."depot_touch_updated_at"();



CREATE OR REPLACE TRIGGER "skt_alarm_calculation" BEFORE INSERT OR UPDATE ON "public"."skt_records" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_skt_alarm_date"();



CREATE OR REPLACE TRIGGER "task_item_completion_update" AFTER INSERT OR DELETE OR UPDATE ON "public"."task_items" FOR EACH ROW EXECUTE FUNCTION "public"."update_task_completion"();



CREATE OR REPLACE TRIGGER "trg_branch_requests_updated_at" BEFORE UPDATE ON "public"."branch_requests" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trg_break_sessions_updated_at" BEFORE UPDATE ON "public"."break_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."set_break_session_updated_at"();



CREATE OR REPLACE TRIGGER "trg_products_alt_barcodes" BEFORE INSERT OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."validate_products_alt_barcodes"();



CREATE OR REPLACE TRIGGER "update_branches_updated_at" BEFORE UPDATE ON "public"."branches" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_products_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_regions_updated_at" BEFORE UPDATE ON "public"."regions" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_skt_records_updated_at" BEFORE UPDATE ON "public"."skt_records" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_tenants_updated_at" BEFORE UPDATE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



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
    ADD CONSTRAINT "store_scoring_sessions_evaluator_id_fkey" FOREIGN KEY ("evaluator_id") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."store_scoring_sessions"
    ADD CONSTRAINT "store_scoring_sessions_form_version_id_fkey" FOREIGN KEY ("form_version_id") REFERENCES "public"."store_scoring_form_versions"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_assignees"
    ADD CONSTRAINT "task_assignees_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_completed_by_fkey" FOREIGN KEY ("completed_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."task_items"
    ADD CONSTRAINT "task_items_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_parent_task_id_fkey" FOREIGN KEY ("parent_task_id") REFERENCES "public"."tasks"("id") ON DELETE CASCADE;



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



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



CREATE POLICY "Branch managers can view their branch submissions" ON "public"."form_submissions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."branch_id" = "u"."branch_id") AND ("u"."role" = 'sube_muduru'::"public"."user_role")))));



CREATE POLICY "Tenant admin can view all submissions" ON "public"."form_submissions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."role" = 'firma_admin'::"public"."user_role")))));



CREATE POLICY "Users can view their own submissions" ON "public"."form_submissions" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "alarm_notifications_service" ON "public"."skt_alarm_notifications" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "alarm_notifications_user_select" ON "public"."skt_alarm_notifications" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "alarm_notifications_user_update" ON "public"."skt_alarm_notifications" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."announcement_reads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attendance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."branch_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "branch_requests_insert" ON "public"."branch_requests" FOR INSERT WITH CHECK ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "branch_requests"."tenant_id") AND (("u"."role" = 'grand_admin'::"public"."user_role") OR ("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "branch_requests"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "branch_requests"."branch_id")) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."branch_id" = "branch_requests"."branch_id") AND ("u"."id" = "branch_requests"."created_by"))))))));



CREATE POLICY "branch_requests_select" ON "public"."branch_requests" FOR SELECT USING ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "branch_requests"."tenant_id") AND (("u"."role" = 'grand_admin'::"public"."user_role") OR ("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "branch_requests"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "branch_requests"."branch_id")) OR (("u"."role" = 'personel'::"public"."user_role") AND (("u"."id" = "branch_requests"."created_by") OR ("u"."branch_id" = "branch_requests"."branch_id")))))))));



CREATE POLICY "branch_requests_update" ON "public"."branch_requests" FOR UPDATE USING ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "branch_requests"."tenant_id") AND (("u"."role" = 'grand_admin'::"public"."user_role") OR ("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "branch_requests"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "branch_requests"."branch_id")) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "branch_requests"."created_by")))))))) WITH CHECK ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "branch_requests"."tenant_id") AND (("u"."role" = 'grand_admin'::"public"."user_role") OR ("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "branch_requests"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "branch_requests"."branch_id")) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "branch_requests"."created_by"))))))));



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


CREATE POLICY "form versions select" ON "public"."store_scoring_form_versions" FOR SELECT TO "authenticated" USING ((("auth"."role"() = 'service_role'::"text") OR ("public"."current_user_role"() = 'grand_admin'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."store_scoring_forms" "f"
  WHERE (("f"."id" = "store_scoring_form_versions"."form_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))));



CREATE POLICY "form versions select by user tenant" ON "public"."store_scoring_form_versions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."store_scoring_forms" "f"
     JOIN "public"."users" "u" ON (("u"."id" = "auth"."uid"())))
  WHERE (("f"."id" = "store_scoring_form_versions"."form_id") AND ("f"."tenant_id" = "u"."tenant_id")))));



ALTER TABLE "public"."form_submissions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_submissions_all" ON "public"."form_submissions" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "form_submissions"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("u"."branch_id" = "form_submissions"."branch_id") OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "form_submissions"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id")))))) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "form_submissions"."user_id")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "form_submissions"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "form_submissions"."branch_id")) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "form_submissions"."user_id"))))))))));



ALTER TABLE "public"."form_templates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "form_templates_all" ON "public"."form_templates" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "form_templates"."tenant_id") AND ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'sube_muduru'::"public"."user_role"]))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "form_templates"."tenant_id") AND ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'sube_muduru'::"public"."user_role"])))))))));



CREATE POLICY "forms select" ON "public"."store_scoring_forms" FOR SELECT TO "authenticated" USING ((("auth"."role"() = 'service_role'::"text") OR ("public"."current_user_role"() = 'grand_admin'::"text") OR ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "forms select by user tenant" ON "public"."store_scoring_forms" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "store_scoring_forms"."tenant_id")))));



ALTER TABLE "public"."health_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_reports_all" ON "public"."health_reports" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "health_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("u"."branch_id" = "health_reports"."branch_id") OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "health_reports"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id")))))) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "health_reports"."user_id")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "health_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR ("u"."role" = 'sube_muduru'::"public"."user_role") OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "health_reports"."user_id"))))))))));



CREATE POLICY "items select" ON "public"."store_scoring_items" FOR SELECT TO "authenticated" USING ((("auth"."role"() = 'service_role'::"text") OR ("public"."current_user_role"() = 'grand_admin'::"text") OR (EXISTS ( SELECT 1
   FROM (("public"."store_scoring_sections" "s"
     JOIN "public"."store_scoring_form_versions" "fv" ON (("fv"."id" = "s"."form_version_id")))
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
  WHERE (("s"."id" = "store_scoring_items"."section_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))));



CREATE POLICY "items select by user tenant" ON "public"."store_scoring_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ((("public"."store_scoring_sections" "s"
     JOIN "public"."store_scoring_form_versions" "fv" ON (("fv"."id" = "s"."form_version_id")))
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
     JOIN "public"."users" "u" ON (("u"."id" = "auth"."uid"())))
  WHERE (("s"."id" = "store_scoring_items"."section_id") AND ("f"."tenant_id" = "u"."tenant_id")))));



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
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND (("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) OR ("ctx"."id" = "merch_people"."created_by"))))))));



CREATE POLICY "merch_people_insert" ON "public"."merch_people" FOR INSERT WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"]))))))));



CREATE POLICY "merch_people_select" ON "public"."merch_people" FOR SELECT USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND ("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"]))))))));



CREATE POLICY "merch_people_update" ON "public"."merch_people" FOR UPDATE USING (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND (("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) OR ("ctx"."id" = "merch_people"."created_by")))))))) WITH CHECK (("public"."is_service_role"() OR (EXISTS ( SELECT 1
   FROM "public"."current_user_ctx"() "ctx"("id", "tenant_id", "role", "branch_id")
  WHERE (("ctx"."role" = 'grand_admin'::"public"."user_role") OR (("ctx"."tenant_id" = "merch_people"."tenant_id") AND (("ctx"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) OR ("ctx"."id" = "merch_people"."created_by"))))))));



ALTER TABLE "public"."modules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "modules_select" ON "public"."modules" FOR SELECT USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'authenticated'::"text") OR (COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'anon'::"text")));



ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notifications_all" ON "public"."notifications" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "notifications"."tenant_id") AND (("u"."id" = "notifications"."user_id") OR ("u"."role" = ANY (ARRAY['firma_admin'::"public"."user_role", 'bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "notifications"."tenant_id") AND ("u"."id" = "notifications"."user_id"))))))));



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



CREATE POLICY "scoring_session_items_manage" ON "public"."store_scoring_session_items" USING ((EXISTS ( SELECT 1
   FROM "public"."store_scoring_sessions" "s"
  WHERE (("s"."id" = "store_scoring_session_items"."session_id") AND (("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))) AND (("s"."branch_id" = ( SELECT "users"."branch_id"
           FROM "public"."users"
          WHERE ("users"."id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "s"."branch_id") AND ("r"."manager_id" = "auth"."uid"()) AND ("r"."tenant_id" = "public"."current_tenant_id"())))))) OR (("auth"."role"() = 'sube_muduru'::"text") AND ("s"."evaluator_id" = "auth"."uid"()) AND ("s"."branch_id" = ( SELECT "users"."branch_id"
           FROM "public"."users"
          WHERE ("users"."id" = "auth"."uid"()))) AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'personel'::"text") AND ("s"."evaluator_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."store_scoring_sessions" "s"
  WHERE (("s"."id" = "store_scoring_session_items"."session_id") AND (("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))) AND (("s"."branch_id" = ( SELECT "users"."branch_id"
           FROM "public"."users"
          WHERE ("users"."id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "s"."branch_id") AND ("r"."manager_id" = "auth"."uid"()) AND ("r"."tenant_id" = "public"."current_tenant_id"())))))) OR (("auth"."role"() = 'sube_muduru'::"text") AND ("s"."evaluator_id" = "auth"."uid"()) AND ("s"."branch_id" = ( SELECT "users"."branch_id"
           FROM "public"."users"
          WHERE ("users"."id" = "auth"."uid"()))) AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'personel'::"text") AND ("s"."evaluator_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
           FROM ("public"."store_scoring_form_versions" "v"
             JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
          WHERE (("v"."id" = "s"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))))))));



CREATE POLICY "scoring_sessions_delete" ON "public"."store_scoring_sessions" FOR DELETE USING ((("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"])) AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR ("evaluator_id" = "auth"."uid"())));



CREATE POLICY "scoring_sessions_insert" ON "public"."store_scoring_sessions" FOR INSERT WITH CHECK ((("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))) AND (("branch_id" = ( SELECT "users"."branch_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."branches" "b"
     JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
  WHERE (("b"."id" = "store_scoring_sessions"."branch_id") AND ("r"."manager_id" = "auth"."uid"()) AND ("r"."tenant_id" = "public"."current_tenant_id"())))))) OR (("auth"."role"() = 'sube_muduru'::"text") AND ("evaluator_id" = "auth"."uid"()) AND ("branch_id" = ( SELECT "users"."branch_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))) AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'personel'::"text") AND ("evaluator_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))))));



CREATE POLICY "scoring_sessions_select" ON "public"."store_scoring_sessions" FOR SELECT USING ((("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = 'firma_admin'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'bolge_muduru'::"text") AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))) AND (("branch_id" = ( SELECT "users"."branch_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."branches" "b"
     JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
  WHERE (("b"."id" = "store_scoring_sessions"."branch_id") AND ("r"."manager_id" = "auth"."uid"()) AND ("r"."tenant_id" = "public"."current_tenant_id"())))))) OR (("auth"."role"() = 'sube_muduru'::"text") AND ("evaluator_id" = "auth"."uid"()) AND ("branch_id" = ( SELECT "users"."branch_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))) AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR (("auth"."role"() = 'personel'::"text") AND ("evaluator_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))))));



CREATE POLICY "scoring_sessions_update" ON "public"."store_scoring_sessions" FOR UPDATE USING ((("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"])) AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR ("evaluator_id" = "auth"."uid"()))) WITH CHECK ((("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"])) AND (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "v"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "v"."form_id")))
  WHERE (("v"."id" = "store_scoring_sessions"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))) OR ("evaluator_id" = "auth"."uid"())));



CREATE POLICY "sections select" ON "public"."store_scoring_sections" FOR SELECT TO "authenticated" USING ((("auth"."role"() = 'service_role'::"text") OR ("public"."current_user_role"() = 'grand_admin'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "fv"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
  WHERE (("fv"."id" = "store_scoring_sections"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))));



CREATE POLICY "sections select by user tenant" ON "public"."store_scoring_sections" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM (("public"."store_scoring_form_versions" "fv"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
     JOIN "public"."users" "u" ON (("u"."id" = "auth"."uid"())))
  WHERE (("fv"."id" = "store_scoring_sections"."form_version_id") AND ("f"."tenant_id" = "u"."tenant_id")))));



ALTER TABLE "public"."shift_pattern_drafts" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shift_pattern_drafts_owner_delete" ON "public"."shift_pattern_drafts" FOR DELETE TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "shift_pattern_drafts_owner_insert" ON "public"."shift_pattern_drafts" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "shift_pattern_drafts_owner_select" ON "public"."shift_pattern_drafts" FOR SELECT TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "shift_pattern_drafts_owner_update" ON "public"."shift_pattern_drafts" FOR UPDATE TO "authenticated" USING ((("user_id" = "auth"."uid"()) AND ("tenant_id" = "public"."current_tenant_id"()))) WITH CHECK ((("user_id" = "auth"."uid"()) AND ("tenant_id" = "public"."current_tenant_id"())));



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


CREATE POLICY "store_form_versions_select" ON "public"."store_scoring_form_versions" FOR SELECT USING ((("auth"."role"() = 'grand_admin'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."store_scoring_forms" "f"
  WHERE (("f"."id" = "store_scoring_form_versions"."form_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))));



CREATE POLICY "store_form_versions_write" ON "public"."store_scoring_form_versions" USING ((("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"])) AND (EXISTS ( SELECT 1
   FROM "public"."store_scoring_forms" "f"
  WHERE (("f"."id" = "store_scoring_form_versions"."form_id") AND ("f"."tenant_id" = "public"."current_tenant_id"()))))))) WITH CHECK ((("auth"."role"() = 'grand_admin'::"text") OR (("auth"."role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"])) AND (EXISTS ( SELECT 1
   FROM "public"."store_scoring_forms" "f"
  WHERE (("f"."id" = "store_scoring_form_versions"."form_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))))));



CREATE POLICY "store_forms_select" ON "public"."store_scoring_forms" FOR SELECT USING ((("auth"."role"() = 'grand_admin'::"text") OR ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "store_forms_write" ON "public"."store_scoring_forms" USING ((("auth"."role"() = 'grand_admin'::"text") OR (("tenant_id" = "public"."current_tenant_id"()) AND ("auth"."role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"]))))) WITH CHECK ((("auth"."role"() = 'grand_admin'::"text") OR (("tenant_id" = "public"."current_tenant_id"()) AND ("auth"."role"() = ANY (ARRAY['firma_admin'::"text", 'bolge_muduru'::"text"])))));



ALTER TABLE "public"."store_scoring_form_versions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_scoring_forms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_scoring_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_scoring_sections" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_scoring_session_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."store_scoring_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "submissions select" ON "public"."form_submissions" FOR SELECT TO "authenticated" USING ((("auth"."role"() = 'service_role'::"text") OR ("public"."current_user_role"() = 'grand_admin'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "form_submissions"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND ("u"."branch_id" = "form_submissions"."branch_id")) OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("u"."branch_id" = "form_submissions"."branch_id")) OR ("u"."id" = "form_submissions"."user_id")))))));



ALTER TABLE "public"."task_assignees" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "task_assignees_all" ON "public"."task_assignees" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."users" "u" ON (("u"."id" = ( SELECT "auth"."uid"() AS "uid"))))
  WHERE (("t"."id" = "task_assignees"."task_id") AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "t"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND (("t"."branch_id" = "u"."branch_id") OR ("task_assignees"."user_id" = "u"."id"))) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "t"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))))))))))) WITH CHECK (true);



ALTER TABLE "public"."task_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "task_items_all" ON "public"."task_items" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."tasks" "t"
     JOIN "public"."users" "u" ON (("u"."id" = ( SELECT "auth"."uid"() AS "uid"))))
  WHERE (("t"."id" = "task_items"."task_id") AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "t"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "t"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND (("t"."branch_id" = "u"."branch_id") OR (EXISTS ( SELECT 1
           FROM "public"."task_assignees" "ta"
          WHERE (("ta"."task_id" = "t"."id") AND ("ta"."user_id" = "u"."id")))))))))))))) WITH CHECK (true);



ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tasks_delete" ON "public"."tasks" FOR DELETE USING ((("auth"."role"() = 'service_role'::"text") OR (("created_by" = "auth"."uid"()) AND ("tenant_id" = COALESCE(((("current_setting"('request.jwt.claims'::"text", true))::json ->> 'tenant_id'::"text"))::"uuid", ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())))))));



CREATE POLICY "tasks_insert" ON "public"."tasks" FOR INSERT WITH CHECK ((("auth"."role"() = 'service_role'::"text") OR (("created_by" = "auth"."uid"()) AND ("tenant_id" = COALESCE(((("current_setting"('request.jwt.claims'::"text", true))::json ->> 'tenant_id'::"text"))::"uuid", ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())))))));



CREATE POLICY "tasks_select" ON "public"."tasks" FOR SELECT USING ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "tasks"."branch_id") AND ("b"."tenant_id" = "u"."tenant_id") AND ("r"."manager_id" = "u"."id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("tasks"."branch_id" = "u"."branch_id"))))))));



CREATE POLICY "tasks_update" ON "public"."tasks" FOR UPDATE USING ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("tasks"."branch_id" = "u"."branch_id")))))))) WITH CHECK ((("auth"."role"() = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = "auth"."uid"()) AND ("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = ANY (ARRAY['grand_admin'::"public"."user_role", 'firma_admin'::"public"."user_role"])) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("tasks"."branch_id" = "u"."branch_id"))))))));



CREATE POLICY "tenant form versions select" ON "public"."store_scoring_form_versions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."store_scoring_forms" "f"
  WHERE (("f"."id" = "store_scoring_form_versions"."form_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))));



CREATE POLICY "tenant forms select" ON "public"."store_scoring_forms" FOR SELECT TO "authenticated" USING (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "tenant scoring items select" ON "public"."store_scoring_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM (("public"."store_scoring_sections" "s"
     JOIN "public"."store_scoring_form_versions" "fv" ON (("fv"."id" = "s"."form_version_id")))
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
  WHERE (("s"."id" = "store_scoring_items"."section_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))));



CREATE POLICY "tenant scoring sections select" ON "public"."store_scoring_sections" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."store_scoring_form_versions" "fv"
     JOIN "public"."store_scoring_forms" "f" ON (("f"."id" = "fv"."form_id")))
  WHERE (("fv"."id" = "store_scoring_sections"."form_version_id") AND ("f"."tenant_id" = "public"."current_tenant_id"())))));



CREATE POLICY "tenant scoring session items manage" ON "public"."store_scoring_session_items" TO "authenticated" USING ("public"."session_belongs_to_current_tenant"("session_id")) WITH CHECK ("public"."session_belongs_to_current_tenant"("session_id"));



CREATE POLICY "tenant scoring sessions insert" ON "public"."store_scoring_sessions" FOR INSERT TO "authenticated" WITH CHECK ("public"."branch_belongs_to_current_tenant"("branch_id"));



CREATE POLICY "tenant scoring sessions select" ON "public"."store_scoring_sessions" FOR SELECT TO "authenticated" USING ("public"."branch_belongs_to_current_tenant"("branch_id"));



CREATE POLICY "tenant scoring sessions update" ON "public"."store_scoring_sessions" FOR UPDATE TO "authenticated" USING ("public"."branch_belongs_to_current_tenant"("branch_id")) WITH CHECK ("public"."branch_belongs_to_current_tenant"("branch_id"));



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


CREATE POLICY "tenants_select_all" ON "public"."tenants" FOR SELECT USING ((("auth"."role"() = 'grand_admin'::"text") OR ("id" = "public"."current_tenant_id"())));



ALTER TABLE "public"."todos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "todos_delete_self" ON "public"."todos" FOR DELETE USING ((("auth"."role"() = 'service_role'::"text") OR (("owner_id" = "auth"."uid"()) AND ("tenant_id" = COALESCE(((("current_setting"('request.jwt.claims'::"text", true))::json ->> 'tenant_id'::"text"))::"uuid", ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())))))));



CREATE POLICY "todos_insert_self" ON "public"."todos" FOR INSERT WITH CHECK ((("auth"."role"() = 'service_role'::"text") OR (("owner_id" = "auth"."uid"()) AND ("tenant_id" = COALESCE(((("current_setting"('request.jwt.claims'::"text", true))::json ->> 'tenant_id'::"text"))::"uuid", ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())))))));



CREATE POLICY "todos_select_self" ON "public"."todos" FOR SELECT USING ((("auth"."role"() = 'service_role'::"text") OR (("owner_id" = "auth"."uid"()) AND ("tenant_id" = COALESCE(((("current_setting"('request.jwt.claims'::"text", true))::json ->> 'tenant_id'::"text"))::"uuid", ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())))))));



CREATE POLICY "todos_update_self" ON "public"."todos" FOR UPDATE USING ((("auth"."role"() = 'service_role'::"text") OR (("owner_id" = "auth"."uid"()) AND ("tenant_id" = COALESCE(((("current_setting"('request.jwt.claims'::"text", true))::json ->> 'tenant_id'::"text"))::"uuid", ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"()))))))) WITH CHECK ((("auth"."role"() = 'service_role'::"text") OR (("owner_id" = "auth"."uid"()) AND ("tenant_id" = COALESCE(((("current_setting"('request.jwt.claims'::"text", true))::json ->> 'tenant_id'::"text"))::"uuid", ( SELECT "users"."tenant_id"
   FROM "public"."users"
  WHERE ("users"."id" = "auth"."uid"())))))));



ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_select_self" ON "public"."users" FOR SELECT USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (( SELECT "auth"."uid"() AS "uid") = "id")));





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
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "service_role";
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "supabase_auth_admin";



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



GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_branch_team_members"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_depot_notice_offer_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_depot_notice_offer_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_depot_notice_offer_counts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_personal_profile"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tenant_modules"("p_tenant_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_data_by_id"("p_user_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_email_by_sicil"("p_sicil_no" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_modules"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_modules"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_modules"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."grand_admin_list_tenants"() FROM PUBLIC;
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



GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."seed_default_store_scoring_form"("p_tenant_id" "uuid", "p_admin_id" "uuid", "p_form_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."session_belongs_to_current_tenant"("p_session_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_break_session_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_break_session_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_break_session_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."start_break_session"("p_user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."start_break_session"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_break_session"("p_user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."toggle_tenant_module"("p_tenant_id" "uuid", "p_module_code" "text", "p_is_enabled" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_task_completion"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_task_completion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_task_completion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_module_order"("p_module_code" "text", "p_display_order" integer) TO "service_role";



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



GRANT ALL ON TABLE "public"."task_assignees" TO "anon";
GRANT ALL ON TABLE "public"."task_assignees" TO "authenticated";
GRANT ALL ON TABLE "public"."task_assignees" TO "service_role";



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































drop extension if exists "pg_net";

create extension if not exists "pg_net" with schema "public";


  create policy "delete own request files"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'request-files'::text) AND (auth.role() = 'authenticated'::text) AND (owner = auth.uid())));



  create policy "insert personal request files"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'request-files'::text) AND (auth.role() = 'authenticated'::text) AND ((storage.foldername(name))[1] = (auth.jwt() ->> 'tenant_id'::text))));



  create policy "request-files delete own"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'request-files'::text) AND (owner = auth.uid())));



  create policy "request-files insert"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check (((bucket_id = 'request-files'::text) AND ((storage.foldername(name))[1] = 'malfunctions'::text) AND (cardinality(storage.foldername(name)) >= 3) AND (storage.filename(name) ~~ (auth.uid() || '_%'::text)) AND (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND ((u.tenant_id)::text = (storage.foldername(objects.name))[2]) AND ((u.branch_id)::text = (storage.foldername(objects.name))[3]))))));



  create policy "request-files select"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using (((bucket_id = 'request-files'::text) AND ((storage.foldername(name))[1] = 'malfunctions'::text) AND (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = auth.uid()) AND ((u.tenant_id)::text = (storage.foldername(objects.name))[2]) AND (((u.branch_id)::text = (storage.foldername(objects.name))[3]) OR (u.role = ANY (ARRAY['grand_admin'::public.user_role, 'firma_admin'::public.user_role, 'bolge_muduru'::public.user_role, 'sube_muduru'::public.user_role]))))))));



  create policy "select personal request files"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'request-files'::text) AND (auth.role() = 'authenticated'::text) AND ((storage.foldername(name))[1] = (auth.jwt() ->> 'tenant_id'::text))));


-- Storage triggers are managed by Supabase, skip if they exist
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'enforce_bucket_name_length_trigger') THEN
        CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'objects_delete_delete_prefix') THEN
        CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'objects_insert_create_prefix') THEN
        CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger();
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'objects_update_create_prefix') THEN
        CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (((new.name <> old.name) OR (new.bucket_id <> old.bucket_id))) EXECUTE FUNCTION storage.objects_update_prefix_trigger();
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_objects_updated_at') THEN
        CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'prefixes_create_hierarchy') THEN
        CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN ((pg_trigger_depth() < 1)) EXECUTE FUNCTION storage.prefixes_insert_trigger();
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'prefixes_delete_hierarchy') THEN
        CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();
    END IF;
END $$;


