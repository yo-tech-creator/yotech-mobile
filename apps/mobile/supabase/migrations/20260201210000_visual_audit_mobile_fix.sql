-- =====================================================
-- FIX: Mobile app için get_my_visual_audit_tasks güncelleme
-- =====================================================
-- Mobil uygulama hala eski fonksiyonu çağırıyor
-- Yeni sistemde template kullanılmıyor, section/notes kullanılıyor

-- 1. Tasks tablosuna title kolonu ekle (eğer yoksa)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'visual_audit_tasks' AND column_name = 'title') THEN
    ALTER TABLE visual_audit_tasks ADD COLUMN title TEXT;
  END IF;
END $$;

-- 2. Mevcut görevlerin title'ını section name'den doldur
UPDATE visual_audit_tasks t
SET title = s.name
FROM visual_audit_sections s
WHERE t.section_id = s.id AND t.title IS NULL;

-- 3. Eski fonksiyonu sil (return type değiştiğinden DROP gerekli)
DROP FUNCTION IF EXISTS get_my_visual_audit_tasks(DATE, TEXT);

-- 4. get_my_visual_audit_tasks fonksiyonunu güncelle
-- Artık template yerine section name ve notes kullanıyor
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
  is_overdue BOOLEAN,
  notes TEXT,
  title TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_id UUID;
BEGIN
  -- Kullanıcının şubesini al
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

-- 4. Grant
GRANT EXECUTE ON FUNCTION get_my_visual_audit_tasks(DATE, TEXT) TO authenticated;
