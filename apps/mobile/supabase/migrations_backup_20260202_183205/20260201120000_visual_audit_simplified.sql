-- ============================================
-- GÖRSEL DENETİM - BASİT SİSTEM
-- ============================================
-- Tek amaç: Yönetici şubelere fotoğraf görevi gönderir
-- Şube personeli fotoğraf çeker ve gönderir

-- ============================================
-- 0. ESKİ FONKSİYONLARI TEMİZLE
-- ============================================
DROP FUNCTION IF EXISTS get_visual_audit_stats(DATE);
DROP FUNCTION IF EXISTS get_visual_audit_tasks(DATE, TEXT, UUID);
DROP FUNCTION IF EXISTS create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT);
DROP FUNCTION IF EXISTS create_instant_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT);
DROP FUNCTION IF EXISTS generate_daily_visual_audit_tasks();

-- ============================================
-- 1. TABLO YAPISI (Mevcut tabloları güncelle)
-- ============================================

-- tasks tablosuna eksik kolonları ekle
DO $$
BEGIN
  -- min_photos: Minimum kaç fotoğraf çekilmeli
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'visual_audit_tasks' AND column_name = 'min_photos') THEN
    ALTER TABLE visual_audit_tasks ADD COLUMN min_photos INTEGER NOT NULL DEFAULT 1;
  END IF;
  
  -- created_by: Görevi oluşturan yönetici
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'visual_audit_tasks' AND column_name = 'created_by') THEN
    ALTER TABLE visual_audit_tasks ADD COLUMN created_by UUID REFERENCES users(id);
  END IF;
  
  -- notes: Görev notu
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'visual_audit_tasks' AND column_name = 'notes') THEN
    ALTER TABLE visual_audit_tasks ADD COLUMN notes TEXT;
  END IF;
  
  -- template_id NULL olabilir (artık şablon zorunlu değil)
  ALTER TABLE visual_audit_tasks ALTER COLUMN template_id DROP NOT NULL;
END $$;

-- ============================================
-- 2. GÖREV OLUŞTURMA FONKSİYONU
-- ============================================
-- Yönetici şubelere görev gönderir

CREATE OR REPLACE FUNCTION create_visual_audit_task(
  p_branch_ids UUID[],           -- Hangi şubelere (boş = tümü)
  p_section_ids UUID[],          -- Hangi bölümler (zorunlu)
  p_deadline_minutes INTEGER DEFAULT 60,  -- Kaç dakika içinde
  p_min_photos INTEGER DEFAULT 1,         -- Minimum fotoğraf
  p_note TEXT DEFAULT NULL                -- Not
)
RETURNS TABLE (
  task_id UUID,
  branch_name TEXT,
  section_name TEXT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_user_id UUID;
  v_tenant_id UUID;
  v_branch_id UUID;
  v_section_id UUID;
  v_task_id UUID;
  v_branch_name TEXT;
  v_section_name TEXT;
  v_actual_branch_ids UUID[];
BEGIN
  -- Yetki kontrolü
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
  END IF;
  
  -- Tenant belirle
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  -- Bölüm kontrolü
  IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'En az bir bölüm seçmelisiniz';
  END IF;
  
  -- Şube listesi
  IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
    -- Tüm aktif şubeleri al
    IF v_role = 'sube_muduru' THEN
      SELECT ARRAY[branch_id] INTO v_actual_branch_ids FROM users WHERE id = v_user_id;
    ELSIF v_role = 'bolge_muduru' THEN
      SELECT ARRAY_AGG(b.id) INTO v_actual_branch_ids 
      FROM branches b
      JOIN users u ON u.region_id = b.region_id
      WHERE u.id = v_user_id AND b.is_active = true;
    ELSE
      SELECT ARRAY_AGG(id) INTO v_actual_branch_ids 
      FROM branches 
      WHERE tenant_id = v_tenant_id AND is_active = true;
    END IF;
  ELSE
    v_actual_branch_ids := p_branch_ids;
  END IF;
  
  -- Şube kontrolü
  IF v_actual_branch_ids IS NULL OR array_length(v_actual_branch_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'Görev gönderilebilecek şube bulunamadı';
  END IF;
  
  -- Her şube ve bölüm için görev oluştur
  FOREACH v_branch_id IN ARRAY v_actual_branch_ids
  LOOP
    SELECT name INTO v_branch_name FROM branches WHERE id = v_branch_id;
    
    FOREACH v_section_id IN ARRAY p_section_ids
    LOOP
      SELECT name INTO v_section_name FROM visual_audit_sections WHERE id = v_section_id;
      
      INSERT INTO visual_audit_tasks (
        tenant_id, 
        template_id,
        branch_id, 
        section_id,
        scheduled_date, 
        scheduled_time, 
        deadline_at,
        min_photos,
        notes,
        created_by,
        status
      )
      VALUES (
        v_tenant_id, 
        NULL,  -- Şablon yok, direkt görev
        v_branch_id, 
        v_section_id,
        CURRENT_DATE, 
        CURRENT_TIME,
        NOW() + (p_deadline_minutes || ' minutes')::INTERVAL,
        p_min_photos,
        p_note,
        v_user_id,
        'pending'
      )
      RETURNING id INTO v_task_id;
      
      task_id := v_task_id;
      branch_name := v_branch_name;
      section_name := v_section_name;
      RETURN NEXT;
    END LOOP;
  END LOOP;
  
  RETURN;
END;
$$;

-- ============================================
-- 3. GÖREVLERİ GETİR FONKSİYONU
-- ============================================

CREATE OR REPLACE FUNCTION get_visual_audit_tasks(
  p_date DATE DEFAULT CURRENT_DATE,
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
  
  -- Şube personeli sadece kendi şubesini görür
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
    u.full_name AS created_by_name,
    t.created_at,
    t.completed_at,
    (SELECT COUNT(*) FROM visual_audit_photos p WHERE p.task_id = t.id) AS photo_count
  FROM visual_audit_tasks t
  JOIN branches b ON b.id = t.branch_id
  JOIN visual_audit_sections s ON s.id = t.section_id
  LEFT JOIN users u ON u.id = t.created_by
  WHERE t.tenant_id = v_tenant_id
    AND t.scheduled_date = p_date
    AND (p_status IS NULL OR t.status = p_status)
    AND (p_branch_id IS NULL OR t.branch_id = p_branch_id)
    AND (v_user_branch_id IS NULL OR t.branch_id = v_user_branch_id)
  ORDER BY t.deadline_at ASC;
END;
$$;

-- ============================================
-- 4. İSTATİSTİKLER FONKSİYONU
-- ============================================

CREATE OR REPLACE FUNCTION get_visual_audit_stats(p_date DATE DEFAULT CURRENT_DATE)
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
    AND t.scheduled_date = p_date
    AND (v_user_branch_id IS NULL OR t.branch_id = v_user_branch_id);
END;
$$;

-- ============================================
-- 5. GRANT EXECUTE
-- ============================================
GRANT EXECUTE ON FUNCTION create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_visual_audit_tasks(DATE, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_visual_audit_stats(DATE) TO authenticated;
