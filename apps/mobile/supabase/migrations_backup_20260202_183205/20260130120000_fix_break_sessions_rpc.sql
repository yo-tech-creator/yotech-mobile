-- Fix get_branch_break_sessions RPC function
-- The function was using v_mgr.region_id which doesn't exist in users table
-- Instead, we need to look up managed regions from the regions table

CREATE OR REPLACE FUNCTION "public"."get_branch_break_sessions"("p_user_id" "uuid" DEFAULT "auth"."uid"()) 
RETURNS SETOF "public"."break_sessions"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
DECLARE
  v_mgr users;
  v_managed_region_ids uuid[];
BEGIN
  SELECT * INTO v_mgr FROM users WHERE id = p_user_id;

  IF v_mgr.id IS NULL THEN
    RAISE EXCEPTION 'Kullanıcı bulunamadı';
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
