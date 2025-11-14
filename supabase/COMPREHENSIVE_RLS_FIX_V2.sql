-- ============================================
-- COMPREHENSIVE RLS FIX V2 - ŞEMA UYUMLU
-- ============================================
-- Bu script şemanıza tam uyumlu olacak şekilde düzeltildi
-- ============================================

-- ADIM 1: TÜM ESKİ POLICY'LERİ SİL
-- ============================================

DO $$
DECLARE
  r RECORD;
  v_count INT := 0;
BEGIN
  RAISE NOTICE '=== ESKİ POLICY''LERİ SİLİYOR ===';
  
  FOR r IN 
    SELECT schemaname, tablename, policyname 
    FROM pg_policies 
    WHERE schemaname = 'public'
    ORDER BY tablename, policyname
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', 
      r.policyname, r.schemaname, r.tablename);
    v_count := v_count + 1;
  END LOOP;
  
  RAISE NOTICE 'Toplam % policy silindi!', v_count;
  RAISE NOTICE '';
END $$;

-- ADIM 2: HELPER FUNCTIONS (eksik varsa ekle)
-- ============================================

CREATE OR REPLACE FUNCTION app.is_grand_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM users 
    WHERE id = (SELECT auth.uid())
      AND rol = 'grand_admin'
      AND aktif = true
  );
$$;

CREATE OR REPLACE FUNCTION app.is_firma_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 
    FROM users 
    WHERE id = (SELECT auth.uid())
      AND rol = 'firma_admin'
      AND aktif = true
  );
$$;

CREATE OR REPLACE FUNCTION app.current_tenant_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT tenant_id 
  FROM users 
  WHERE id = (SELECT auth.uid())
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION app.current_user_branch_ids()
RETURNS UUID[]
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT CASE
    -- Grand Admin: tüm şubeler
    WHEN (SELECT app.is_grand_admin()) THEN
      ARRAY(SELECT id FROM branches)
    
    -- Firma Admin: tenant'ın tüm şubeleri
    WHEN (SELECT app.is_firma_admin()) THEN
      ARRAY(SELECT id FROM branches WHERE tenant_id = (SELECT app.current_tenant_id()))
    
    -- Bölge Müdürü: bölgesindeki şubeler
    WHEN (SELECT rol FROM users WHERE id = (SELECT auth.uid())) = 'bolge_muduru' THEN
      ARRAY(
        SELECT b.id 
        FROM branches b
        WHERE b.region_id = (SELECT region_id FROM users WHERE id = (SELECT auth.uid()))
      )
    
    -- Şube Müdürü veya Personel: sadece kendi şubesi
    ELSE
      ARRAY(SELECT branch_id FROM users WHERE id = (SELECT auth.uid()) AND branch_id IS NOT NULL)
  END;
$$;

DO $$
BEGIN
  RAISE NOTICE '=== HELPER FUNCTIONS OLUŞTURULDU ===';
  RAISE NOTICE '';
END $$;

-- ADIM 3: OPTİMİZE EDİLMİŞ RLS POLICY'LERİ
-- ============================================

-- TENANTS (branch_id YOK)
-- ============================================
CREATE POLICY rls_tenants ON tenants
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR id = (SELECT app.current_tenant_id())
);

-- REGIONS (branch_id YOK)
-- ============================================
CREATE POLICY rls_regions ON regions
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR tenant_id = (SELECT app.current_tenant_id())
);

-- BRANCHES (branch_id YOK, kendi ID'si var)
-- ============================================
CREATE POLICY rls_branches ON branches
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- USERS (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_users ON users
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND (branch_id = ANY((SELECT app.current_user_branch_ids())) OR id = (SELECT auth.uid())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR id = (SELECT auth.uid())
);

-- PRODUCTS (branch_id YOK)
-- ============================================
CREATE POLICY rls_products ON products
FOR ALL TO authenticated, anon, authenticator, cli_login_postgres, dashboard_user
USING (
  (SELECT app.is_grand_admin())
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- SKT_RECORDS (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_skt_records ON skt_records
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
);

-- ATTENDANCE (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_attendance ON attendance
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
);

-- SHIFTS (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_shifts ON shifts
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
);

-- ANNOUNCEMENTS (branch_id YOK)
-- ============================================
CREATE POLICY rls_announcements ON announcements
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- ANNOUNCEMENT_READS (tenant_id YOK, sadece user_id)
-- ============================================
CREATE POLICY rls_announcement_reads ON announcement_reads
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR user_id = (SELECT auth.uid())
)
WITH CHECK (
  user_id = (SELECT auth.uid())
);

-- NOTIFICATIONS (branch_id YOK, user_id VAR)
-- ============================================
CREATE POLICY rls_notifications ON notifications
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR user_id = (SELECT auth.uid())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR user_id = (SELECT auth.uid())
);

-- TASKS (branch_id YOK, sadece tenant_id)
-- ============================================
CREATE POLICY rls_tasks ON tasks
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- TASK_ASSIGNEES (tenant_id YOK, user_id VAR)
-- ============================================
CREATE POLICY rls_task_assignees ON task_assignees
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR user_id = (SELECT auth.uid())
  OR EXISTS (
    SELECT 1 FROM tasks 
    WHERE tasks.id = task_assignees.task_id 
      AND (
        (SELECT app.is_firma_admin()) 
        OR tasks.tenant_id = (SELECT app.current_tenant_id())
      )
  )
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR EXISTS (
    SELECT 1 FROM tasks 
    WHERE tasks.id = task_assignees.task_id 
      AND (SELECT app.is_firma_admin())
  )
);

-- TASK_ITEMS (tenant_id YOK)
-- ============================================
CREATE POLICY rls_task_items ON task_items
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR EXISTS (
    SELECT 1 FROM tasks 
    WHERE tasks.id = task_items.task_id 
      AND (
        (SELECT app.is_firma_admin()) 
        OR tasks.tenant_id = (SELECT app.current_tenant_id())
      )
  )
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR EXISTS (
    SELECT 1 FROM tasks 
    WHERE tasks.id = task_items.task_id 
      AND (SELECT app.is_firma_admin())
  )
);

-- LEAVE_REQUESTS (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_leave_requests ON leave_requests
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
);

-- BREAK_LOGS (branch_id YOK, user_id VAR)
-- ============================================
CREATE POLICY rls_break_logs ON break_logs
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
);

-- STOCKOUT_LISTS (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_stockout_lists ON stockout_lists
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
);

-- STOCKOUT_ITEMS (branch_id YOK, stockout_lists üzerinden)
-- ============================================
CREATE POLICY rls_stockout_items ON stockout_items
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR EXISTS (
    SELECT 1 FROM stockout_lists 
    WHERE stockout_lists.id = stockout_items.stockout_list_id 
      AND (
        (SELECT app.is_firma_admin()) 
        OR (stockout_lists.tenant_id = (SELECT app.current_tenant_id())
            AND stockout_lists.branch_id = ANY((SELECT app.current_user_branch_ids())))
      )
  )
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR EXISTS (
    SELECT 1 FROM stockout_lists 
    WHERE stockout_lists.id = stockout_items.stockout_list_id 
      AND (SELECT app.is_firma_admin())
  )
);

-- INVENTORY_TRANSFERS (gonderici_branch_id, alici_branch_id VAR)
-- ============================================
CREATE POLICY rls_inventory_transfers ON inventory_transfers
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND (gonderici_branch_id = ANY((SELECT app.current_user_branch_ids()))
           OR alici_branch_id = ANY((SELECT app.current_user_branch_ids()))))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND gonderici_branch_id = ANY((SELECT app.current_user_branch_ids())))
);

-- FORM_TEMPLATES (branch_id YOK)
-- ============================================
CREATE POLICY rls_form_templates ON form_templates
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- FORM_SUBMISSIONS (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_form_submissions ON form_submissions
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
);

-- PRODUCT_ISSUES (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_product_issues ON product_issues
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
);

-- HEALTH_REPORTS (branch_id YOK, user_id VAR)
-- ============================================
CREATE POLICY rls_health_reports ON health_reports
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
  OR tenant_id = (SELECT app.current_tenant_id())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
);

-- MALFUNCTION_REPORTS (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_malfunction_reports ON malfunction_reports
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
);

-- PAYROLLS (branch_id YOK, user_id VAR)
-- ============================================
CREATE POLICY rls_payrolls ON payrolls
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- BRANCH_SCORES (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_branch_scores ON branch_scores
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- EMPLOYEE_SCORES (branch_id VAR ✓)
-- ============================================
CREATE POLICY rls_employee_scores ON employee_scores
FOR ALL TO authenticated
USING (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
  OR user_id = (SELECT auth.uid())
  OR (tenant_id = (SELECT app.current_tenant_id()) 
      AND branch_id = ANY((SELECT app.current_user_branch_ids())))
)
WITH CHECK (
  (SELECT app.is_grand_admin())
  OR ((SELECT app.is_firma_admin()) AND tenant_id = (SELECT app.current_tenant_id()))
);

-- ============================================
-- FINAL KONTROL
-- ============================================

DO $$
DECLARE
  r RECORD;
  v_policy_count INT;
  v_duplicate_count INT;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '=== SONUÇ RAPORU ===';
  RAISE NOTICE '';
  
  SELECT COUNT(*) INTO v_policy_count
  FROM pg_policies
  WHERE schemaname = 'public';
  
  RAISE NOTICE 'Toplam Policy Sayısı: %', v_policy_count;
  
  SELECT COUNT(*) INTO v_duplicate_count
  FROM (
    SELECT tablename, cmd, COUNT(*) as cnt
    FROM pg_policies
    WHERE schemaname = 'public'
      AND cmd != 'ALL'
    GROUP BY tablename, cmd
    HAVING COUNT(*) > 1
  ) t;
  
  RAISE NOTICE 'Duplicate Policy Sayısı: %', v_duplicate_count;
  RAISE NOTICE '';
  
  IF v_duplicate_count > 0 THEN
    RAISE NOTICE '⚠️  UYARI: Hala duplicate policy''ler var!';
  ELSE
    RAISE NOTICE '✅ BAŞARILI: Duplicate policy yok!';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE 'Her tablo için policy listesi:';
  RAISE NOTICE '';
  
  FOR r IN 
    SELECT tablename, COUNT(*) as policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
    GROUP BY tablename
    ORDER BY tablename
  LOOP
    RAISE NOTICE '  % : % policy', rpad(r.tablename, 30), r.policy_count;
  END LOOP;
  
  RAISE NOTICE '';
  RAISE NOTICE '=== TÜM İŞLEMLER TAMAMLANDI ===';
END $$;
