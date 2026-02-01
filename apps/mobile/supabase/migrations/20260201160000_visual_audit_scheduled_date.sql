-- ============================================
-- GÖRSEL DENETİM - SCHEDULED DATE PARAMETRESİ
-- ============================================
-- Tekrarlayan görevler için scheduled_date parametresi eklendi

DROP FUNCTION IF EXISTS create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT);
DROP FUNCTION IF EXISTS create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE);

CREATE OR REPLACE FUNCTION create_visual_audit_task(
  p_branch_ids UUID[],
  p_section_ids UUID[],
  p_deadline_minutes INTEGER DEFAULT 60,
  p_min_photos INTEGER DEFAULT 1,
  p_note TEXT DEFAULT NULL,
  p_scheduled_date DATE DEFAULT CURRENT_DATE
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
  v_deadline_at TIMESTAMPTZ;
BEGIN
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'En az bir bölüm seçmelisiniz';
  END IF;
  
  -- Şube listesi
  IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
    IF v_role = 'sube_muduru' THEN
      SELECT ARRAY[branch_id] INTO v_actual_branch_ids FROM users WHERE id = v_user_id;
    ELSIF v_role = 'bolge_muduru' THEN
      SELECT ARRAY_AGG(b.id) INTO v_actual_branch_ids 
      FROM branches b
      JOIN users u ON u.region_id = b.region_id
      WHERE u.id = v_user_id AND b.active = true;
    ELSE
      SELECT ARRAY_AGG(id) INTO v_actual_branch_ids 
      FROM branches 
      WHERE tenant_id = v_tenant_id AND active = true;
    END IF;
  ELSE
    v_actual_branch_ids := p_branch_ids;
  END IF;
  
  IF v_actual_branch_ids IS NULL OR array_length(v_actual_branch_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'Görev gönderilebilecek şube bulunamadı';
  END IF;
  
  -- Deadline hesapla - scheduled_date'e göre
  -- Eğer scheduled_date bugün ise şimdiden itibaren, değilse o günün başlangıcından itibaren
  IF p_scheduled_date = CURRENT_DATE THEN
    v_deadline_at := NOW() + (p_deadline_minutes || ' minutes')::INTERVAL;
  ELSE
    -- Gelecek bir gün için: O günün sabah 09:00'dan itibaren deadline
    v_deadline_at := (p_scheduled_date::TIMESTAMP + TIME '09:00:00') + (p_deadline_minutes || ' minutes')::INTERVAL;
  END IF;
  
  FOREACH v_branch_id IN ARRAY v_actual_branch_ids
  LOOP
    SELECT name INTO v_branch_name FROM branches WHERE id = v_branch_id;
    
    FOREACH v_section_id IN ARRAY p_section_ids
    LOOP
      SELECT name INTO v_section_name FROM visual_audit_sections WHERE id = v_section_id;
      
      INSERT INTO visual_audit_tasks (
        tenant_id, template_id, branch_id, section_id,
        scheduled_date, scheduled_time, deadline_at,
        min_photos, notes, created_by, status
      )
      VALUES (
        v_tenant_id, NULL, v_branch_id, v_section_id,
        p_scheduled_date, 
        CASE WHEN p_scheduled_date = CURRENT_DATE THEN CURRENT_TIME ELSE TIME '09:00:00' END,
        v_deadline_at,
        p_min_photos, p_note, v_user_id, 'pending'
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT, DATE) TO authenticated;
