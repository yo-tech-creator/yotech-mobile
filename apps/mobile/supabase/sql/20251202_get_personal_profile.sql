-- Kullanıcılar için şirket, şube ve yönetici bilgilerinin tek seferde
-- güvenli şekilde alınmasını sağlayan yardımcı fonksiyon.
CREATE OR REPLACE FUNCTION public.get_personal_profile(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  first_name text,
  last_name text,
  email text,
  phone text,
  "position" text,
  role user_role,
  employee_code text,
  hire_date date,
  tenant_id uuid,
  tenant_name text,
  branch_id uuid,
  branch_name text,
  branch_code text,
  branch_city text,
  branch_district text,
  branch_manager_id uuid,
  branch_manager_first_name text,
  branch_manager_last_name text,
  branch_manager_phone text,
  region_id uuid,
  region_name text,
  regional_manager_id uuid,
  regional_manager_first_name text,
  regional_manager_last_name text,
  regional_manager_phone text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

GRANT EXECUTE ON FUNCTION public.get_personal_profile(uuid)
  TO authenticated, service_role, anon;
