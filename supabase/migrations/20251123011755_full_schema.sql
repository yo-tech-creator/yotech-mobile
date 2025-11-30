


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


CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "extensions";


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



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


CREATE TYPE "public"."product_issue_status" AS ENUM (
    'acik',
    'inceleniyor',
    'cozuldu',
    'kapandi'
);


ALTER TYPE "public"."product_issue_status" OWNER TO "postgres";


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
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  v_user_id UUID;
  v_email TEXT;
  v_phone TEXT;
BEGIN
  v_user_id := gen_random_uuid();
  v_email := LOWER(p_employee_code) || '@filemarket.com';
  v_phone := '5550000000';
  
  -- Auth kullanıcısı oluştur (basit şifreleme)
  INSERT INTO auth.users (
    instance_id, id, aud, role, email,
    encrypted_password,
    email_confirmed_at, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    v_email,
    '$2a$10$' || encode(digest(p_password || v_user_id::text, 'sha256'), 'base64'),
    NOW(), NOW(), NOW(),
    '', '', '', ''
  );
  
  -- Public users tablosuna ekle
  INSERT INTO public.users (
    id, tenant_id, first_name, last_name, email, phone,
    employee_code, role, position, hire_date, active
  ) VALUES (
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
    true
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'email', v_email
  );
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM
    );
END;
$_$;


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
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT COALESCE(
    (SELECT tenant_id FROM users WHERE id = auth.uid()),
    '00000000-0000-0000-0000-000000000000'::uuid
  );
$$;


ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_user_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT COALESCE(
    auth.uid(),
    '00000000-0000-0000-0000-000000000000'::uuid
  );
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

SET default_tablespace = '';

SET default_table_access_method = "heap";


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


CREATE TABLE IF NOT EXISTS "public"."inventory_transfers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "from_branch_id" "uuid" NOT NULL,
    "to_branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" integer NOT NULL,
    "status" "public"."transfer_status" DEFAULT 'hazirlaniyor'::"public"."transfer_status",
    "requested_by" "uuid" NOT NULL,
    "approved_by" "uuid",
    "shipped_at" timestamp with time zone,
    "delivered_at" timestamp with time zone,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventory_transfers" OWNER TO "postgres";


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
    "updated_at" timestamp with time zone DEFAULT "now"()
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


ALTER TABLE ONLY "public"."announcement_reads"
    ADD CONSTRAINT "announcement_reads_announcement_id_user_id_key" UNIQUE ("announcement_id", "user_id");



ALTER TABLE ONLY "public"."announcement_reads"
    ADD CONSTRAINT "announcement_reads_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."announcements"
    ADD CONSTRAINT "announcements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."inventory_transfers"
    ADD CONSTRAINT "inventory_transfers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."leave_requests"
    ADD CONSTRAINT "leave_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."malfunction_reports"
    ADD CONSTRAINT "malfunction_reports_pkey" PRIMARY KEY ("id");



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



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_tenant_id_employee_code_key" UNIQUE ("tenant_id", "employee_code");



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



CREATE INDEX "idx_inventory_transfers_approved_by" ON "public"."inventory_transfers" USING "btree" ("approved_by");



CREATE INDEX "idx_inventory_transfers_product_id" ON "public"."inventory_transfers" USING "btree" ("product_id");



CREATE INDEX "idx_inventory_transfers_requested_by" ON "public"."inventory_transfers" USING "btree" ("requested_by");



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



CREATE INDEX "idx_tasks_status" ON "public"."tasks" USING "btree" ("status");



CREATE INDEX "idx_tasks_tenant_branch" ON "public"."tasks" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_transfer_from_branch" ON "public"."inventory_transfers" USING "btree" ("from_branch_id");



CREATE INDEX "idx_transfer_status" ON "public"."inventory_transfers" USING "btree" ("status");



CREATE INDEX "idx_transfer_tenant" ON "public"."inventory_transfers" USING "btree" ("tenant_id");



CREATE INDEX "idx_transfer_to_branch" ON "public"."inventory_transfers" USING "btree" ("to_branch_id");



CREATE INDEX "idx_users_branch" ON "public"."users" USING "btree" ("branch_id");



CREATE INDEX "idx_users_email" ON "public"."users" USING "btree" ("email");



CREATE INDEX "idx_users_role" ON "public"."users" USING "btree" ("role");



CREATE INDEX "idx_users_tenant" ON "public"."users" USING "btree" ("tenant_id");



CREATE INDEX "skt_records_deleted_at_idx" ON "public"."skt_records" USING "btree" ("deleted_at") WHERE ("deleted_at" IS NOT NULL);



CREATE OR REPLACE TRIGGER "attendance_minutes_calculation" BEFORE UPDATE ON "public"."attendance" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_attendance_minutes"();



CREATE OR REPLACE TRIGGER "break_duration_calculation" BEFORE UPDATE ON "public"."break_logs" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_break_duration"();



CREATE OR REPLACE TRIGGER "skt_alarm_calculation" BEFORE INSERT OR UPDATE ON "public"."skt_records" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_skt_alarm_date"();



CREATE OR REPLACE TRIGGER "task_item_completion_update" AFTER INSERT OR DELETE OR UPDATE ON "public"."task_items" FOR EACH ROW EXECUTE FUNCTION "public"."update_task_completion"();



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



ALTER TABLE ONLY "public"."inventory_transfers"
    ADD CONSTRAINT "inventory_transfers_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."inventory_transfers"
    ADD CONSTRAINT "inventory_transfers_from_branch_id_fkey" FOREIGN KEY ("from_branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_transfers"
    ADD CONSTRAINT "inventory_transfers_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_transfers"
    ADD CONSTRAINT "inventory_transfers_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."inventory_transfers"
    ADD CONSTRAINT "inventory_transfers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_transfers"
    ADD CONSTRAINT "inventory_transfers_to_branch_id_fkey" FOREIGN KEY ("to_branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



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
    ADD CONSTRAINT "tasks_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_enabled_by_fkey" FOREIGN KEY ("enabled_by") REFERENCES "public"."users"("id");



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_module_code_fkey" FOREIGN KEY ("module_code") REFERENCES "public"."modules"("code") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."tenant_modules"
    ADD CONSTRAINT "tenant_modules_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



CREATE POLICY "alarm_notifications_service" ON "public"."skt_alarm_notifications" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "alarm_notifications_user_select" ON "public"."skt_alarm_notifications" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "alarm_notifications_user_update" ON "public"."skt_alarm_notifications" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."announcement_reads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."announcements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attendance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."branch_scores" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."branches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "branches_select" ON "public"."branches" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "branches"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM "public"."regions" "r"
          WHERE (("r"."id" = "branches"."region_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "branches"."tenant_id"))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND ("u"."branch_id" = "branches"."id"))))))))));



ALTER TABLE "public"."break_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."device_tokens" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "device_tokens_service_all" ON "public"."device_tokens" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "device_tokens_user_insert" ON "public"."device_tokens" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "device_tokens_user_select" ON "public"."device_tokens" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "device_tokens_user_update" ON "public"."device_tokens" FOR UPDATE TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."employee_scores" ENABLE ROW LEVEL SECURITY;


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



ALTER TABLE "public"."health_reports" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "health_reports_all" ON "public"."health_reports" USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "health_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = ANY (ARRAY['bolge_muduru'::"public"."user_role", 'sube_muduru'::"public"."user_role"])) AND (("u"."branch_id" = "health_reports"."branch_id") OR (EXISTS ( SELECT 1
           FROM ("public"."branches" "b"
             JOIN "public"."regions" "r" ON (("r"."id" = "b"."region_id")))
          WHERE (("b"."id" = "health_reports"."branch_id") AND ("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id")))))) OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "health_reports"."user_id")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "health_reports"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR ("u"."role" = 'sube_muduru'::"public"."user_role") OR (("u"."role" = 'personel'::"public"."user_role") AND ("u"."id" = "health_reports"."user_id"))))))))));



ALTER TABLE "public"."inventory_transfers" ENABLE ROW LEVEL SECURITY;


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


CREATE POLICY "tasks_insert" ON "public"."tasks" FOR INSERT WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("tasks"."branch_id" = "u"."branch_id"))))))))));



CREATE POLICY "tasks_select" ON "public"."tasks" FOR SELECT USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'bolge_muduru'::"public"."user_role") AND (EXISTS ( SELECT 1
           FROM "public"."regions" "r"
          WHERE (("r"."manager_id" = "u"."id") AND ("r"."tenant_id" = "u"."tenant_id") AND (("tasks"."branch_id" IS NULL) OR ("tasks"."branch_id" IN ( SELECT "b"."id"
                   FROM "public"."branches" "b"
                  WHERE ("b"."region_id" = "r"."id")))))))) OR (("u"."role" = ANY (ARRAY['sube_muduru'::"public"."user_role", 'personel'::"public"."user_role"])) AND (("tasks"."branch_id" = "u"."branch_id") OR (EXISTS ( SELECT 1
           FROM "public"."task_assignees" "ta"
          WHERE (("ta"."task_id" = "tasks"."id") AND ("ta"."user_id" = "u"."id"))))))))))))));



CREATE POLICY "tasks_update" ON "public"."tasks" FOR UPDATE USING (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("tasks"."branch_id" = "u"."branch_id")))))))))) WITH CHECK (((( SELECT "auth"."role"() AS "role") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR (("u"."tenant_id" = "tasks"."tenant_id") AND (("u"."role" = 'firma_admin'::"public"."user_role") OR (("u"."role" = 'sube_muduru'::"public"."user_role") AND ("tasks"."branch_id" = "u"."branch_id"))))))))));



ALTER TABLE "public"."tenant_modules" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tenant_modules_select" ON "public"."tenant_modules" FOR SELECT USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR ("u"."tenant_id" = "tenant_modules"."tenant_id")))))));



CREATE POLICY "tenant_modules_update" ON "public"."tenant_modules" FOR UPDATE USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR ("u"."tenant_id" = "tenant_modules"."tenant_id"))))))) WITH CHECK (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (EXISTS ( SELECT 1
   FROM "public"."users" "u"
  WHERE (("u"."id" = ( SELECT "auth"."uid"() AS "uid")) AND (("u"."role" = 'grand_admin'::"public"."user_role") OR ("u"."tenant_id" = "tenant_modules"."tenant_id")))))));



ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users_select_self" ON "public"."users" FOR SELECT USING (((COALESCE(( SELECT "auth"."role"() AS "role"), 'anon'::"text") = 'service_role'::"text") OR (( SELECT "auth"."uid"() AS "uid") = "id")));



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



GRANT ALL ON FUNCTION "public"."current_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."current_user_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_user_role"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "service_role";
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "supabase_auth_admin";



GRANT ALL ON FUNCTION "public"."dispatch_skt_alarm_notifications"() TO "anon";
GRANT ALL ON FUNCTION "public"."dispatch_skt_alarm_notifications"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."dispatch_skt_alarm_notifications"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_all_tenants"() TO "service_role";



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



GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_user_password"("p_email" "text", "p_new_password" "text") TO "service_role";



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



GRANT ALL ON TABLE "public"."branch_scores" TO "anon";
GRANT ALL ON TABLE "public"."branch_scores" TO "authenticated";
GRANT ALL ON TABLE "public"."branch_scores" TO "service_role";



GRANT ALL ON TABLE "public"."branches" TO "anon";
GRANT ALL ON TABLE "public"."branches" TO "authenticated";
GRANT ALL ON TABLE "public"."branches" TO "service_role";



GRANT ALL ON TABLE "public"."break_logs" TO "anon";
GRANT ALL ON TABLE "public"."break_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."break_logs" TO "service_role";



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



GRANT ALL ON TABLE "public"."inventory_transfers" TO "anon";
GRANT ALL ON TABLE "public"."inventory_transfers" TO "authenticated";
GRANT ALL ON TABLE "public"."inventory_transfers" TO "service_role";



GRANT ALL ON TABLE "public"."leave_requests" TO "anon";
GRANT ALL ON TABLE "public"."leave_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."leave_requests" TO "service_role";



GRANT ALL ON TABLE "public"."malfunction_reports" TO "anon";
GRANT ALL ON TABLE "public"."malfunction_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."malfunction_reports" TO "service_role";



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



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON TABLE "public"."v_active_skt_alarms" TO "anon";
GRANT ALL ON TABLE "public"."v_active_skt_alarms" TO "authenticated";
GRANT ALL ON TABLE "public"."v_active_skt_alarms" TO "service_role";



GRANT ALL ON TABLE "public"."v_pending_leave_requests" TO "anon";
GRANT ALL ON TABLE "public"."v_pending_leave_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."v_pending_leave_requests" TO "service_role";



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







