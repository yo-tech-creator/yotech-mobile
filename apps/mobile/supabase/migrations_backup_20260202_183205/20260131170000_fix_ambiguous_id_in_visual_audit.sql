-- Fix ambiguous "id" column reference in get_my_visual_audit_tasks function
-- The "id" in RETURNS TABLE conflicts with "id" column in users table

CREATE OR REPLACE FUNCTION get_my_visual_audit_tasks(
  p_date DATE DEFAULT CURRENT_DATE,
  p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  template_id UUID,
  template_name TEXT,
  section_id UUID,
  section_name TEXT,
  section_icon TEXT,
  section_color TEXT,
  scheduled_date DATE,
  scheduled_time TIME,
  deadline_at TIMESTAMPTZ,
  status visual_audit_task_status,
  photo_count BIGINT,
  min_photos INTEGER,
  completed_by UUID,
  completed_at TIMESTAMPTZ,
  is_overdue BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_id UUID;
BEGIN
  -- Kullanıcının şubesini al - users.id olarak belirt
  SELECT u.branch_id INTO v_branch_id FROM users u WHERE u.id = current_user_id();
  
  IF v_branch_id IS NULL THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.template_id,
    vt.name AS template_name,
    t.section_id,
    s.name AS section_name,
    s.icon AS section_icon,
    s.color AS section_color,
    t.scheduled_date,
    t.scheduled_time,
    t.deadline_at,
    t.status,
    COUNT(p.id) AS photo_count,
    vt.min_photos,
    t.completed_by,
    t.completed_at,
    (t.deadline_at < now() AND t.status NOT IN ('completed', 'approved')) AS is_overdue
  FROM visual_audit_tasks t
  JOIN visual_audit_templates vt ON vt.id = t.template_id
  JOIN visual_audit_sections s ON s.id = t.section_id
  LEFT JOIN visual_audit_photos p ON p.task_id = t.id
  WHERE t.branch_id = v_branch_id
    AND t.scheduled_date = p_date
    AND (p_status IS NULL OR t.status::TEXT = p_status)
  GROUP BY t.id, vt.name, vt.min_photos, s.name, s.icon, s.color
  ORDER BY t.scheduled_time, s.name;
END;
$$;
