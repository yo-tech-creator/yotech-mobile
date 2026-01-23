-- Kullanıcıların diğer kullanıcıları görebilmesi için RLS politikası güncelleme
-- Şube müdürü: Kendi şubesindeki personelleri görebilir
-- Bölge müdürü: Yönettiği şubelerdeki personelleri görebilir

-- Mevcut politikayı sil
DROP POLICY IF EXISTS "users_select_self" ON "public"."users";

-- Yeni genişletilmiş politika
CREATE POLICY "users_select_policy" ON "public"."users" FOR SELECT USING (
  -- Service role her şeyi görebilir
  (COALESCE((SELECT auth.role()), 'anon') = 'service_role')
  
  -- Kendi kaydını herkes görebilir
  OR ((SELECT auth.uid()) = id)
  
  -- Aynı tenant içindeki kullanıcıları görebilir (temel erişim)
  OR (
    tenant_id = current_tenant_id()
    AND (
      -- Şube müdürü: Kendi şubesindeki personelleri görebilir
      (
        (SELECT role FROM users WHERE id = auth.uid()) = 'sube_muduru'
        AND branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
      )
      -- Bölge müdürü: Yönettiği şubelerdeki personelleri görebilir
      OR (
        (SELECT role FROM users WHERE id = auth.uid()) = 'bolge_muduru'
        AND branch_id IN (
          SELECT b.id 
          FROM branches b
          INNER JOIN regions r ON r.id = b.region_id
          WHERE r.manager_id = auth.uid() AND r.tenant_id = current_tenant_id()
        )
      )
      -- Firma admin ve grand admin: Tüm tenant kullanıcılarını görebilir
      OR (SELECT role FROM users WHERE id = auth.uid()) IN ('firma_admin', 'grand_admin')
    )
  )
);

-- İndeks ekle (performans için)
CREATE INDEX IF NOT EXISTS idx_users_branch_id ON users(branch_id);
CREATE INDEX IF NOT EXISTS idx_users_tenant_role ON users(tenant_id, role);
