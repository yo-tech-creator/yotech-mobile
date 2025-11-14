-- ============================================
-- EKSİK FUNCTIONS EKLE
-- ============================================

-- 1. app.is_grand_admin() function
CREATE OR REPLACE FUNCTION app.is_grand_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM users 
    WHERE id = auth.uid() 
      AND rol = 'grand_admin'
      AND aktif = true
  );
$$;

-- 2. app.current_user_branch_ids() - kullanıcının erişebileceği şubeler
CREATE OR REPLACE FUNCTION app.current_user_branch_ids()
RETURNS UUID[]
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT CASE
    -- Grand Admin: tüm şubeler
    WHEN app.is_grand_admin() THEN
      ARRAY(SELECT id FROM branches)
    
    -- Firma Admin: tenant'ın tüm şubeleri
    WHEN app.is_firma_admin() THEN
      ARRAY(SELECT id FROM branches WHERE tenant_id = app.current_tenant_id())
    
    -- Bölge Müdürü: bölgesindeki şubeler
    WHEN (SELECT rol FROM users WHERE id = auth.uid()) = 'bolge_muduru' THEN
      ARRAY(
        SELECT b.id 
        FROM branches b
        WHERE b.region_id = (SELECT region_id FROM users WHERE id = auth.uid())
      )
    
    -- Şube Müdürü veya Personel: sadece kendi şubesi
    ELSE
      ARRAY(SELECT branch_id FROM users WHERE id = auth.uid() AND branch_id IS NOT NULL)
  END;
$$;

-- 3. app.is_firma_admin() - zaten var mı kontrol et
CREATE OR REPLACE FUNCTION app.is_firma_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM users 
    WHERE id = auth.uid() 
      AND rol = 'firma_admin'
      AND aktif = true
  );
$$;

-- 4. app.current_tenant_id() - kullanıcının tenant'ı
CREATE OR REPLACE FUNCTION app.current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT tenant_id 
  FROM users 
  WHERE id = auth.uid()
  LIMIT 1;
$$;

-- 5. Test - functionlar çalışıyor mu?
SELECT 
  'is_grand_admin' as function_name,
  app.is_grand_admin() as result
UNION ALL
SELECT 
  'is_firma_admin',
  app.is_firma_admin()
UNION ALL
SELECT 
  'current_tenant_id',
  (app.current_tenant_id())::text
UNION ALL
SELECT 
  'current_user_branch_ids',
  array_length(app.current_user_branch_ids(), 1)::text;
