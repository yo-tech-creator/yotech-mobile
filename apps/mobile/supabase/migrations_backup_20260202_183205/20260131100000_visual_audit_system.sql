-- =====================================================
-- GÖRSEL DENETİM SİSTEMİ (Visual Audit System)
-- =====================================================
-- Bu migration görsel denetim/saha takip sistemini oluşturur
-- Admin bölüm fotoğrafları talep eder, personel yükler
-- =====================================================

-- 1. ENUM TİPLERİ
-- =====================================================

-- Denetim şablonu tekrar tipi
CREATE TYPE visual_audit_recurrence AS ENUM (
  'daily',           -- Her gün
  'weekly',          -- Haftalık belirli günler
  'monthly'          -- Aylık belirli günler
);

-- Görev durumu
CREATE TYPE visual_audit_task_status AS ENUM (
  'pending',         -- Bekliyor
  'in_progress',     -- Devam ediyor (en az 1 foto yüklendi)
  'completed',       -- Tamamlandı
  'missed',          -- Kaçırıldı (süre doldu)
  'approved',        -- Yönetici onayladı
  'rejected'         -- Yönetici reddetti, tekrar foto istedi
);

-- Yorum tipi
CREATE TYPE visual_audit_comment_type AS ENUM (
  'comment',         -- Normal yorum
  'approval',        -- Onay
  'rejection',       -- Red
  'revision_request' -- Düzeltme talebi
);

-- 2. TABLOLAR
-- =====================================================

-- Bölüm tanımları (Manav, Şarküteri, Unlu, Kasap vb.)
CREATE TABLE IF NOT EXISTS visual_audit_sections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT DEFAULT 'store',
  color TEXT DEFAULT '#3B82F6',
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  UNIQUE(tenant_id, name)
);

-- İndeksler
CREATE INDEX idx_visual_audit_sections_tenant ON visual_audit_sections(tenant_id);
CREATE INDEX idx_visual_audit_sections_active ON visual_audit_sections(tenant_id, is_active);

-- Denetim şablonları (Admin oluşturur)
CREATE TABLE IF NOT EXISTS visual_audit_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  created_by UUID NOT NULL REFERENCES users(id),
  
  name TEXT NOT NULL,
  description TEXT,
  
  -- Hangi bölümlerden foto isteniyor
  section_ids UUID[] NOT NULL,
  
  -- Hangi şubeler için (null = tüm şubeler)
  branch_ids UUID[],
  
  -- Tekrar ayarları
  recurrence visual_audit_recurrence NOT NULL DEFAULT 'daily',
  
  -- Saat ayarları (HH:MM formatında array)
  scheduled_times TEXT[] NOT NULL DEFAULT ARRAY['10:00'],
  
  -- Haftalık ise: hangi günler (0=Pazar, 1=Pazartesi, ..., 6=Cumartesi)
  weekly_days INTEGER[] DEFAULT ARRAY[1,2,3,4,5],
  
  -- Aylık ise: ayın hangi günleri
  monthly_days INTEGER[],
  
  -- Fotoğraf için süre limiti (dakika)
  deadline_minutes INTEGER DEFAULT 60,
  
  -- Minimum fotoğraf sayısı
  min_photos INTEGER DEFAULT 1,
  
  -- Aktiflik
  is_active BOOLEAN DEFAULT TRUE,
  starts_at DATE DEFAULT CURRENT_DATE,
  ends_at DATE,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- İndeksler
CREATE INDEX idx_visual_audit_templates_tenant ON visual_audit_templates(tenant_id);
CREATE INDEX idx_visual_audit_templates_active ON visual_audit_templates(tenant_id, is_active);
CREATE INDEX idx_visual_audit_templates_created_by ON visual_audit_templates(created_by);

-- Günlük oluşan görevler
CREATE TABLE IF NOT EXISTS visual_audit_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  template_id UUID NOT NULL REFERENCES visual_audit_templates(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  section_id UUID NOT NULL REFERENCES visual_audit_sections(id) ON DELETE CASCADE,
  
  -- Görev zamanlaması
  scheduled_date DATE NOT NULL,
  scheduled_time TIME NOT NULL,
  deadline_at TIMESTAMPTZ NOT NULL,
  
  -- Durum
  status visual_audit_task_status NOT NULL DEFAULT 'pending',
  
  -- Tamamlama bilgileri
  completed_by UUID REFERENCES users(id),
  completed_at TIMESTAMPTZ,
  
  -- Onay bilgileri
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMPTZ,
  review_note TEXT,
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  
  -- Aynı gün, aynı saat, aynı bölüm için tekrar görev oluşmasın
  UNIQUE(template_id, branch_id, section_id, scheduled_date, scheduled_time)
);

-- İndeksler
CREATE INDEX idx_visual_audit_tasks_tenant ON visual_audit_tasks(tenant_id);
CREATE INDEX idx_visual_audit_tasks_branch ON visual_audit_tasks(branch_id);
CREATE INDEX idx_visual_audit_tasks_template ON visual_audit_tasks(template_id);
CREATE INDEX idx_visual_audit_tasks_date ON visual_audit_tasks(scheduled_date);
CREATE INDEX idx_visual_audit_tasks_status ON visual_audit_tasks(status);
CREATE INDEX idx_visual_audit_tasks_section ON visual_audit_tasks(section_id);
CREATE INDEX idx_visual_audit_tasks_pending ON visual_audit_tasks(branch_id, status, scheduled_date) 
  WHERE status IN ('pending', 'in_progress', 'rejected');

-- Yüklenen fotoğraflar
CREATE TABLE IF NOT EXISTS visual_audit_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  task_id UUID NOT NULL REFERENCES visual_audit_tasks(id) ON DELETE CASCADE,
  
  -- Yükleyen kullanıcı
  uploaded_by UUID NOT NULL REFERENCES users(id),
  
  -- Fotoğraf URL'i (Supabase Storage)
  photo_url TEXT NOT NULL,
  thumbnail_url TEXT,
  
  -- Fotoğraf meta bilgileri
  file_name TEXT,
  file_size INTEGER,
  mime_type TEXT DEFAULT 'image/jpeg',
  
  -- Opsiyonel açıklama
  caption TEXT,
  
  -- Konum bilgisi (opsiyonel)
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  
  created_at TIMESTAMPTZ DEFAULT now()
);

-- İndeksler
CREATE INDEX idx_visual_audit_photos_task ON visual_audit_photos(task_id);
CREATE INDEX idx_visual_audit_photos_tenant ON visual_audit_photos(tenant_id);
CREATE INDEX idx_visual_audit_photos_uploaded_by ON visual_audit_photos(uploaded_by);

-- Görev yorumları (iletişim için)
CREATE TABLE IF NOT EXISTS visual_audit_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  task_id UUID NOT NULL REFERENCES visual_audit_tasks(id) ON DELETE CASCADE,
  
  user_id UUID NOT NULL REFERENCES users(id),
  comment_type visual_audit_comment_type NOT NULL DEFAULT 'comment',
  message TEXT NOT NULL,
  
  -- Yoruma bağlı fotoğraf varsa
  photo_id UUID REFERENCES visual_audit_photos(id),
  
  created_at TIMESTAMPTZ DEFAULT now()
);

-- İndeksler
CREATE INDEX idx_visual_audit_comments_task ON visual_audit_comments(task_id);
CREATE INDEX idx_visual_audit_comments_user ON visual_audit_comments(user_id);

-- 3. RLS POLİTİKALARI
-- =====================================================

ALTER TABLE visual_audit_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE visual_audit_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE visual_audit_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE visual_audit_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE visual_audit_comments ENABLE ROW LEVEL SECURITY;

-- Bölümler: Aynı tenant'ın kullanıcıları görebilir
CREATE POLICY visual_audit_sections_select ON visual_audit_sections
  FOR SELECT USING (tenant_id = current_tenant_id() OR current_user_role() = 'grand_admin');

CREATE POLICY visual_audit_sections_insert ON visual_audit_sections
  FOR INSERT WITH CHECK (
    tenant_id = current_tenant_id() AND 
    current_user_role() IN ('firma_admin', 'bolge_muduru')
  );

CREATE POLICY visual_audit_sections_update ON visual_audit_sections
  FOR UPDATE USING (
    tenant_id = current_tenant_id() AND 
    current_user_role() IN ('firma_admin', 'bolge_muduru')
  );

CREATE POLICY visual_audit_sections_delete ON visual_audit_sections
  FOR DELETE USING (
    tenant_id = current_tenant_id() AND 
    current_user_role() = 'firma_admin'
  );

-- Şablonlar: Yöneticiler oluşturabilir/görebilir
CREATE POLICY visual_audit_templates_select ON visual_audit_templates
  FOR SELECT USING (tenant_id = current_tenant_id() OR current_user_role() = 'grand_admin');

CREATE POLICY visual_audit_templates_insert ON visual_audit_templates
  FOR INSERT WITH CHECK (
    tenant_id = current_tenant_id() AND 
    current_user_role() IN ('firma_admin', 'bolge_muduru', 'sube_muduru')
  );

CREATE POLICY visual_audit_templates_update ON visual_audit_templates
  FOR UPDATE USING (
    tenant_id = current_tenant_id() AND 
    current_user_role() IN ('firma_admin', 'bolge_muduru', 'sube_muduru')
  );

CREATE POLICY visual_audit_templates_delete ON visual_audit_templates
  FOR DELETE USING (
    tenant_id = current_tenant_id() AND 
    current_user_role() IN ('firma_admin', 'bolge_muduru')
  );

-- Görevler: Aynı tenant görebilir, şube personeli kendi şubesini görebilir
CREATE POLICY visual_audit_tasks_select ON visual_audit_tasks
  FOR SELECT USING (
    current_user_role() = 'grand_admin' OR
    tenant_id = current_tenant_id()
  );

CREATE POLICY visual_audit_tasks_update ON visual_audit_tasks
  FOR UPDATE USING (
    tenant_id = current_tenant_id()
  );

-- Fotoğraflar
CREATE POLICY visual_audit_photos_select ON visual_audit_photos
  FOR SELECT USING (
    current_user_role() = 'grand_admin' OR
    tenant_id = current_tenant_id()
  );

CREATE POLICY visual_audit_photos_insert ON visual_audit_photos
  FOR INSERT WITH CHECK (
    tenant_id = current_tenant_id()
  );

CREATE POLICY visual_audit_photos_delete ON visual_audit_photos
  FOR DELETE USING (
    tenant_id = current_tenant_id() AND
    (uploaded_by = current_user_id() OR current_user_role() IN ('firma_admin', 'bolge_muduru', 'sube_muduru'))
  );

-- Yorumlar
CREATE POLICY visual_audit_comments_select ON visual_audit_comments
  FOR SELECT USING (
    current_user_role() = 'grand_admin' OR
    tenant_id = current_tenant_id()
  );

CREATE POLICY visual_audit_comments_insert ON visual_audit_comments
  FOR INSERT WITH CHECK (
    tenant_id = current_tenant_id()
  );

-- 4. RPC FONKSİYONLARI
-- =====================================================

-- Bölüm listesi getir
CREATE OR REPLACE FUNCTION get_visual_audit_sections(
  p_tenant_id UUID DEFAULT NULL
)
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
BEGIN
  v_tenant_id := COALESCE(p_tenant_id, current_tenant_id());
  
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
  ORDER BY s.display_order, s.name;
END;
$$;

-- Bölüm oluştur
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
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('firma_admin', 'bolge_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  INSERT INTO visual_audit_sections (tenant_id, name, description, icon, color)
  VALUES (current_tenant_id(), p_name, p_description, p_icon, p_color)
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$;

-- Şablon oluştur
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
BEGIN
  v_role := current_user_role();
  
  IF v_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  INSERT INTO visual_audit_templates (
    tenant_id, created_by, name, description, section_ids,
    branch_ids, recurrence, scheduled_times, weekly_days,
    monthly_days, deadline_minutes, min_photos
  )
  VALUES (
    current_tenant_id(), current_user_id(), p_name, p_description, p_section_ids,
    p_branch_ids, p_recurrence, p_scheduled_times, p_weekly_days,
    p_monthly_days, p_deadline_minutes, p_min_photos
  )
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$;

-- Günlük görevleri oluştur (cron job ile çağrılacak)
CREATE OR REPLACE FUNCTION generate_visual_audit_tasks_for_date(
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
  v_day_of_week INTEGER;
  v_day_of_month INTEGER;
  v_count INTEGER := 0;
  v_branches UUID[];
BEGIN
  v_day_of_week := EXTRACT(DOW FROM p_date)::INTEGER;
  v_day_of_month := EXTRACT(DAY FROM p_date)::INTEGER;
  
  FOR v_template IN 
    SELECT * FROM visual_audit_templates 
    WHERE is_active = TRUE 
      AND starts_at <= p_date 
      AND (ends_at IS NULL OR ends_at >= p_date)
  LOOP
    -- Tekrar tipine göre kontrol
    CONTINUE WHEN v_template.recurrence = 'weekly' AND NOT (v_day_of_week = ANY(v_template.weekly_days));
    CONTINUE WHEN v_template.recurrence = 'monthly' AND NOT (v_day_of_month = ANY(v_template.monthly_days));
    
    -- Şubeleri belirle
    IF v_template.branch_ids IS NULL OR array_length(v_template.branch_ids, 1) IS NULL THEN
      SELECT ARRAY_AGG(b.id) INTO v_branches 
      FROM branches b 
      WHERE b.tenant_id = v_template.tenant_id AND b.is_active = TRUE;
    ELSE
      v_branches := v_template.branch_ids;
    END IF;
    
    -- Her şube için
    FOREACH v_branch_id IN ARRAY v_branches
    LOOP
      -- Her bölüm için
      FOREACH v_section_id IN ARRAY v_template.section_ids
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
  END LOOP;
  
  RETURN v_count;
END;
$$;

-- Kullanıcının görevlerini getir (mobil için)
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
  -- Kullanıcının şubesini al
  SELECT branch_id INTO v_branch_id FROM users WHERE id = current_user_id();
  
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

-- Fotoğraf yükle
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
  v_min_photos INTEGER;
BEGIN
  -- Görevi al
  SELECT t.*, vt.min_photos INTO v_task
  FROM visual_audit_tasks t
  JOIN visual_audit_templates vt ON vt.id = t.template_id
  WHERE t.id = p_task_id;
  
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
  IF v_photo_count >= v_task.min_photos AND v_task.status NOT IN ('completed', 'approved') THEN
    UPDATE visual_audit_tasks 
    SET status = 'completed', completed_by = current_user_id(), completed_at = now(), updated_at = now()
    WHERE id = p_task_id;
  END IF;
  
  RETURN v_id;
END;
$$;

-- Görev fotoğraflarını getir
CREATE OR REPLACE FUNCTION get_visual_audit_task_photos(
  p_task_id UUID
)
RETURNS TABLE (
  id UUID,
  photo_url TEXT,
  thumbnail_url TEXT,
  caption TEXT,
  uploaded_by UUID,
  uploader_name TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.photo_url,
    p.thumbnail_url,
    p.caption,
    p.uploaded_by,
    CONCAT(u.first_name, ' ', u.last_name) AS uploader_name,
    p.latitude,
    p.longitude,
    p.created_at
  FROM visual_audit_photos p
  JOIN users u ON u.id = p.uploaded_by
  WHERE p.task_id = p_task_id
  ORDER BY p.created_at;
END;
$$;

-- Yorum ekle
CREATE OR REPLACE FUNCTION add_visual_audit_comment(
  p_task_id UUID,
  p_message TEXT,
  p_comment_type visual_audit_comment_type DEFAULT 'comment',
  p_photo_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_task RECORD;
BEGIN
  SELECT * INTO v_task FROM visual_audit_tasks WHERE id = p_task_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı';
  END IF;
  
  INSERT INTO visual_audit_comments (tenant_id, task_id, user_id, comment_type, message, photo_id)
  VALUES (v_task.tenant_id, p_task_id, current_user_id(), p_comment_type, p_message, p_photo_id)
  RETURNING id INTO v_id;
  
  -- Onay/Red durumlarını güncelle
  IF p_comment_type = 'approval' THEN
    UPDATE visual_audit_tasks 
    SET status = 'approved', reviewed_by = current_user_id(), reviewed_at = now(), review_note = p_message, updated_at = now()
    WHERE id = p_task_id;
  ELSIF p_comment_type = 'rejection' OR p_comment_type = 'revision_request' THEN
    UPDATE visual_audit_tasks 
    SET status = 'rejected', reviewed_by = current_user_id(), reviewed_at = now(), review_note = p_message, updated_at = now()
    WHERE id = p_task_id;
  END IF;
  
  RETURN v_id;
END;
$$;

-- Görev yorumlarını getir
CREATE OR REPLACE FUNCTION get_visual_audit_comments(
  p_task_id UUID
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  user_name TEXT,
  user_role TEXT,
  comment_type visual_audit_comment_type,
  message TEXT,
  photo_id UUID,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS user_name,
    u.role::TEXT AS user_role,
    c.comment_type,
    c.message,
    c.photo_id,
    c.created_at
  FROM visual_audit_comments c
  JOIN users u ON u.id = c.user_id
  WHERE c.task_id = p_task_id
  ORDER BY c.created_at;
END;
$$;

-- Yönetici için görev listesi (web panel)
CREATE OR REPLACE FUNCTION get_visual_audit_tasks_for_manager(
  p_date DATE DEFAULT CURRENT_DATE,
  p_branch_id UUID DEFAULT NULL,
  p_section_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  template_name TEXT,
  section_id UUID,
  section_name TEXT,
  section_color TEXT,
  branch_id UUID,
  branch_name TEXT,
  scheduled_date DATE,
  scheduled_time TIME,
  deadline_at TIMESTAMPTZ,
  status visual_audit_task_status,
  photo_count BIGINT,
  min_photos INTEGER,
  completed_by_name TEXT,
  completed_at TIMESTAMPTZ,
  is_overdue BOOLEAN,
  total_count BIGINT
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
  v_role TEXT;
BEGIN
  v_tenant_id := current_tenant_id();
  v_role := current_user_role();
  
  IF v_role NOT IN ('firma_admin', 'bolge_muduru', 'sube_muduru', 'grand_admin') THEN
    RETURN;
  END IF;
  
  RETURN QUERY
  WITH filtered AS (
    SELECT 
      t.id,
      vt.name AS template_name,
      t.section_id,
      s.name AS section_name,
      s.color AS section_color,
      t.branch_id,
      b.name AS branch_name,
      t.scheduled_date,
      t.scheduled_time,
      t.deadline_at,
      t.status,
      COUNT(p.id) AS photo_count,
      vt.min_photos,
      CONCAT(cu.first_name, ' ', cu.last_name) AS completed_by_name,
      t.completed_at,
      (t.deadline_at < now() AND t.status NOT IN ('completed', 'approved')) AS is_overdue
    FROM visual_audit_tasks t
    JOIN visual_audit_templates vt ON vt.id = t.template_id
    JOIN visual_audit_sections s ON s.id = t.section_id
    JOIN branches b ON b.id = t.branch_id
    LEFT JOIN visual_audit_photos p ON p.task_id = t.id
    LEFT JOIN users cu ON cu.id = t.completed_by
    WHERE t.tenant_id = v_tenant_id
      AND (p_date IS NULL OR t.scheduled_date = p_date)
      AND (p_branch_id IS NULL OR t.branch_id = p_branch_id)
      AND (p_section_id IS NULL OR t.section_id = p_section_id)
      AND (p_status IS NULL OR t.status::TEXT = p_status)
    GROUP BY t.id, vt.name, vt.min_photos, s.name, s.color, b.name, cu.first_name, cu.last_name
  )
  SELECT 
    f.*,
    (SELECT COUNT(*) FROM filtered) AS total_count
  FROM filtered f
  ORDER BY f.scheduled_date DESC, f.scheduled_time, f.branch_name
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Şablon listesi (yönetici için)
CREATE OR REPLACE FUNCTION get_visual_audit_templates_list()
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  section_names TEXT[],
  branch_count BIGINT,
  recurrence visual_audit_recurrence,
  scheduled_times TEXT[],
  is_active BOOLEAN,
  created_by_name TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.name,
    t.description,
    ARRAY(
      SELECT s.name FROM visual_audit_sections s 
      WHERE s.id = ANY(t.section_ids) 
      ORDER BY s.display_order
    ) AS section_names,
    CASE 
      WHEN t.branch_ids IS NULL THEN (SELECT COUNT(*) FROM branches b WHERE b.tenant_id = t.tenant_id AND b.is_active = TRUE)
      ELSE array_length(t.branch_ids, 1)::BIGINT
    END AS branch_count,
    t.recurrence,
    t.scheduled_times,
    t.is_active,
    CONCAT(u.first_name, ' ', u.last_name) AS created_by_name,
    t.created_at
  FROM visual_audit_templates t
  JOIN users u ON u.id = t.created_by
  WHERE t.tenant_id = current_tenant_id()
  ORDER BY t.is_active DESC, t.created_at DESC;
END;
$$;

-- Dashboard istatistikleri
CREATE OR REPLACE FUNCTION get_visual_audit_stats(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  total_tasks BIGINT,
  pending_tasks BIGINT,
  completed_tasks BIGINT,
  missed_tasks BIGINT,
  completion_rate NUMERIC
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
BEGIN
  v_tenant_id := current_tenant_id();
  
  RETURN QUERY
  SELECT 
    COUNT(*) AS total_tasks,
    COUNT(*) FILTER (WHERE status = 'pending') AS pending_tasks,
    COUNT(*) FILTER (WHERE status IN ('completed', 'approved')) AS completed_tasks,
    COUNT(*) FILTER (WHERE status = 'missed' OR (deadline_at < now() AND status = 'pending')) AS missed_tasks,
    CASE 
      WHEN COUNT(*) = 0 THEN 0
      ELSE ROUND(COUNT(*) FILTER (WHERE status IN ('completed', 'approved'))::NUMERIC / COUNT(*) * 100, 1)
    END AS completion_rate
  FROM visual_audit_tasks
  WHERE tenant_id = v_tenant_id AND scheduled_date = p_date;
END;
$$;

-- 5. STORAGE BUCKET
-- =====================================================
-- Storage bucket için Supabase Dashboard'dan manuel oluşturulmalı
-- Bucket adı: visual-audits
-- Public: false
-- Allowed MIME types: image/jpeg, image/png, image/webp

-- 6. TRIGGER - updated_at otomatik güncelleme
-- =====================================================

CREATE OR REPLACE FUNCTION update_visual_audit_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER visual_audit_sections_updated_at
  BEFORE UPDATE ON visual_audit_sections
  FOR EACH ROW EXECUTE FUNCTION update_visual_audit_updated_at();

CREATE TRIGGER visual_audit_templates_updated_at
  BEFORE UPDATE ON visual_audit_templates
  FOR EACH ROW EXECUTE FUNCTION update_visual_audit_updated_at();

CREATE TRIGGER visual_audit_tasks_updated_at
  BEFORE UPDATE ON visual_audit_tasks
  FOR EACH ROW EXECUTE FUNCTION update_visual_audit_updated_at();

-- 7. VARSAYILAN BÖLÜMLER (Seed data örneği - opsiyonel)
-- =====================================================
-- Bu kısım firma admin tarafından manuel oluşturulacak
-- Örnek bölümler:
-- INSERT INTO visual_audit_sections (tenant_id, name, icon, color, display_order) VALUES
-- ('tenant-uuid', 'Manav', 'apple', '#22C55E', 1),
-- ('tenant-uuid', 'Şarküteri', 'sandwich', '#F59E0B', 2),
-- ('tenant-uuid', 'Kasap', 'beef', '#EF4444', 3),
-- ('tenant-uuid', 'Unlu Mamüller', 'croissant', '#A855F7', 4),
-- ('tenant-uuid', 'Kasa', 'banknote', '#3B82F6', 5);

COMMENT ON TABLE visual_audit_sections IS 'Görsel denetim bölümleri (Manav, Şarküteri vb.)';
COMMENT ON TABLE visual_audit_templates IS 'Görsel denetim şablonları - hangi bölümler, hangi saatler';
COMMENT ON TABLE visual_audit_tasks IS 'Günlük oluşan görsel denetim görevleri';
COMMENT ON TABLE visual_audit_photos IS 'Yüklenen denetim fotoğrafları';
COMMENT ON TABLE visual_audit_comments IS 'Görev yorumları ve iletişim';
