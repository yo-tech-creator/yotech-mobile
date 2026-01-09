-- Bölge müdürü yetkilendirilmiş personel işlemleri.

-- Yardımcı fonksiyon: auth ve public kayıtlarını birlikte oluşturan mevcut helper.
CREATE OR REPLACE FUNCTION public.add_personel(
  p_employee_code text,
  p_password text,
  p_tenant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
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
CREATE OR REPLACE FUNCTION public.region_manager_get_branch_personnel(p_branch_id uuid)
RETURNS TABLE (
  member_id uuid,
  first_name text,
  last_name text,
  email text,
  phone text,
  employee_code text,
  role user_role,
  "position" text,
  active boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

CREATE OR REPLACE FUNCTION public.region_manager_update_personnel_role(
  p_personnel_id uuid,
  p_role user_role
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

CREATE OR REPLACE FUNCTION public.region_manager_remove_personnel(
  p_personnel_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

CREATE OR REPLACE FUNCTION public.region_manager_create_personnel(
  p_branch_id uuid,
  p_employee_code text,
  p_password text,
  p_first_name text,
  p_last_name text,
  p_role user_role,
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_position text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

GRANT EXECUTE ON FUNCTION public.region_manager_get_branch_personnel(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.region_manager_update_personnel_role(uuid, user_role)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.region_manager_remove_personnel(uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.region_manager_create_personnel(
  uuid, text, text, text, text, user_role, text, text, text
) TO authenticated, service_role;
