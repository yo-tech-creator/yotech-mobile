-- =====================================================
-- FIX: store_scoring_sessions INSERT RLS policy
-- Sorun: Personel rolündeki kullanıcılar form dolduramıyor
-- =====================================================

-- Önce mevcut politikaları temizle
DROP POLICY IF EXISTS "scoring_sessions_insert" ON "public"."store_scoring_sessions";
DROP POLICY IF EXISTS "tenant scoring sessions insert" ON "public"."store_scoring_sessions";
DROP POLICY IF EXISTS "store_scoring_sessions_insert_v2" ON "public"."store_scoring_sessions";
DROP POLICY IF EXISTS "store_scoring_sessions_insert" ON "public"."store_scoring_sessions";

-- Basit ve çalışan INSERT politikası oluştur
-- Authenticated kullanıcılar kendi tenant'larındaki formları doldurabilir
CREATE POLICY "store_scoring_sessions_insert_policy" ON "public"."store_scoring_sessions"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Kullanıcı kendi adına kayıt oluşturmalı
    evaluator_id = auth.uid()
    AND
    -- Şube kullanıcının tenant'ına ait olmalı
    EXISTS (
      SELECT 1 FROM branches b
      WHERE b.id = branch_id
      AND b.tenant_id = current_tenant_id()
    )
    AND
    -- Form versiyonu kullanıcının tenant'ına ait olmalı
    EXISTS (
      SELECT 1 
      FROM store_scoring_form_versions v
      JOIN store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = form_version_id
      AND f.tenant_id = current_tenant_id()
    )
  );

-- store_scoring_session_items için de INSERT politikası ekle
DROP POLICY IF EXISTS "scoring_session_items_insert" ON "public"."store_scoring_session_items";
DROP POLICY IF EXISTS "store_scoring_session_items_insert_policy" ON "public"."store_scoring_session_items";

CREATE POLICY "store_scoring_session_items_insert_policy" ON "public"."store_scoring_session_items"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- Session kullanıcıya ait olmalı
    EXISTS (
      SELECT 1 FROM store_scoring_sessions s
      WHERE s.id = session_id
      AND s.evaluator_id = auth.uid()
    )
  );

-- Comment ekle
COMMENT ON POLICY "store_scoring_sessions_insert_policy" ON "public"."store_scoring_sessions" IS 
'Authenticated kullanıcılar kendi tenant''larındaki formları kendi adlarına doldurabilir';

COMMENT ON POLICY "store_scoring_session_items_insert_policy" ON "public"."store_scoring_session_items" IS 
'Kullanıcılar kendi oluşturdukları session''lara item ekleyebilir';
