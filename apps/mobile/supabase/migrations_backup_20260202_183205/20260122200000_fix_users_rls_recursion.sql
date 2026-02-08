-- Sonsuz döngü sorununu çözmek için SECURITY DEFINER helper fonksiyonları

-- Önce hatalı politikayı kaldır
DROP POLICY IF EXISTS "users_select_policy" ON "public"."users";

-- Kullanıcının rolünü döndüren helper fonksiyon (RLS'i bypass eder)
CREATE OR REPLACE FUNCTION get_my_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role::TEXT FROM users WHERE id = auth.uid();
$$;

-- Kullanıcının branch_id'sini döndüren helper fonksiyon
CREATE OR REPLACE FUNCTION get_my_branch_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT branch_id FROM users WHERE id = auth.uid();
$$;

-- Bölge müdürünün yönettiği şubeleri döndüren helper fonksiyon
CREATE OR REPLACE FUNCTION get_my_managed_branch_ids()
RETURNS SETOF UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT b.id 
  FROM branches b
  INNER JOIN regions r ON r.id = b.region_id
  WHERE r.manager_id = auth.uid() AND r.tenant_id = current_tenant_id();
$$;

-- Yeni basitleştirilmiş politika
CREATE POLICY "users_select_policy" ON "public"."users" FOR SELECT USING (
  -- Service role her şeyi görebilir
  (COALESCE((SELECT auth.role()), 'anon') = 'service_role')
  
  -- Kendi kaydını herkes görebilir
  OR ((SELECT auth.uid()) = id)
  
  -- Aynı tenant içinde rol bazlı erişim
  OR (
    tenant_id = current_tenant_id()
    AND (
      -- Şube müdürü: Kendi şubesindeki personelleri görebilir
      (get_my_role() = 'sube_muduru' AND branch_id = get_my_branch_id())
      -- Bölge müdürü: Yönettiği şubelerdeki personelleri görebilir
      OR (get_my_role() = 'bolge_muduru' AND branch_id IN (SELECT get_my_managed_branch_ids()))
      -- Firma admin ve grand admin: Tüm tenant kullanıcılarını görebilir
      OR get_my_role() IN ('firma_admin', 'grand_admin')
    )
  )
);
