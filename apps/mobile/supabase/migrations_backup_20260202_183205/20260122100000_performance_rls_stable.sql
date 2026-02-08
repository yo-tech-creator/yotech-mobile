-- Performance: wrap auth calls with stable helpers to avoid per-row re-evaluation (auth_rls_initplan)
-- Applies to tasks, form_submissions, todos, branch_requests, announcement_reads,
-- task_assignees/task_items, shift_pattern_drafts, store_scoring* policies.

-- Helpers already exist: public.current_user_id(), public.current_tenant_id(), public.current_user_role(), public.is_service_role().
-- We rely on these instead of auth.uid()/auth.role()/current_setting.

-- =================
-- tasks
-- =================
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;
CREATE POLICY "tasks_delete" ON public.tasks
FOR DELETE USING (
  public.is_service_role()
  OR (
    tasks.created_by = public.current_user_id()
    AND tasks.tenant_id = COALESCE(public.current_tenant_id(), (
      SELECT u.tenant_id FROM public.users u WHERE u.id = public.current_user_id()
    ))
  )
);

DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
CREATE POLICY "tasks_insert" ON public.tasks
FOR INSERT WITH CHECK (
  public.is_service_role()
  OR (
    tasks.created_by = public.current_user_id()
    AND tasks.tenant_id = COALESCE(public.current_tenant_id(), (
      SELECT u.tenant_id FROM public.users u WHERE u.id = public.current_user_id()
    ))
  )
);

DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
CREATE POLICY "tasks_select" ON public.tasks
FOR SELECT USING (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.tenant_id = tasks.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.branches b
            JOIN public.regions r ON r.id = b.region_id
            WHERE b.id = tasks.branch_id
              AND b.tenant_id = u.tenant_id
              AND r.manager_id = u.id
          )
        )
        OR (
          u.role IN ('sube_muduru','personel')
          AND tasks.branch_id = u.branch_id
        )
      )
  )
);

DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
CREATE POLICY "tasks_update" ON public.tasks
FOR UPDATE USING (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.tenant_id = tasks.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role IN ('sube_muduru','personel')
          AND tasks.branch_id = u.branch_id
        )
      )
  )
) WITH CHECK (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.tenant_id = tasks.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role IN ('sube_muduru','personel')
          AND tasks.branch_id = u.branch_id
        )
      )
  )
);

-- =================
-- form_submissions
-- =================
DROP POLICY IF EXISTS "Users can view their own submissions" ON public.form_submissions;
CREATE POLICY "Users can view their own submissions" ON public.form_submissions
FOR SELECT USING (public.current_user_id() = form_submissions.user_id);

DROP POLICY IF EXISTS "Branch managers can view their branch submissions" ON public.form_submissions;
CREATE POLICY "Branch managers can view their branch submissions" ON public.form_submissions
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.role = 'sube_muduru'
      AND u.branch_id = form_submissions.branch_id
  )
);

DROP POLICY IF EXISTS "Tenant admin can view all submissions" ON public.form_submissions;
CREATE POLICY "Tenant admin can view all submissions" ON public.form_submissions
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.role = 'firma_admin'
      AND u.tenant_id = form_submissions.tenant_id
  )
);

DROP POLICY IF EXISTS "form_submissions_all" ON public.form_submissions;
CREATE POLICY "form_submissions_all" ON public.form_submissions
USING (
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
) WITH CHECK (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND (
        u.role = 'grand_admin'
        OR (
          u.tenant_id = form_submissions.tenant_id AND (
            u.role = 'firma_admin'
            OR (u.role = 'sube_muduru' AND u.branch_id = form_submissions.branch_id)
            OR (u.role = 'personel' AND u.id = form_submissions.user_id)
          )
        )
      )
  )
);

-- =================
-- branch_requests
-- =================
DROP POLICY IF EXISTS "branch_requests_insert" ON public.branch_requests;
CREATE POLICY "branch_requests_insert" ON public.branch_requests
FOR INSERT WITH CHECK (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.tenant_id = branch_requests.tenant_id
      AND u.role IN ('grand_admin','firma_admin','bolge_muduru','sube_muduru','personel')
  )
);

DROP POLICY IF EXISTS "branch_requests_select" ON public.branch_requests;
CREATE POLICY "branch_requests_select" ON public.branch_requests
FOR SELECT USING (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.tenant_id = branch_requests.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
            WHERE b.id = branch_requests.branch_id
              AND r.manager_id = u.id
              AND r.tenant_id = u.tenant_id
          )
        )
        OR (u.role IN ('sube_muduru','personel') AND u.branch_id = branch_requests.branch_id)
      )
  )
);

DROP POLICY IF EXISTS "branch_requests_update" ON public.branch_requests;
CREATE POLICY "branch_requests_update" ON public.branch_requests
FOR UPDATE USING (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.tenant_id = branch_requests.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
            WHERE b.id = branch_requests.branch_id
              AND r.manager_id = u.id
              AND r.tenant_id = u.tenant_id
          )
        )
        OR (u.role IN ('sube_muduru','personel') AND u.branch_id = branch_requests.branch_id)
      )
  )
);

-- =================
-- todos
-- =================
DROP POLICY IF EXISTS "todos_delete_self" ON public.todos;
CREATE POLICY "todos_delete_self" ON public.todos
FOR DELETE USING (
  public.is_service_role()
  OR (
    todos.owner_id = public.current_user_id()
    AND todos.tenant_id = COALESCE(public.current_tenant_id(), (
      SELECT u.tenant_id FROM public.users u WHERE u.id = public.current_user_id()
    ))
  )
);

DROP POLICY IF EXISTS "todos_insert_self" ON public.todos;
CREATE POLICY "todos_insert_self" ON public.todos
FOR INSERT WITH CHECK (
  public.is_service_role()
  OR (
    todos.owner_id = public.current_user_id()
    AND todos.tenant_id = COALESCE(public.current_tenant_id(), (
      SELECT u.tenant_id FROM public.users u WHERE u.id = public.current_user_id()
    ))
  )
);

DROP POLICY IF EXISTS "todos_select_self" ON public.todos;
CREATE POLICY "todos_select_self" ON public.todos
FOR SELECT USING (
  public.is_service_role()
  OR (
    todos.owner_id = public.current_user_id()
    AND todos.tenant_id = COALESCE(public.current_tenant_id(), (
      SELECT u.tenant_id FROM public.users u WHERE u.id = public.current_user_id()
    ))
  )
);

DROP POLICY IF EXISTS "todos_update_self" ON public.todos;
CREATE POLICY "todos_update_self" ON public.todos
FOR UPDATE USING (
  public.is_service_role()
  OR (
    todos.owner_id = public.current_user_id()
    AND todos.tenant_id = COALESCE(public.current_tenant_id(), (
      SELECT u.tenant_id FROM public.users u WHERE u.id = public.current_user_id()
    ))
  )
) WITH CHECK (
  public.is_service_role()
  OR (
    todos.owner_id = public.current_user_id()
    AND todos.tenant_id = COALESCE(public.current_tenant_id(), (
      SELECT u.tenant_id FROM public.users u WHERE u.id = public.current_user_id()
    ))
  )
);

-- =================
-- announcement_reads
-- =================
DROP POLICY IF EXISTS "announcement_reads_owner" ON public.announcement_reads;
CREATE POLICY "announcement_reads_owner" ON public.announcement_reads
FOR SELECT USING (
  announcement_reads.user_id = public.current_user_id()
  AND EXISTS (
    SELECT 1 FROM public.announcements a
    WHERE a.id = announcement_reads.announcement_id
      AND a.tenant_id = public.current_tenant_id()
      AND (
        a.target_branches IS NULL OR cardinality(a.target_branches) = 0
        OR (SELECT branch_id FROM public.users u WHERE u.id = public.current_user_id()) = ANY (a.target_branches)
      )
      AND (
        a.target_roles IS NULL OR cardinality(a.target_roles) = 0
        OR (SELECT role FROM public.users u WHERE u.id = public.current_user_id()) = ANY (a.target_roles)
      )
  )
);

DROP POLICY IF EXISTS "announcement_reads_owner_write" ON public.announcement_reads;
CREATE POLICY "announcement_reads_owner_write" ON public.announcement_reads
FOR INSERT WITH CHECK (
  announcement_reads.user_id = public.current_user_id()
  AND EXISTS (
    SELECT 1 FROM public.announcements a
    WHERE a.id = announcement_reads.announcement_id
      AND a.tenant_id = public.current_tenant_id()
      AND (
        a.target_branches IS NULL OR cardinality(a.target_branches) = 0
        OR (SELECT branch_id FROM public.users u WHERE u.id = public.current_user_id()) = ANY (a.target_branches)
      )
      AND (
        a.target_roles IS NULL OR cardinality(a.target_roles) = 0
        OR (SELECT role FROM public.users u WHERE u.id = public.current_user_id()) = ANY (a.target_roles)
      )
  )
);

-- =================
-- task_assignees / task_items
-- =================
DROP POLICY IF EXISTS "task_assignees_all" ON public.task_assignees;
CREATE POLICY "task_assignees_all" ON public.task_assignees
USING (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.tasks t
    JOIN public.users u ON u.id = public.current_user_id()
    WHERE t.id = task_assignees.task_id
      AND t.tenant_id = u.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
            WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
          )
        )
        OR (
          u.role IN ('sube_muduru','personel')
          AND (t.branch_id = u.branch_id OR task_assignees.user_id = u.id)
        )
      )
  )
) WITH CHECK (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.tasks t
    JOIN public.users u ON u.id = public.current_user_id()
    WHERE t.id = task_assignees.task_id
      AND t.tenant_id = u.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
            WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
          )
        )
        OR (
          u.role IN ('sube_muduru','personel')
          AND (t.branch_id = u.branch_id OR task_assignees.user_id = u.id)
        )
      )
  )
);

DROP POLICY IF EXISTS "task_items_all" ON public.task_items;
CREATE POLICY "task_items_all" ON public.task_items
USING (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.tasks t
    JOIN public.users u ON u.id = public.current_user_id()
    WHERE t.id = task_items.task_id
      AND t.tenant_id = u.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
            WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
          )
        )
        OR (
          u.role IN ('sube_muduru','personel')
          AND (
            t.branch_id = u.branch_id
            OR EXISTS (
              SELECT 1 FROM public.task_assignees ta
              WHERE ta.task_id = task_items.task_id AND ta.user_id = u.id
            )
          )
        )
      )
  )
) WITH CHECK (
  public.is_service_role()
  OR EXISTS (
    SELECT 1 FROM public.tasks t
    JOIN public.users u ON u.id = public.current_user_id()
    WHERE t.id = task_items.task_id
      AND t.tenant_id = u.tenant_id
      AND (
        u.role IN ('grand_admin','firma_admin')
        OR (
          u.role = 'bolge_muduru'
          AND EXISTS (
            SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
            WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
          )
        )
        OR (
          u.role IN ('sube_muduru','personel')
          AND (
            t.branch_id = u.branch_id
            OR EXISTS (
              SELECT 1 FROM public.task_assignees ta
              WHERE ta.task_id = task_items.task_id AND ta.user_id = u.id
            )
          )
        )
      )
  )
);

-- =================
-- shift_pattern_drafts (owner-scoped)
-- =================
DROP POLICY IF EXISTS "shift_pattern_drafts_owner_select" ON public.shift_pattern_drafts;
CREATE POLICY "shift_pattern_drafts_owner_select" ON public.shift_pattern_drafts
FOR SELECT USING (
  shift_pattern_drafts.user_id = public.current_user_id()
  AND shift_pattern_drafts.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "shift_pattern_drafts_owner_insert" ON public.shift_pattern_drafts;
CREATE POLICY "shift_pattern_drafts_owner_insert" ON public.shift_pattern_drafts
FOR INSERT WITH CHECK (
  shift_pattern_drafts.user_id = public.current_user_id()
  AND shift_pattern_drafts.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "shift_pattern_drafts_owner_update" ON public.shift_pattern_drafts;
CREATE POLICY "shift_pattern_drafts_owner_update" ON public.shift_pattern_drafts
FOR UPDATE USING (
  shift_pattern_drafts.user_id = public.current_user_id()
  AND shift_pattern_drafts.tenant_id = public.current_tenant_id()
) WITH CHECK (
  shift_pattern_drafts.user_id = public.current_user_id()
  AND shift_pattern_drafts.tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "shift_pattern_drafts_owner_delete" ON public.shift_pattern_drafts;
CREATE POLICY "shift_pattern_drafts_owner_delete" ON public.shift_pattern_drafts
FOR DELETE USING (
  shift_pattern_drafts.user_id = public.current_user_id()
  AND shift_pattern_drafts.tenant_id = public.current_tenant_id()
);

-- =================
-- store scoring forms / versions / items / sections
-- =================
DROP POLICY IF EXISTS "form versions select" ON public.store_scoring_form_versions;
CREATE POLICY "form versions select" ON public.store_scoring_form_versions
FOR SELECT TO authenticated USING (
  public.is_service_role()
  OR public.current_user_role() = 'grand_admin'
  OR EXISTS (
    SELECT 1 FROM public.store_scoring_forms f
    WHERE f.id = store_scoring_form_versions.form_id
      AND f.tenant_id = public.current_tenant_id()
  )
);

DROP POLICY IF EXISTS "form versions select by user tenant" ON public.store_scoring_form_versions;
CREATE POLICY "form versions select by user tenant" ON public.store_scoring_form_versions
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.store_scoring_forms f
    JOIN public.users u ON u.id = public.current_user_id()
    WHERE f.id = store_scoring_form_versions.form_id
      AND f.tenant_id = u.tenant_id
  )
);

DROP POLICY IF EXISTS "store_form_versions_select" ON public.store_scoring_form_versions;
CREATE POLICY "store_form_versions_select" ON public.store_scoring_form_versions
FOR SELECT USING (
  public.current_user_role() = 'grand_admin'
  OR EXISTS (
    SELECT 1 FROM public.store_scoring_forms f
    WHERE f.id = store_scoring_form_versions.form_id
      AND f.tenant_id = public.current_tenant_id()
  )
);

DROP POLICY IF EXISTS "store_form_versions_write" ON public.store_scoring_form_versions;
CREATE POLICY "store_form_versions_write" ON public.store_scoring_form_versions
USING (
  public.current_user_role() = 'grand_admin'
  OR (
    public.current_user_role() IN ('firma_admin','bolge_muduru')
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_forms f
      WHERE f.id = store_scoring_form_versions.form_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
) WITH CHECK (
  public.current_user_role() = 'grand_admin'
  OR (
    public.current_user_role() IN ('firma_admin','bolge_muduru')
    AND EXISTS (
      SELECT 1 FROM public.store_scoring_forms f
      WHERE f.id = store_scoring_form_versions.form_id
        AND f.tenant_id = public.current_tenant_id()
    )
  )
);

DROP POLICY IF EXISTS "forms select" ON public.store_scoring_forms;
CREATE POLICY "forms select" ON public.store_scoring_forms
FOR SELECT TO authenticated USING (
  public.is_service_role()
  OR public.current_user_role() = 'grand_admin'
  OR tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "forms select by user tenant" ON public.store_scoring_forms;
CREATE POLICY "forms select by user tenant" ON public.store_scoring_forms
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_user_id()
      AND u.tenant_id = store_scoring_forms.tenant_id
  )
);

DROP POLICY IF EXISTS "store_forms_select" ON public.store_scoring_forms;
CREATE POLICY "store_forms_select" ON public.store_scoring_forms
FOR SELECT USING (
  public.current_user_role() = 'grand_admin'
  OR tenant_id = public.current_tenant_id()
);

DROP POLICY IF EXISTS "store_forms_write" ON public.store_scoring_forms;
CREATE POLICY "store_forms_write" ON public.store_scoring_forms
USING (
  public.current_user_role() = 'grand_admin'
  OR (
    tenant_id = public.current_tenant_id()
    AND public.current_user_role() IN ('firma_admin','bolge_muduru')
  )
) WITH CHECK (
  public.current_user_role() = 'grand_admin'
  OR (
    tenant_id = public.current_tenant_id()
    AND public.current_user_role() IN ('firma_admin','bolge_muduru')
  )
);

DROP POLICY IF EXISTS "items select" ON public.store_scoring_items;
CREATE POLICY "items select" ON public.store_scoring_items
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

DROP POLICY IF EXISTS "items select by user tenant" ON public.store_scoring_items;
CREATE POLICY "items select by user tenant" ON public.store_scoring_items
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.store_scoring_sections s
    JOIN public.store_scoring_form_versions fv ON fv.id = s.form_version_id
    JOIN public.store_scoring_forms f ON f.id = fv.form_id
    JOIN public.users u ON u.id = public.current_user_id()
    WHERE s.id = store_scoring_items.section_id
      AND f.tenant_id = u.tenant_id
  )
);

DROP POLICY IF EXISTS "sections select" ON public.store_scoring_sections;
CREATE POLICY "sections select" ON public.store_scoring_sections
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

DROP POLICY IF EXISTS "sections select by user tenant" ON public.store_scoring_sections;
CREATE POLICY "sections select by user tenant" ON public.store_scoring_sections
FOR SELECT TO authenticated USING (
  EXISTS (
    SELECT 1 FROM public.store_scoring_form_versions fv
    JOIN public.store_scoring_forms f ON f.id = fv.form_id
    JOIN public.users u ON u.id = public.current_user_id()
    WHERE fv.id = store_scoring_sections.form_version_id
      AND f.tenant_id = u.tenant_id
  )
);

-- =================
-- store scoring sessions and session items
-- =================
DROP POLICY IF EXISTS "scoring_sessions_select" ON public.store_scoring_sessions;
CREATE POLICY "scoring_sessions_select" ON public.store_scoring_sessions
FOR SELECT USING (
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
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      JOIN public.branches b ON b.id = store_scoring_sessions.branch_id
      JOIN public.regions r ON r.id = b.region_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
        AND r.manager_id = public.current_user_id()
    )
  )
  OR (
    public.current_user_role() = 'sube_muduru'
    AND store_scoring_sessions.evaluator_id = public.current_user_id()
    AND store_scoring_sessions.branch_id = (
      SELECT u.branch_id FROM public.users u WHERE u.id = public.current_user_id()
    )
  )
  OR (
    public.current_user_role() = 'personel'
    AND store_scoring_sessions.evaluator_id = public.current_user_id()
  )
);

DROP POLICY IF EXISTS "scoring_sessions_insert" ON public.store_scoring_sessions;
CREATE POLICY "scoring_sessions_insert" ON public.store_scoring_sessions
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
);

DROP POLICY IF EXISTS "scoring_sessions_update" ON public.store_scoring_sessions;
CREATE POLICY "scoring_sessions_update" ON public.store_scoring_sessions
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
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      JOIN public.branches b ON b.id = store_scoring_sessions.branch_id
      JOIN public.regions r ON r.id = b.region_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
        AND r.manager_id = public.current_user_id()
    )
  )
  OR (
    public.current_user_role() = 'sube_muduru'
    AND store_scoring_sessions.evaluator_id = public.current_user_id()
    AND store_scoring_sessions.branch_id = (
      SELECT u.branch_id FROM public.users u WHERE u.id = public.current_user_id()
    )
  )
  OR (
    public.current_user_role() = 'personel'
    AND store_scoring_sessions.evaluator_id = public.current_user_id()
  )
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
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      JOIN public.branches b ON b.id = store_scoring_sessions.branch_id
      JOIN public.regions r ON r.id = b.region_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
        AND r.manager_id = public.current_user_id()
    )
  )
  OR (
    public.current_user_role() = 'sube_muduru'
    AND store_scoring_sessions.evaluator_id = public.current_user_id()
    AND store_scoring_sessions.branch_id = (
      SELECT u.branch_id FROM public.users u WHERE u.id = public.current_user_id()
    )
  )
  OR (
    public.current_user_role() = 'personel'
    AND store_scoring_sessions.evaluator_id = public.current_user_id()
  )
);

DROP POLICY IF EXISTS "scoring_sessions_delete" ON public.store_scoring_sessions;
CREATE POLICY "scoring_sessions_delete" ON public.store_scoring_sessions
FOR DELETE USING (
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
      SELECT 1 FROM public.store_scoring_form_versions v
      JOIN public.store_scoring_forms f ON f.id = v.form_id
      JOIN public.branches b ON b.id = store_scoring_sessions.branch_id
      JOIN public.regions r ON r.id = b.region_id
      WHERE v.id = store_scoring_sessions.form_version_id
        AND f.tenant_id = public.current_tenant_id()
        AND r.manager_id = public.current_user_id()
    )
  )
);

DROP POLICY IF EXISTS "scoring_session_items_manage" ON public.store_scoring_session_items;
CREATE POLICY "scoring_session_items_manage" ON public.store_scoring_session_items
USING (
  EXISTS (
    SELECT 1 FROM public.store_scoring_sessions s
    WHERE s.id = store_scoring_session_items.session_id
      AND s.branch_id IN (
        SELECT b.id FROM public.branches b
        WHERE (
          public.current_user_role() = 'grand_admin'
          OR (
            public.current_user_role() = 'firma_admin' AND b.tenant_id = public.current_tenant_id()
          )
          OR (
            public.current_user_role() = 'bolge_muduru'
            AND EXISTS (
              SELECT 1 FROM public.regions r
              WHERE r.id = b.region_id
                AND r.manager_id = public.current_user_id()
                AND r.tenant_id = public.current_tenant_id()
            )
          )
          OR (
            public.current_user_role() = 'sube_muduru'
            AND b.id = (
              SELECT u.branch_id FROM public.users u WHERE u.id = public.current_user_id()
            )
          )
        )
      )
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.store_scoring_sessions s
    WHERE s.id = store_scoring_session_items.session_id
      AND s.branch_id IN (
        SELECT b.id FROM public.branches b
        WHERE (
          public.current_user_role() = 'grand_admin'
          OR (
            public.current_user_role() = 'firma_admin' AND b.tenant_id = public.current_tenant_id()
          )
          OR (
            public.current_user_role() = 'bolge_muduru'
            AND EXISTS (
              SELECT 1 FROM public.regions r
              WHERE r.id = b.region_id
                AND r.manager_id = public.current_user_id()
                AND r.tenant_id = public.current_tenant_id()
            )
          )
          OR (
            public.current_user_role() = 'sube_muduru'
            AND b.id = (
              SELECT u.branch_id FROM public.users u WHERE u.id = public.current_user_id()
            )
          )
        )
      )
  )
);
