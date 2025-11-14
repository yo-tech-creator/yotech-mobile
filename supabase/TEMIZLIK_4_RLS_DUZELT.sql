-- ============================================
-- RLS POLİCY'LERİ DÜZELT - ŞUBELER BİRBİRİNİ GÖRMEMEL İ!
-- ============================================

-- ÖNEMLI: Bu script'i çalıştırmadan önce:
-- 1. ESKİ_RLS_SIL.sql çalıştır
-- 2. FUNCTIONS_EKLE.sql çalıştır
-- 3. Bu script'i çalıştır

-- ============================================
-- SKT_RECORDS TABLOSU - ÇOK ÖNEMLİ!
-- ============================================

-- Mevcut policy'leri kontrol et
SELECT policyname FROM pg_policies WHERE tablename = 'skt_records';

-- Yeni policy'ler oluştur (eski zaten silindi)
DROP POLICY IF EXISTS rls_sel_skt_records ON skt_records;
DROP POLICY IF EXISTS rls_ins_skt_records ON skt_records;
DROP POLICY IF EXISTS rls_upd_skt_records ON skt_records;
DROP POLICY IF EXISTS rls_del_skt_records ON skt_records;

-- SELECT: Sadece kendi tenant + kendi branch erişimi
CREATE POLICY rls_sel_skt_records ON skt_records
FOR SELECT
TO authenticated
USING (
  -- Grand Admin: her şeyi görebilir
  app.is_grand_admin()
  OR
  -- Firma Admin: kendi tenant'ının her şeyini görebilir
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  -- Diğerleri: sadece kendi branch'leri
  (tenant_id = app.current_tenant_id() 
   AND branch_id = ANY(app.current_user_branch_ids()))
);

-- INSERT: Sadece kendi tenant + kendi branch'e ekleyebilir
CREATE POLICY rls_ins_skt_records ON skt_records
FOR INSERT
TO authenticated
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  (tenant_id = app.current_tenant_id() 
   AND branch_id = ANY(app.current_user_branch_ids()))
);

-- UPDATE: Sadece kendi tenant + kendi branch güncelleyebilir
CREATE POLICY rls_upd_skt_records ON skt_records
FOR UPDATE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  (tenant_id = app.current_tenant_id() 
   AND branch_id = ANY(app.current_user_branch_ids()))
)
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  (tenant_id = app.current_tenant_id() 
   AND branch_id = ANY(app.current_user_branch_ids()))
);

-- DELETE: Sadece kendi tenant + kendi branch silebilir
CREATE POLICY rls_del_skt_records ON skt_records
FOR DELETE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  (tenant_id = app.current_tenant_id() 
   AND branch_id = ANY(app.current_user_branch_ids()))
);

-- ============================================
-- USERS TABLOSU
-- ============================================

DROP POLICY IF EXISTS rls_sel_users ON users;
DROP POLICY IF EXISTS rls_ins_users ON users;
DROP POLICY IF EXISTS rls_upd_users ON users;
DROP POLICY IF EXISTS rls_del_users ON users;

-- SELECT: Sadece kendi tenant + kendi branch personelleri
CREATE POLICY rls_sel_users ON users
FOR SELECT
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  (tenant_id = app.current_tenant_id() 
   AND (branch_id = ANY(app.current_user_branch_ids()) OR id = auth.uid()))
);

-- INSERT: Firma Admin veya Grand Admin
CREATE POLICY rls_ins_users ON users
FOR INSERT
TO authenticated
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

-- UPDATE: Kendi bilgilerini veya yetkisi olanlar
CREATE POLICY rls_upd_users ON users
FOR UPDATE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  id = auth.uid() -- Herkes kendi bilgisini güncelleyebilir
)
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
  OR
  id = auth.uid()
);

-- DELETE: Sadece yetkili olanlar
CREATE POLICY rls_del_users ON users
FOR DELETE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

-- ============================================
-- BRANCHES TABLOSU
-- ============================================

DROP POLICY IF EXISTS rls_sel_branches ON branches;
DROP POLICY IF EXISTS rls_ins_branches ON branches;
DROP POLICY IF EXISTS rls_upd_branches ON branches;
DROP POLICY IF EXISTS rls_del_branches ON branches;

-- SELECT: Sadece kendi tenant'ın şubeleri
CREATE POLICY rls_sel_branches ON branches
FOR SELECT
TO authenticated
USING (
  app.is_grand_admin()
  OR
  tenant_id = app.current_tenant_id()
);

-- INSERT: Firma Admin veya Grand Admin
CREATE POLICY rls_ins_branches ON branches
FOR INSERT
TO authenticated
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

-- UPDATE: Firma Admin veya Grand Admin
CREATE POLICY rls_upd_branches ON branches
FOR UPDATE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
)
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

-- DELETE: Sadece yetkili olanlar
CREATE POLICY rls_del_branches ON branches
FOR DELETE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

-- ============================================
-- PRODUCTS TABLOSU
-- ============================================

DROP POLICY IF EXISTS rls_sel_products ON products;
DROP POLICY IF EXISTS rls_ins_products ON products;
DROP POLICY IF EXISTS rls_upd_products ON products;
DROP POLICY IF EXISTS rls_del_products ON products;

-- SELECT: Sadece kendi tenant'ın ürünleri
CREATE POLICY rls_sel_products ON products
FOR SELECT
TO authenticated
USING (
  app.is_grand_admin()
  OR
  tenant_id = app.current_tenant_id()
);

-- INSERT, UPDATE, DELETE: Firma Admin veya Grand Admin
CREATE POLICY rls_ins_products ON products
FOR INSERT
TO authenticated
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

CREATE POLICY rls_upd_products ON products
FOR UPDATE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
)
WITH CHECK (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

CREATE POLICY rls_del_products ON products
FOR DELETE
TO authenticated
USING (
  app.is_grand_admin()
  OR
  (app.is_firma_admin() AND tenant_id = app.current_tenant_id())
);

-- ============================================
-- KONTROL - RLS'LERİ LİSTELE
-- ============================================

SELECT 
  tablename,
  policyname,
  cmd,
  CASE 
    WHEN policyname LIKE 'rls_%' THEN '✅ YENİ'
    ELSE '❌ ESKİ'
  END as durum
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('skt_records', 'users', 'branches', 'products')
ORDER BY tablename, cmd, policyname;
