-- =====================================================
-- Görsel Denetim Görevlerini Silme Fonksiyonu
-- =====================================================
-- RLS bypass için SECURITY DEFINER kullanıyoruz

CREATE OR REPLACE FUNCTION delete_visual_audit_tasks(
  p_task_ids UUID[]
)
RETURNS JSON
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
  v_user_id UUID;
  v_tenant_id UUID;
  v_deleted_count INTEGER := 0;
BEGIN
  -- Yetki kontrolü
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RETURN json_build_object('success', false, 'error', 'Bu işlem için yetkiniz yok');
  END IF;
  
  -- Tenant kontrolü
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  IF p_task_ids IS NULL OR array_length(p_task_ids, 1) IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Silinecek görev seçilmedi');
  END IF;
  
  -- Önce fotoğrafları sil
  DELETE FROM visual_audit_photos 
  WHERE task_id = ANY(p_task_ids);
  
  -- Yorumları sil
  DELETE FROM visual_audit_comments 
  WHERE task_id = ANY(p_task_ids);
  
  -- Görevleri sil (sadece kendi tenant'ının görevlerini)
  WITH deleted AS (
    DELETE FROM visual_audit_tasks 
    WHERE id = ANY(p_task_ids) 
      AND tenant_id = v_tenant_id
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted;
  
  RETURN json_build_object('success', true, 'deleted', v_deleted_count);
END;
$$;

-- Grant
GRANT EXECUTE ON FUNCTION delete_visual_audit_tasks(UUID[]) TO authenticated;
