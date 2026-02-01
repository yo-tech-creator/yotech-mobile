-- Visual Audit RPC fonksiyonlarına grand_admin yetkisi ekle

-- Önce mevcut fonksiyonları drop et (return type değiştirmek için gerekli)
DROP FUNCTION IF EXISTS get_visual_audit_templates_list();
DROP FUNCTION IF EXISTS get_visual_audit_sections();
DROP FUNCTION IF EXISTS create_visual_audit_section(TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS create_visual_audit_template(TEXT, UUID[], TEXT[], TEXT, UUID[], visual_audit_recurrence, INTEGER[], INTEGER[], INTEGER, INTEGER);

-- Bölüm oluştur - grand_admin ekle
CREATE OR REPLACE FUNCTION create_visual_audit_section(
  p_name TEXT,
  p_description TEXT DEFAULT NULL,
  p_icon TEXT DEFAULT 'store',
  p_color TEXT DEFAULT '#3B82F6'
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_role TEXT;
  v_tenant_id UUID;
BEGIN
  v_role := current_user_role();
  
  -- grand_admin de ekleyebilsin
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  -- grand_admin için tenant_id parametre olarak alınmalı, şimdilik first tenant
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  INSERT INTO visual_audit_sections (tenant_id, name, description, icon, color)
  VALUES (v_tenant_id, p_name, p_description, p_icon, p_color)
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$;

-- Şablon oluştur - grand_admin ekle
CREATE OR REPLACE FUNCTION create_visual_audit_template(
  p_name TEXT,
  p_section_ids UUID[],
  p_scheduled_times TEXT[],
  p_description TEXT DEFAULT NULL,
  p_branch_ids UUID[] DEFAULT NULL,
  p_recurrence visual_audit_recurrence DEFAULT 'daily',
  p_weekly_days INTEGER[] DEFAULT ARRAY[1,2,3,4,5],
  p_monthly_days INTEGER[] DEFAULT NULL,
  p_deadline_minutes INTEGER DEFAULT 60,
  p_min_photos INTEGER DEFAULT 1
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_role TEXT;
  v_user_id UUID;
  v_tenant_id UUID;
  v_section_id UUID;
  v_branch_id UUID;
  v_actual_branch_ids UUID[];
BEGIN
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  -- grand_admin de ekleyebilsin
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  -- grand_admin için tenant_id
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  -- Şube listesi boşsa, tenant'ın tüm aktif şubelerini al
  IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
    SELECT array_agg(id) INTO v_actual_branch_ids
    FROM branches
    WHERE tenant_id = v_tenant_id AND is_active = true;
  ELSE
    v_actual_branch_ids := p_branch_ids;
  END IF;
  
  -- Template oluştur
  INSERT INTO visual_audit_templates (
    tenant_id, name, description, recurrence, 
    weekly_days, monthly_days, scheduled_times,
    deadline_minutes, min_photos, created_by
  )
  VALUES (
    v_tenant_id, p_name, p_description, p_recurrence,
    p_weekly_days, p_monthly_days, p_scheduled_times,
    p_deadline_minutes, p_min_photos, v_user_id
  )
  RETURNING id INTO v_id;
  
  -- Bölümleri ekle
  FOREACH v_section_id IN ARRAY p_section_ids
  LOOP
    INSERT INTO visual_audit_template_sections (template_id, section_id)
    VALUES (v_id, v_section_id);
  END LOOP;
  
  -- Şubeleri ekle
  IF v_actual_branch_ids IS NOT NULL THEN
    FOREACH v_branch_id IN ARRAY v_actual_branch_ids
    LOOP
      INSERT INTO visual_audit_template_branches (template_id, branch_id)
      VALUES (v_id, v_branch_id);
    END LOOP;
  END IF;
  
  RETURN v_id;
END;
$$;

-- get_visual_audit_sections - grand_admin için tüm tenant'ları göster
CREATE OR REPLACE FUNCTION get_visual_audit_sections()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  icon TEXT,
  color TEXT,
  display_order INTEGER,
  is_active BOOLEAN
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
  v_role TEXT;
BEGIN
  v_role := current_user_role();
  
  IF v_role = 'grand_admin' THEN
    -- grand_admin tüm bölümleri görsün
    RETURN QUERY
    SELECT s.id, s.name, s.description, s.icon, s.color, s.display_order, s.is_active
    FROM visual_audit_sections s
    ORDER BY s.display_order, s.name;
  ELSE
    v_tenant_id := current_tenant_id();
    
    RETURN QUERY
    SELECT s.id, s.name, s.description, s.icon, s.color, s.display_order, s.is_active
    FROM visual_audit_sections s
    WHERE s.tenant_id = v_tenant_id
    ORDER BY s.display_order, s.name;
  END IF;
END;
$$;

-- get_visual_audit_templates_list - grand_admin için
CREATE OR REPLACE FUNCTION get_visual_audit_templates_list()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  section_names TEXT[],
  branch_count BIGINT,
  recurrence TEXT,
  scheduled_times TEXT[],
  is_active BOOLEAN,
  created_by_name TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
  v_role TEXT;
BEGIN
  v_role := current_user_role();
  
  IF v_role = 'grand_admin' THEN
    RETURN QUERY
    SELECT 
      t.id,
      t.name,
      t.description,
      (SELECT array_agg(s.name) FROM visual_audit_template_sections ts 
       JOIN visual_audit_sections s ON s.id = ts.section_id 
       WHERE ts.template_id = t.id),
      (SELECT COUNT(*) FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      t.recurrence::TEXT,
      t.scheduled_times,
      t.is_active,
      (SELECT COALESCE(p.full_name, 'Sistem') FROM profiles p WHERE p.id = t.created_by),
      t.created_at
    FROM visual_audit_templates t
    ORDER BY t.created_at DESC;
  ELSE
    v_tenant_id := current_tenant_id();
    
    RETURN QUERY
    SELECT 
      t.id,
      t.name,
      t.description,
      (SELECT array_agg(s.name) FROM visual_audit_template_sections ts 
       JOIN visual_audit_sections s ON s.id = ts.section_id 
       WHERE ts.template_id = t.id),
      (SELECT COUNT(*) FROM visual_audit_template_branches tb WHERE tb.template_id = t.id),
      t.recurrence::TEXT,
      t.scheduled_times,
      t.is_active,
      (SELECT COALESCE(p.full_name, 'Sistem') FROM profiles p WHERE p.id = t.created_by),
      t.created_at
    FROM visual_audit_templates t
    WHERE t.tenant_id = v_tenant_id
    ORDER BY t.created_at DESC;
  END IF;
END;
$$;
