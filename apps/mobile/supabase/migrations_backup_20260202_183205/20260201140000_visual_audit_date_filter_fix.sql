-- ============================================
-- GÖRSEL DENETİM - TARİH FİLTRESİ DÜZELTMESİ
-- ============================================
-- Stats ve tasks tutarlı olsun

DROP FUNCTION IF EXISTS get_visual_audit_tasks(DATE, TEXT, UUID);
DROP FUNCTION IF EXISTS get_visual_audit_stats(DATE);

-- ============================================
-- 1. GÖREVLERİ GETİR (TARİH OPSİYONEL)
-- ============================================
-- p_date NULL ise tüm görevler gelir
-- p_date verilirse o tarihe göre filtreler

CREATE OR REPLACE FUNCTION get_visual_audit_tasks(
  p_date DATE DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_branch_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  branch_id UUID,
  branch_name TEXT,
  section_id UUID,
  section_name TEXT,
  section_color TEXT,
  status TEXT,
  scheduled_date DATE,
  scheduled_time TIME,
  deadline_at TIMESTAMPTZ,
  min_photos INTEGER,
  notes TEXT,
  created_by UUID,
  created_by_name TEXT,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  photo_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
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
    t.status,
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

-- ============================================
-- 2. İSTATİSTİKLER (TARİH OPSİYONEL)
-- ============================================
-- p_date NULL ise tüm görevlerin stats'ı
-- p_date verilirse o tarihe göre filtreler

CREATE OR REPLACE FUNCTION get_visual_audit_stats(p_date DATE DEFAULT NULL)
RETURNS TABLE (
  total_tasks BIGINT,
  pending_tasks BIGINT,
  completed_tasks BIGINT,
  overdue_tasks BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_visual_audit_tasks(DATE, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_visual_audit_stats(DATE) TO authenticated;
