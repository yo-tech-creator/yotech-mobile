-- RLS/performance cleanup: reduce multiple permissive policies and remove per-row auth.<fn> calls
-- Tables: tenants, form_submissions, announcements, store_scoring_forms/form_versions/items/sections/sessions/session_items

-- ========== tenants ==========
DROP POLICY IF EXISTS "tenants_select_all" ON public.tenants;
CREATE POLICY "tenants_select_all" ON public.tenants
FOR SELECT USING (
  public.current_user_role() = 'grand_admin'
  OR public.is_service_role()
  OR id = public.current_tenant_id()
);

-- ========== form_submissions ==========
-- Drop old overlapping select policies
DROP POLICY IF EXISTS "Users can view their own submissions" ON public.form_submissions;
DROP POLICY IF EXISTS "Branch managers can view their branch submissions" ON public.form_submissions;
DROP POLICY IF EXISTS "Tenant admin can view all submissions" ON public.form_submissions;
DROP POLICY IF EXISTS "form_submissions_all" ON public.form_submissions;
DROP POLICY IF EXISTS "submissions select" ON public.form_submissions;

-- Single consolidated select policy (authenticated)
CREATE POLICY "form_submissions_select" ON public.form_submissions
FOR SELECT TO authenticated USING (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND (
        u.role = 'grand_admin'
        OR (
          u.tenant_id = form_submissions.tenant_id AND (
            u.role = 'firma_admin'
            OR (
              u.role IN ('bolge_muduru','sube_muduru')
              AND (
                u.branch_id = form_submissions.branch_id
                OR EXISTS (
                  SELECT 1 FROM public.branches b
                  JOIN public.regions r ON r.id = b.region_id
                  WHERE b.id = form_submissions.branch_id
                    AND r.manager_id = u.id
                    AND r.tenant_id = u.tenant_id
                )
              )
            )
            OR (u.role = 'personel' AND u.id = form_submissions.user_id)
          )
        )
      )
  )
);

-- ========== announcements ==========
-- Remove select duplication; keep audience read for SELECT, admin for write-only
DROP POLICY IF EXISTS "announcements_admin_write" ON public.announcements;
CREATE POLICY "announcements_admin_write" ON public.announcements
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND ctx.role IN ('grand_admin', 'firma_admin', 'bolge_muduru')
    ) OR public.is_service_role()
  );

DROP POLICY IF EXISTS "announcements_admin_write_update" ON public.announcements;
CREATE POLICY "announcements_admin_write_update" ON public.announcements
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND ctx.role IN ('grand_admin', 'firma_admin', 'bolge_muduru')
    ) OR public.is_service_role()
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND ctx.role IN ('grand_admin', 'firma_admin', 'bolge_muduru')
    ) OR public.is_service_role()
  );

DROP POLICY IF EXISTS "announcements_admin_write_delete" ON public.announcements;
CREATE POLICY "announcements_admin_write_delete" ON public.announcements
  FOR DELETE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND ctx.role IN ('grand_admin', 'firma_admin', 'bolge_muduru')
    ) OR public.is_service_role()
  );

-- keep announcements_audience_read + announcements_service_all from prior migration for SELECT

-- ========== store_scoring_form_versions ==========
DROP POLICY IF EXISTS "form versions select" ON public.store_scoring_form_versions;
DROP POLICY IF EXISTS "form versions select by user tenant" ON public.store_scoring_form_versions;
DROP POLICY IF EXISTS "tenant form versions select" ON public.store_scoring_form_versions;
DROP POLICY IF EXISTS "store_form_versions_select" ON public.store_scoring_form_versions;
DROP POLICY IF EXISTS "store_form_versions_write" ON public.store_scoring_form_versions;

CREATE POLICY "store_form_versions_select" ON public.store_scoring_form_versions
FOR SELECT TO authenticated USING (
  public.is_service_role()
  OR public.current_user_role() = 'grand_admin'
  OR EXISTS (
    SELECT 1 FROM public.store_scoring_forms f
    WHERE f.id = store_scoring_form_versions.form_id
      AND f.tenant_id = public.current_tenant_id()
  )
);

CREATE POLICY "store_form_versions_write" ON public.store_scoring_form_versions
FOR ALL TO authenticated USING (
  public.is_service_role()
  OR (
    public.current_user_role() IN ('grand_admin','firma_admin','bolge_muduru')
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_forms f
      WHERE f.id = store_scoring_form_versions.form_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
) WITH CHECK (
  public.is_service_role()
  OR (
    public.current_user_role() IN ('grand_admin','firma_admin','bolge_muduru')
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_forms f
      WHERE f.id = store_scoring_form_versions.form_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
);

-- ========== store_scoring_forms ==========
DROP POLICY IF EXISTS "forms select" ON public.store_scoring_forms;
DROP POLICY IF EXISTS "forms select by user tenant" ON public.store_scoring_forms;
DROP POLICY IF EXISTS "tenant forms select" ON public.store_scoring_forms;
DROP POLICY IF EXISTS "store_forms_select" ON public.store_scoring_forms;
DROP POLICY IF EXISTS "store_forms_write" ON public.store_scoring_forms;

CREATE POLICY "store_forms_select" ON public.store_scoring_forms
FOR SELECT TO authenticated USING (
  public.is_service_role()
  OR public.current_user_role() = 'grand_admin'
  OR tenant_id = public.current_tenant_id()
);

CREATE POLICY "store_forms_write" ON public.store_scoring_forms
FOR ALL TO authenticated USING (
  public.is_service_role()
  OR (
    tenant_id = public.current_tenant_id()
    AND public.current_user_role() IN ('grand_admin','firma_admin','bolge_muduru')
  )
) WITH CHECK (
  public.is_service_role()
  OR (
    tenant_id = public.current_tenant_id()
    AND public.current_user_role() IN ('grand_admin','firma_admin','bolge_muduru')
  )
);

-- ========== store_scoring_items ==========
DROP POLICY IF EXISTS "items select" ON public.store_scoring_items;
DROP POLICY IF EXISTS "items select by user tenant" ON public.store_scoring_items;
DROP POLICY IF EXISTS "tenant scoring items select" ON public.store_scoring_items;

CREATE POLICY "store_scoring_items_select" ON public.store_scoring_items
FOR SELECT TO authenticated USING (
  public.is_service_role()
  OR public.current_user_role() = 'grand_admin'
  OR EXISTS (
    SELECT 1 FROM public.store_scoring_sections s
    JOIN public.store_scoring_form_versions fv ON fv.id = s.form_version_id
    JOIN public.store_scoring_forms f ON f.id = fv.form_id
    WHERE s.id = store_scoring_items.section_id
      AND f.tenant_id = public.current_tenant_id()
  )
);

-- ========== store_scoring_sections ==========
DROP POLICY IF EXISTS "sections select" ON public.store_scoring_sections;
DROP POLICY IF EXISTS "sections select by user tenant" ON public.store_scoring_sections;
DROP POLICY IF EXISTS "tenant scoring sections select" ON public.store_scoring_sections;

CREATE POLICY "store_scoring_sections_select" ON public.store_scoring_sections
FOR SELECT TO authenticated USING (
  public.is_service_role()
  OR public.current_user_role() = 'grand_admin'
  OR EXISTS (
    SELECT 1 FROM public.store_scoring_form_versions fv
    JOIN public.store_scoring_forms f ON f.id = fv.form_id
    WHERE fv.id = store_scoring_sections.form_version_id
      AND f.tenant_id = public.current_tenant_id()
  )
);

-- ========== store_scoring_sessions ==========
DROP POLICY IF EXISTS "scoring_sessions_select" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "scoring_sessions_insert" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "scoring_sessions_update" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "scoring_sessions_delete" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions select" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions insert" ON public.store_scoring_sessions;
DROP POLICY IF EXISTS "tenant scoring sessions update" ON public.store_scoring_sessions;

CREATE POLICY "store_scoring_sessions_select" ON public.store_scoring_sessions
FOR SELECT TO authenticated USING (
  public.current_user_role() = 'grand_admin'
  OR (
    public.current_user_role() = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
  OR (
    public.current_user_role() = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = public.current_user_id()
        AND r.tenant_id = public.current_tenant_id()
    )
  )
  OR (
    public.current_user_role() IN ('sube_muduru','personel')
    AND store_scoring_sessions.evaluator_id = public.current_user_id()
  )
  OR public.is_service_role()
);

CREATE POLICY "store_scoring_sessions_insert" ON public.store_scoring_sessions
FOR INSERT TO authenticated WITH CHECK (
  public.current_user_role() = 'grand_admin'
  OR (
    public.current_user_role() = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_forms f
      WHERE f.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
  OR (
    public.current_user_role() = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = public.current_user_id()
        AND r.tenant_id = public.current_tenant_id()
    )
  )
  OR public.is_service_role()
);

CREATE POLICY "store_scoring_sessions_update" ON public.store_scoring_sessions
FOR UPDATE TO authenticated USING (
  public.current_user_role() = 'grand_admin'
  OR (
    public.current_user_role() = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
  OR (
    public.current_user_role() = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = public.current_user_id()
        AND r.tenant_id = public.current_tenant_id()
    )
  )
  OR public.is_service_role()
) WITH CHECK (
  public.current_user_role() = 'grand_admin'
  OR (
    public.current_user_role() = 'firma_admin'
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
  OR (
    public.current_user_role() = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = public.current_user_id()
        AND r.tenant_id = public.current_tenant_id()
    )
  )
  OR public.is_service_role()
);

CREATE POLICY "store_scoring_sessions_delete" ON public.store_scoring_sessions
FOR DELETE TO authenticated USING (
  public.current_user_role() IN ('grand_admin','firma_admin')
  OR (
    public.current_user_role() = 'bolge_muduru'
    AND EXISTS (
      SELECT 1 FROM public.branches b
      JOIN public.regions r ON r.id = b.region_id
      WHERE b.id = store_scoring_sessions.branch_id
        AND r.manager_id = public.current_user_id()
        AND r.tenant_id = public.current_tenant_id()
    )
  )
  OR public.is_service_role()
);

-- ========== store_scoring_session_items ==========
DROP POLICY IF EXISTS "scoring_session_items_manage" ON public.store_scoring_session_items;
DROP POLICY IF EXISTS "tenant scoring session items manage" ON public.store_scoring_session_items;

CREATE POLICY "store_scoring_session_items_manage" ON public.store_scoring_session_items
FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.store_scoring_sessions s
    WHERE s.id = store_scoring_session_items.session_id
      AND (
        public.current_user_role() = 'grand_admin'
        OR (
          public.current_user_role() = 'firma_admin' AND s.branch_id IN (
            SELECT b.id FROM public.branches b WHERE b.tenant_id = public.current_tenant_id()
          )
        )
        OR (
          public.current_user_role() = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.regions r
            WHERE r.id = (SELECT b.region_id FROM public.branches b WHERE b.id = s.branch_id)
              AND r.manager_id = public.current_user_id()
              AND r.tenant_id = public.current_tenant_id()
          )
        )
        OR (
          public.current_user_role() = 'sube_muduru'
          AND s.branch_id = (
            SELECT u.branch_id FROM public.users u WHERE u.id = public.current_user_id()
          )
        )
        OR (
          public.current_user_role() = 'personel'
          AND s.evaluator_id = public.current_user_id()
        )
      )
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.store_scoring_sessions s
    WHERE s.id = store_scoring_session_items.session_id
      AND (
        public.current_user_role() = 'grand_admin'
        OR (
          public.current_user_role() = 'firma_admin' AND s.branch_id IN (
            SELECT b.id FROM public.branches b WHERE b.tenant_id = public.current_tenant_id()
          )
        )
        OR (
          public.current_user_role() = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.regions r
            WHERE r.id = (SELECT b.region_id FROM public.branches b WHERE b.id = s.branch_id)
              AND r.manager_id = public.current_user_id()
              AND r.tenant_id = public.current_tenant_id()
          )
        )
        OR (
          public.current_user_role() = 'sube_muduru'
          AND s.branch_id = (
            SELECT u.branch_id FROM public.users u WHERE u.id = public.current_user_id()
          )
        )
        OR (
          public.current_user_role() = 'personel'
          AND s.evaluator_id = public.current_user_id()
        )
      )
  )
);

-- Note: other existing policies for announcements_audience_read, announcement_reads, tasks, etc. remain from previous migrations.
