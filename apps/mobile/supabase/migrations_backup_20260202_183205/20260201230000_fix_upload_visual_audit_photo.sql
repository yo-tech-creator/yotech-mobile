-- ============================================
-- FOTOĞRAF YÜKLEME FONKSİYONUNU DÜZELT
-- ============================================
-- Sorun: Eski fonksiyon template_id üzerinden JOIN yapıyor
-- template_id artık NULL olabilir, bu yüzden JOIN başarısız oluyor
-- Çözüm: min_photos direkt tasks tablosundan al

-- Eski fonksiyonu sil
DROP FUNCTION IF EXISTS upload_visual_audit_photo(UUID, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION);

-- Düzeltilmiş fonksiyon
CREATE OR REPLACE FUNCTION upload_visual_audit_photo(
  p_task_id UUID,
  p_photo_url TEXT,
  p_caption TEXT DEFAULT NULL,
  p_thumbnail_url TEXT DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_task RECORD;
  v_photo_count INTEGER;
BEGIN
  -- Görevi al (template JOIN yok - artık gerekli değil)
  SELECT * INTO v_task
  FROM visual_audit_tasks
  WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı';
  END IF;
  
  -- Fotoğraf ekle
  INSERT INTO visual_audit_photos (
    tenant_id, task_id, uploaded_by, photo_url, thumbnail_url, caption, latitude, longitude
  )
  VALUES (
    v_task.tenant_id, p_task_id, current_user_id(), p_photo_url, p_thumbnail_url, p_caption, p_latitude, p_longitude
  )
  RETURNING id INTO v_id;
  
  -- Fotoğraf sayısını kontrol et
  SELECT COUNT(*) INTO v_photo_count FROM visual_audit_photos WHERE task_id = p_task_id;
  
  -- Durumu güncelle
  IF v_task.status = 'pending' THEN
    UPDATE visual_audit_tasks 
    SET status = 'in_progress', updated_at = now()
    WHERE id = p_task_id;
  END IF;
  
  -- Minimum fotoğraf sayısına ulaşıldıysa tamamla
  -- min_photos artık tasks tablosunda, COALESCE ile varsayılan 1
  IF v_photo_count >= COALESCE(v_task.min_photos, 1) AND v_task.status NOT IN ('completed', 'approved') THEN
    UPDATE visual_audit_tasks 
    SET status = 'completed', completed_by = current_user_id(), completed_at = now(), updated_at = now()
    WHERE id = p_task_id;
  END IF;
  
  RETURN v_id;
END;
$$;

-- Yetkileri ver
GRANT EXECUTE ON FUNCTION upload_visual_audit_photo(UUID, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

-- Yorum ekle
COMMENT ON FUNCTION upload_visual_audit_photo IS 'Visual audit görevi için fotoğraf yükler. template_id NULL olabilir.';
