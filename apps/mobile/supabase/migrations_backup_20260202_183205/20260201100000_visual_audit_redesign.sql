-- ============================================
-- GÖRSEL DENETİM SİSTEMİ - YENİDEN TASARIM
-- ============================================
-- 1. Anlık Görev: Yönetici anında tek seferlik görev oluşturur
-- 2. Şablon: Periyodik görevler, otomatik oluşur (trigger ile)

-- ============================================
-- 0. TABLO KOLONLARI (ÖNCELİKLİ)
-- ============================================
DO $$
BEGIN
  -- min_photos kolonu (zorunlu fotoğraf sayısı)
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'visual_audit_tasks' AND column_name = 'min_photos') THEN
    ALTER TABLE visual_audit_tasks ADD COLUMN min_photos INTEGER NOT NULL DEFAULT 1;
  END IF;
  
  -- Görevi oluşturan kişi
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'visual_audit_tasks' AND column_name = 'created_by') THEN
    ALTER TABLE visual_audit_tasks ADD COLUMN created_by UUID REFERENCES users(id);
  END IF;
  
  -- Görev notu
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_name = 'visual_audit_tasks' AND column_name = 'notes') THEN
    ALTER TABLE visual_audit_tasks ADD COLUMN notes TEXT;
  END IF;
  
  -- template_id NULL olabilir (anlık görevler için)
  ALTER TABLE visual_audit_tasks ALTER COLUMN template_id DROP NOT NULL;
END $$;

-- Anlık görevler için yeni unique index (template_id NULL olanlar için)
-- Şablon görevleri mevcut constraint ile korunuyor
CREATE UNIQUE INDEX IF NOT EXISTS idx_visual_audit_tasks_instant_unique 
  ON visual_audit_tasks(branch_id, section_id, scheduled_date, scheduled_time) 
  WHERE template_id IS NULL;

-- ============================================
-- 1. ANLIK GÖREV OLUŞTURMA FONKSİYONU
-- ============================================
-- Yönetici seçtiği şubelere, seçtiği bölümler için anında görev oluşturur

CREATE OR REPLACE FUNCTION create_instant_visual_audit_task(
  p_branch_ids UUID[],
  p_section_ids UUID[],
  p_deadline_minutes INTEGER DEFAULT 60,
  p_min_photos INTEGER DEFAULT 1,
  p_note TEXT DEFAULT NULL
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
  v_role := current_user_role();
  v_user_id := current_user_id();
  
  IF v_role NOT IN ('grand_admin', 'firma_admin', 'bolge_muduru', 'sube_muduru') THEN
    RAISE EXCEPTION 'Yetkiniz yok';
  END IF;
  
  IF v_role = 'grand_admin' THEN
    SELECT id INTO v_tenant_id FROM tenants LIMIT 1;
  ELSE
    v_tenant_id := current_tenant_id();
  END IF;
  
  -- Bölüm kontrolü
  IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'En az bir bölüm seçmelisiniz';
  END IF;
  
  -- Şube listesi boşsa, yetki dahilindeki şubeleri al
  IF p_branch_ids IS NULL OR array_length(p_branch_ids, 1) IS NULL THEN
    IF v_role = 'sube_muduru' THEN
      -- Şube müdürü sadece kendi şubesine görev oluşturabilir
      SELECT branch_id INTO v_actual_branch_ids[1] FROM users WHERE id = v_user_id;
      v_actual_branch_ids := ARRAY[v_actual_branch_ids[1]];
    ELSE
      -- Diğer yöneticiler tüm şubelere
      SELECT array_agg(id) INTO v_actual_branch_ids
      FROM branches
      WHERE tenant_id = v_tenant_id AND active = true;
    END IF;
  ELSE
    v_actual_branch_ids := p_branch_ids;
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
        template_id,  -- NULL for instant tasks
        branch_id, 
        section_id,
        scheduled_date, 
        scheduled_time, 
        deadline_at,
        min_photos,
        notes,
        created_by
      )
      VALUES (
        v_tenant_id, 
        NULL,  -- Anlık görev, şablon yok
        v_branch_id, 
        v_section_id,
        CURRENT_DATE, 
        CURRENT_TIME,
        NOW() + (p_deadline_minutes || ' minutes')::INTERVAL,
        p_min_photos,
        p_note,
        v_user_id
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
-- 2. ŞABLON OLUŞTURULDUĞUNDA OTOMATİK GÖREV
-- ============================================
-- Şablon oluşturulduğunda bugün için görevleri hemen oluştur

CREATE OR REPLACE FUNCTION trigger_generate_tasks_on_template_create()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_branch_id UUID;
  v_section_id UUID;
  v_time TEXT;
  v_branches UUID[];
  v_sections UUID[];
  v_day_of_week INTEGER;
  v_should_create BOOLEAN := FALSE;
BEGIN
  -- Bugün için görev oluşturulmalı mı kontrol et
  v_day_of_week := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
  
  IF NEW.recurrence = 'daily' THEN
    v_should_create := TRUE;
  ELSIF NEW.recurrence = 'weekly' AND NEW.weekly_days IS NOT NULL THEN
    v_should_create := v_day_of_week = ANY(NEW.weekly_days);
  ELSIF NEW.recurrence = 'monthly' AND NEW.monthly_days IS NOT NULL THEN
    v_should_create := EXTRACT(DAY FROM CURRENT_DATE)::INTEGER = ANY(NEW.monthly_days);
  END IF;
  
  IF NOT v_should_create THEN
    RETURN NEW;
  END IF;
  
  -- Bölümleri al (relational table'dan)
  SELECT ARRAY_AGG(ts.section_id) INTO v_sections
  FROM visual_audit_template_sections ts
  WHERE ts.template_id = NEW.id;
  
  -- Şubeleri al (relational table'dan)
  SELECT ARRAY_AGG(tb.branch_id) INTO v_branches
  FROM visual_audit_template_branches tb
  WHERE tb.template_id = NEW.id;
  
  -- Şube yoksa tüm aktif şubeleri al
  IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
    SELECT ARRAY_AGG(b.id) INTO v_branches
    FROM branches b
    WHERE b.tenant_id = NEW.tenant_id AND b.active = true;
  END IF;
  
  -- Bölüm yoksa çık
  IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Görevleri oluştur
  IF v_branches IS NOT NULL THEN
    FOREACH v_branch_id IN ARRAY v_branches
    LOOP
      FOREACH v_section_id IN ARRAY v_sections
      LOOP
        FOREACH v_time IN ARRAY NEW.scheduled_times
        LOOP
          INSERT INTO visual_audit_tasks (
            tenant_id, template_id, branch_id, section_id,
            scheduled_date, scheduled_time, deadline_at, min_photos
          )
          VALUES (
            NEW.tenant_id, NEW.id, v_branch_id, v_section_id,
            CURRENT_DATE, v_time::TIME,
            (CURRENT_DATE + v_time::TIME) + (NEW.deadline_minutes || ' minutes')::INTERVAL,
            NEW.min_photos
          )
          ON CONFLICT (template_id, branch_id, section_id, scheduled_date, scheduled_time) DO NOTHING;
        END LOOP;
      END LOOP;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Trigger'ı oluştur (varsa önce sil)
DROP TRIGGER IF EXISTS trg_generate_tasks_on_template_create ON visual_audit_templates;

-- NOT: Trigger INSERT sonrasında çalışmalı çünkü ilişkisel tablolar henüz dolmamış olabilir
-- Bu yüzden create_visual_audit_template fonksiyonunun sonuna görev oluşturmayı ekliyoruz

-- ============================================
-- 3. ŞABLON OLUŞTURMA FONKSİYONUNU GÜNCELLE
-- ============================================
-- Şablon oluşturulduktan sonra bugün için görevleri otomatik oluştur

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
  v_time TEXT;
  v_day_of_week INTEGER;
  v_should_create_today BOOLEAN := FALSE;
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
  
  -- section_ids kontrolü
  IF p_section_ids IS NULL OR array_length(p_section_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'En az bir bölüm seçmelisiniz';
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
  
  -- ============================================
  -- BUGÜN İÇİN GÖREVLERİ OTOMATİK OLUŞTUR
  -- ============================================
  v_day_of_week := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
  
  IF p_recurrence = 'daily' THEN
    v_should_create_today := TRUE;
  ELSIF p_recurrence = 'weekly' AND p_weekly_days IS NOT NULL THEN
    v_should_create_today := v_day_of_week = ANY(p_weekly_days);
  ELSIF p_recurrence = 'monthly' AND p_monthly_days IS NOT NULL THEN
    v_should_create_today := EXTRACT(DAY FROM CURRENT_DATE)::INTEGER = ANY(p_monthly_days);
  END IF;
  
  IF v_should_create_today AND v_actual_branch_ids IS NOT NULL THEN
    FOREACH v_branch_id IN ARRAY v_actual_branch_ids
    LOOP
      FOREACH v_section_id IN ARRAY p_section_ids
      LOOP
        FOREACH v_time IN ARRAY p_scheduled_times
        LOOP
          INSERT INTO visual_audit_tasks (
            tenant_id, template_id, branch_id, section_id,
            scheduled_date, scheduled_time, deadline_at, min_photos
          )
          VALUES (
            v_tenant_id, v_id, v_branch_id, v_section_id,
            CURRENT_DATE, v_time::TIME,
            (CURRENT_DATE + v_time::TIME) + (p_deadline_minutes || ' minutes')::INTERVAL,
            p_min_photos
          )
          ON CONFLICT (template_id, branch_id, section_id, scheduled_date, scheduled_time) DO NOTHING;
        END LOOP;
      END LOOP;
    END LOOP;
  END IF;
  
  RETURN v_id;
END;
$$;

-- ============================================
-- 4. GÜNLÜK OTOMATİK GÖREV OLUŞTURMA
-- ============================================
-- Bu fonksiyon her gün çalıştırılmalı (cron job veya pg_cron ile)
-- Veya uygulama başlangıcında çağrılabilir

CREATE OR REPLACE FUNCTION generate_daily_visual_audit_tasks()
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
  v_sections UUID[];
BEGIN
  v_day_of_week := EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
  v_day_of_month := EXTRACT(DAY FROM CURRENT_DATE)::INTEGER;
  
  FOR v_template IN 
    SELECT * FROM visual_audit_templates 
    WHERE is_active = TRUE 
      AND starts_at <= CURRENT_DATE 
      AND (ends_at IS NULL OR ends_at >= CURRENT_DATE)
  LOOP
    -- Tekrar tipine göre kontrol
    CONTINUE WHEN v_template.recurrence = 'weekly' AND NOT (v_day_of_week = ANY(v_template.weekly_days));
    CONTINUE WHEN v_template.recurrence = 'monthly' AND v_template.monthly_days IS NOT NULL AND NOT (v_day_of_month = ANY(v_template.monthly_days));
    
    -- Şubeleri al
    SELECT ARRAY_AGG(tb.branch_id) INTO v_branches
    FROM visual_audit_template_branches tb
    WHERE tb.template_id = v_template.id;
    
    IF v_branches IS NULL OR array_length(v_branches, 1) IS NULL THEN
      SELECT ARRAY_AGG(b.id) INTO v_branches 
      FROM branches b 
      WHERE b.tenant_id = v_template.tenant_id AND b.active = TRUE;
    END IF;
    
    -- Bölümleri al
    SELECT ARRAY_AGG(ts.section_id) INTO v_sections
    FROM visual_audit_template_sections ts
    WHERE ts.template_id = v_template.id;
    
    IF v_sections IS NULL OR array_length(v_sections, 1) IS NULL THEN
      CONTINUE;
    END IF;
    
    -- Görevleri oluştur
    IF v_branches IS NOT NULL THEN
      FOREACH v_branch_id IN ARRAY v_branches
      LOOP
        FOREACH v_section_id IN ARRAY v_sections
        LOOP
          FOREACH v_time IN ARRAY v_template.scheduled_times
          LOOP
            INSERT INTO visual_audit_tasks (
              tenant_id, template_id, branch_id, section_id,
              scheduled_date, scheduled_time, deadline_at, min_photos
            )
            VALUES (
              v_template.tenant_id, v_template.id, v_branch_id, v_section_id,
              CURRENT_DATE, v_time::TIME,
              (CURRENT_DATE + v_time::TIME) + (v_template.deadline_minutes || ' minutes')::INTERVAL,
              v_template.min_photos
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

-- ============================================
-- 5. GRANT EXECUTE
-- ============================================
GRANT EXECUTE ON FUNCTION create_instant_visual_audit_task(UUID[], UUID[], INTEGER, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_daily_visual_audit_tasks() TO authenticated;

-- Bugün için şablonlardan görevleri oluştur
SELECT generate_daily_visual_audit_tasks();
