-- Spesifik şablonlar için görev oluşturma fonksiyonu
-- Belirli şablonları seçerek belirli bir tarih için görev oluşturur

CREATE OR REPLACE FUNCTION generate_visual_audit_tasks_for_templates(
  p_template_ids UUID[],
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_template RECORD;
  v_branch_id UUID;
  v_section_id UUID;
  v_time TEXT;
  v_count INTEGER := 0;
  v_branches UUID[];
  v_sections UUID[];
BEGIN
  -- Her şablon için
  FOR v_template IN 
    SELECT * FROM visual_audit_templates 
    WHERE id = ANY(p_template_ids)
      AND is_active = TRUE
  LOOP
    -- Şubeleri belirle - önce relational table'dan
    SELECT ARRAY_AGG(tb.branch_id) INTO v_branches
    FROM visual_audit_template_branches tb
    WHERE tb.template_id = v_template.id;
    
    IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
      -- Fallback: tüm aktif şubeleri al
      SELECT ARRAY_AGG(b.id) INTO v_branches 
      FROM branches b 
      WHERE b.tenant_id = v_template.tenant_id AND b.active = TRUE;
    END IF;
    
    -- Bölümleri belirle - önce relational table'dan
    SELECT ARRAY_AGG(ts.section_id) INTO v_sections
    FROM visual_audit_template_sections ts
    WHERE ts.template_id = v_template.id;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      -- Fallback to section_ids array
      v_sections := v_template.section_ids;
    END IF;
    
    -- Eğer hala bölüm yoksa atla
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      CONTINUE;
    END IF;
    
    -- Her şube için
    IF v_branches IS NOT NULL THEN
      FOREACH v_branch_id IN ARRAY v_branches
      LOOP
        -- Her bölüm için
        FOREACH v_section_id IN ARRAY v_sections
        LOOP
          -- Her saat için
          FOREACH v_time IN ARRAY v_template.scheduled_times
          LOOP
            INSERT INTO visual_audit_tasks (
              tenant_id, template_id, branch_id, section_id,
              scheduled_date, scheduled_time, deadline_at
            )
            VALUES (
              v_template.tenant_id, v_template.id, v_branch_id, v_section_id,
              p_date, v_time::TIME,
              (p_date + v_time::TIME) + (v_template.deadline_minutes || ' minutes')::INTERVAL
            )
            ON CONFLICT (template_id, branch_id, section_id, scheduled_date, scheduled_time) DO NOTHING;
            
            v_count := v_count + 1;
          END LOOP;
        END LOOP;
      END LOOP;
    END IF;
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- Şablon güncelleme fonksiyonu
CREATE OR REPLACE FUNCTION update_visual_audit_template(
  p_id UUID,
  p_name TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL,
  p_section_ids UUID[] DEFAULT NULL,
  p_branch_ids UUID[] DEFAULT NULL,
  p_recurrence visual_audit_recurrence DEFAULT NULL,
  p_weekly_days INTEGER[] DEFAULT NULL,
  p_scheduled_times TEXT[] DEFAULT NULL,
  p_deadline_minutes INTEGER DEFAULT NULL,
  p_min_photos INTEGER DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_tenant_id UUID;
  v_section_id UUID;
  v_branch_id UUID;
  v_order INTEGER := 0;
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  -- Şablonun var olduğunu ve tenant'a ait olduğunu kontrol et
  IF v_role = 'grand_admin' THEN
    SELECT tenant_id INTO v_tenant_id FROM visual_audit_templates WHERE id = p_id;
  ELSE
    v_tenant_id := current_tenant_id();
    IF NOT EXISTS (SELECT 1 FROM visual_audit_templates WHERE id = p_id AND tenant_id = v_tenant_id) THEN
      RAISE EXCEPTION 'Şablon bulunamadı';
    END IF;
  END IF;
  
  -- Temel alanları güncelle
  UPDATE visual_audit_templates SET
    name = COALESCE(p_name, name),
    description = COALESCE(p_description, description),
    recurrence = COALESCE(p_recurrence, recurrence),
    weekly_days = COALESCE(p_weekly_days, weekly_days),
    scheduled_times = COALESCE(p_scheduled_times, scheduled_times),
    deadline_minutes = COALESCE(p_deadline_minutes, deadline_minutes),
    min_photos = COALESCE(p_min_photos, min_photos),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = NOW()
  WHERE id = p_id;
  
  -- Bölümler değiştiyse güncelle
  IF p_section_ids IS NOT NULL THEN
    DELETE FROM visual_audit_template_sections WHERE template_id = p_id;
    FOREACH v_section_id IN ARRAY p_section_ids
    LOOP
      INSERT INTO visual_audit_template_sections (template_id, section_id, display_order)
      VALUES (p_id, v_section_id, v_order);
      v_order := v_order + 1;
    END LOOP;
  END IF;
  
  -- Şubeler değiştiyse güncelle
  IF p_branch_ids IS NOT NULL THEN
    DELETE FROM visual_audit_template_branches WHERE template_id = p_id;
    IF array_length(p_branch_ids, 1) > 0 THEN
      FOREACH v_branch_id IN ARRAY p_branch_ids
      LOOP
        INSERT INTO visual_audit_template_branches (template_id, branch_id)
        VALUES (p_id, v_branch_id);
      END LOOP;
    ELSE
      -- Boş array = tüm şubeler, hiç kayıt ekleme (fonksiyon tüm şubeleri alacak)
      NULL;
    END IF;
  END IF;
  
  RETURN TRUE;
END;
$$;

-- Şablon silme fonksiyonu (soft delete)
CREATE OR REPLACE FUNCTION delete_visual_audit_template(
  p_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_tenant_id UUID;
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    UPDATE visual_audit_templates SET is_active = FALSE, updated_at = NOW() WHERE id = p_id;
  ELSE
    v_tenant_id := current_tenant_id();
    UPDATE visual_audit_templates 
    SET is_active = FALSE, updated_at = NOW() 
    WHERE id = p_id AND tenant_id = v_tenant_id;
  END IF;
  
  RETURN TRUE;
END;
$$;

-- Şablon detaylarını getiren fonksiyon (düzenleme için)
CREATE OR REPLACE FUNCTION get_visual_audit_template_detail(
  p_id UUID
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  section_ids UUID[],
  branch_ids UUID[],
  recurrence TEXT,
  weekly_days INTEGER[],
  monthly_days INTEGER[],
  scheduled_times TEXT[],
  deadline_minutes INTEGER,
  min_photos INTEGER,
  is_active BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_tenant_id UUID;
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    RETURN QUERY
    SELECT 
      t.id,
      t.name,
      t.description,
      ARRAY(SELECT ts.section_id FROM visual_audit_template_sections ts WHERE ts.template_id = t.id ORDER BY ts.display_order),
      ARRAY(SELECT tb.branch_id FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      t.recurrence::TEXT,
      t.weekly_days,
      t.monthly_days,
      t.scheduled_times,
      t.deadline_minutes,
      t.min_photos,
      t.is_active
    FROM visual_audit_templates t
    WHERE t.id = p_id;
  ELSE
    v_tenant_id := current_tenant_id();
    RETURN QUERY
    SELECT 
      t.id,
      t.name,
      t.description,
      ARRAY(SELECT ts.section_id FROM visual_audit_template_sections ts WHERE ts.template_id = t.id ORDER BY ts.display_order),
      ARRAY(SELECT tb.branch_id FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      t.recurrence::TEXT,
      t.weekly_days,
      t.monthly_days,
      t.scheduled_times,
      t.deadline_minutes,
      t.min_photos,
      t.is_active
    FROM visual_audit_templates t
    WHERE t.id = p_id AND t.tenant_id = v_tenant_id;
  END IF;
END;
$$;

-- GRANT EXECUTE
GRANT EXECUTE ON FUNCTION generate_visual_audit_tasks_for_templates(UUID[], DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION update_visual_audit_template(UUID, TEXT, TEXT, UUID[], UUID[], visual_audit_recurrence, INTEGER[], TEXT[], INTEGER, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_visual_audit_template(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_visual_audit_template_detail(UUID) TO authenticated;
