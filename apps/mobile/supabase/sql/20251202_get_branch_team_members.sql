-- Takım arkadaşları ekranı için şube personel listesini güvenli şekilde döndüren fonksiyon.
CREATE OR REPLACE FUNCTION public.get_branch_team_members(p_user_id uuid)
RETURNS TABLE (
  member_id uuid,
  first_name text,
  last_name text,
  "position" text,
  role user_role,
  phone text,
  email text,
  employee_code text,
  branch_id uuid,
  is_branch_manager boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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

GRANT EXECUTE ON FUNCTION public.get_branch_team_members(uuid)
  TO authenticated, service_role, anon;
