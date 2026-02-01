-- Visual Audit düzeltmeleri

-- 1. Eksik tablo: visual_audit_template_sections (many-to-many ilişki tablosu)
CREATE TABLE IF NOT EXISTS visual_audit_template_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES visual_audit_templates(id) ON DELETE CASCADE,
  section_id UUID NOT NULL REFERENCES visual_audit_sections(id) ON DELETE CASCADE,
  display_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(template_id, section_id)
);

-- RLS
ALTER TABLE visual_audit_template_sections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "visual_audit_template_sections_select" ON visual_audit_template_sections
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM visual_audit_templates t 
      WHERE t.id = template_id 
      AND (t.tenant_id = current_tenant_id() OR current_user_role() = 'grand_admin')
    )
  );

CREATE POLICY "visual_audit_template_sections_insert" ON visual_audit_template_sections
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM visual_audit_templates t 
      WHERE t.id = template_id 
      AND t.tenant_id = current_tenant_id()
      AND current_user_role() IN ('firma_admin', 'bolge_muduru')
    )
  );

-- 2. get_visual_audit_sections fonksiyon overloading sorununu çöz
-- Parametreli versiyonu sil, sadece parametresiz kalsın
DROP FUNCTION IF EXISTS get_visual_audit_sections(UUID);

-- Parametresiz versiyonu yeniden oluştur (varsa üzerine yaz)
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
    -- Grand admin tüm tenant'ların bölümlerini görebilir (ilk tenant için)
    SELECT t.id INTO v_tenant_id FROM tenants t LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  RETURN QUERY
  SELECT 
    s.id,
    s.name,
    s.description,
    s.icon,
    s.color,
    s.display_order,
    s.is_active
  FROM visual_audit_sections s
  WHERE s.tenant_id = v_tenant_id
    AND s.is_active = true
  ORDER BY s.display_order, s.name;
END;
$$;

-- 3. get_visual_audit_templates_list fonksiyonunu düzelt (template_sections tablosu olmadan çalışsın)
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
    SELECT t.id INTO v_tenant_id FROM tenants t LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    COALESCE(
      (SELECT array_agg(s.name ORDER BY ts.display_order)
       FROM visual_audit_template_sections ts
       JOIN visual_audit_sections s ON s.id = ts.section_id
       WHERE ts.template_id = t.id),
      ARRAY[]::TEXT[]
    ) as section_names,
    (SELECT COUNT(*) FROM visual_audit_template_branches tb WHERE tb.template_id = t.id) as branch_count,
    t.recurrence::TEXT,
    t.scheduled_times,
    t.is_active,
    COALESCE(u.first_name || ' ' || u.last_name, 'Sistem') as created_by_name,
    t.created_at
  FROM visual_audit_templates t
  LEFT JOIN users u ON u.id = t.created_by
  WHERE t.tenant_id = v_tenant_id
    AND t.is_active = true
  ORDER BY t.created_at DESC;
END;
$$;

-- 4. create_visual_audit_template fonksiyonunu düzelt (template_sections tablosuna kayıt eklesin)
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
  v_order INTEGER := 0;
BEGIN
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  -- Şube listesi boşsa, tenant'ın tüm aktif şubelerini al
  IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
    SELECT array_agg(id) INTO v_actual_branch_ids
    FROM branches
    WHERE tenant_id = v_tenant_id AND active = true;
  ELSE
    v_actual_branch_ids := p_branch_ids;
  END IF;
  
  -- Template oluştur
  INSERT INTO visual_audit_templates (
    tenant_id, name, description, recurrence, 
    weekly_days, monthly_days, scheduled_times,
    deadline_minutes, min_photos, created_by
  ) VALUES (
    v_tenant_id, p_name, p_description, p_recurrence,
    p_weekly_days, p_monthly_days, p_scheduled_times,
    p_deadline_minutes, p_min_photos, v_user_id
  ) RETURNING id INTO v_id;
  
  -- Template-Section ilişkilerini ekle
  FOREACH v_section_id IN ARRAY p_section_ids
  LOOP
    INSERT INTO visual_audit_template_sections (template_id, section_id, display_order)
    VALUES (v_id, v_section_id, v_order);
    v_order := v_order + 1;
  END LOOP;
  
  -- Template-Branch ilişkilerini ekle
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
