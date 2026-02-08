-- Security hardening: move pg_net to extensions, tighten RLS on announcements/announcement_reads/attendance,
-- and enforce checks on task_assignees/task_items writes.

-- pg_net schema cannot be moved with ALTER. Drop/recreate in extensions if it is in public.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname = 'pg_net' AND n.nspname = 'public'
  ) THEN
    DROP EXTENSION pg_net;
  END IF;
END $$;

CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";

-- 2) Announcements and read-tracking policies
-- Service role full access
DROP POLICY IF EXISTS "announcements_service_all" ON public.announcements;
CREATE POLICY "announcements_service_all" ON public.announcements
  TO service_role USING (true) WITH CHECK (true);

-- Audience-based read access for authenticated users in the same tenant/branch/role
DROP POLICY IF EXISTS "announcements_audience_read" ON public.announcements;
CREATE POLICY "announcements_audience_read" ON public.announcements
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1
      FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND (announcements.target_branches IS NULL OR array_length(announcements.target_branches, 1) IS NULL OR ctx.branch_id = ANY (announcements.target_branches))
        AND (announcements.target_roles IS NULL OR array_length(announcements.target_roles, 1) IS NULL OR ctx.role = ANY (announcements.target_roles))
    )
    OR public.is_service_role()
  );

-- Publish/update/delete only by tenant admins/managers
DROP POLICY IF EXISTS "announcements_admin_write" ON public.announcements;
CREATE POLICY "announcements_admin_write" ON public.announcements
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1
      FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND ctx.role IN ('grand_admin', 'firma_admin', 'bolge_muduru')
    )
    OR public.is_service_role()
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND ctx.role IN ('grand_admin', 'firma_admin', 'bolge_muduru')
    )
    OR public.is_service_role()
  );

-- announcement_reads: only owner can mark/read within targeted tenant/branch/role
DROP POLICY IF EXISTS "announcement_reads_service_all" ON public.announcement_reads;
CREATE POLICY "announcement_reads_service_all" ON public.announcement_reads
  TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "announcement_reads_owner" ON public.announcement_reads;
CREATE POLICY "announcement_reads_owner" ON public.announcement_reads
  FOR SELECT TO authenticated USING (
    announcement_reads.user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.announcements a
      JOIN public.users u ON u.id = auth.uid()
      WHERE a.id = announcement_reads.announcement_id
        AND a.tenant_id = u.tenant_id
        AND (a.target_branches IS NULL OR array_length(a.target_branches, 1) IS NULL OR u.branch_id = ANY (a.target_branches))
        AND (a.target_roles IS NULL OR array_length(a.target_roles, 1) IS NULL OR u.role = ANY (a.target_roles))
    )
  );

CREATE POLICY "announcement_reads_owner_write" ON public.announcement_reads
  FOR INSERT TO authenticated WITH CHECK (
    announcement_reads.user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.announcements a
      JOIN public.users u ON u.id = auth.uid()
      WHERE a.id = announcement_reads.announcement_id
        AND a.tenant_id = u.tenant_id
        AND (a.target_branches IS NULL OR array_length(a.target_branches, 1) IS NULL OR u.branch_id = ANY (a.target_branches))
        AND (a.target_roles IS NULL OR array_length(a.target_roles, 1) IS NULL OR u.role = ANY (a.target_roles))
    )
  );

-- 3) Attendance: tenant/branch scoped policies
DROP POLICY IF EXISTS "attendance_service_all" ON public.attendance;
CREATE POLICY "attendance_service_all" ON public.attendance
  TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "attendance_tenant_scoped_read" ON public.attendance;
CREATE POLICY "attendance_tenant_scoped_read" ON public.attendance
  FOR SELECT TO authenticated USING (
    public.is_service_role() OR
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = attendance.tenant_id AND (
        ctx.role = 'grand_admin' OR
        ctx.role = 'firma_admin' OR
        (ctx.role = 'bolge_muduru' AND EXISTS (
          SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
          WHERE b.id = attendance.branch_id AND r.manager_id = ctx.id AND r.tenant_id = ctx.tenant_id
        )) OR
        (ctx.role = 'sube_muduru' AND ctx.branch_id = attendance.branch_id) OR
        (ctx.role = 'personel' AND ctx.branch_id = attendance.branch_id AND attendance.user_id = ctx.id)
      )
    )
  );

DROP POLICY IF EXISTS "attendance_tenant_scoped_write" ON public.attendance;
CREATE POLICY "attendance_tenant_scoped_write" ON public.attendance
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = attendance.tenant_id AND (
        ctx.role = 'grand_admin' OR
        ctx.role = 'firma_admin' OR
        (ctx.role = 'bolge_muduru' AND EXISTS (
          SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
          WHERE b.id = attendance.branch_id AND r.manager_id = ctx.id AND r.tenant_id = ctx.tenant_id
        )) OR
        (ctx.role = 'sube_muduru' AND ctx.branch_id = attendance.branch_id) OR
        (ctx.role = 'personel' AND ctx.branch_id = attendance.branch_id AND attendance.user_id = ctx.id)
      )
    )
    OR public.is_service_role()
  );

CREATE POLICY "attendance_tenant_scoped_update" ON public.attendance
  FOR UPDATE TO authenticated USING (
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = attendance.tenant_id AND (
        ctx.role = 'grand_admin' OR
        ctx.role = 'firma_admin' OR
        (ctx.role = 'bolge_muduru' AND EXISTS (
          SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
          WHERE b.id = attendance.branch_id AND r.manager_id = ctx.id AND r.tenant_id = ctx.tenant_id
        )) OR
        (ctx.role = 'sube_muduru' AND ctx.branch_id = attendance.branch_id) OR
        (ctx.role = 'personel' AND ctx.branch_id = attendance.branch_id AND attendance.user_id = ctx.id)
      )
    )
    OR public.is_service_role()
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = attendance.tenant_id AND (
        ctx.role = 'grand_admin' OR
        ctx.role = 'firma_admin' OR
        (ctx.role = 'bolge_muduru' AND EXISTS (
          SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
          WHERE b.id = attendance.branch_id AND r.manager_id = ctx.id AND r.tenant_id = ctx.tenant_id
        )) OR
        (ctx.role = 'sube_muduru' AND ctx.branch_id = attendance.branch_id) OR
        (ctx.role = 'personel' AND ctx.branch_id = attendance.branch_id AND attendance.user_id = ctx.id)
      )
    )
    OR public.is_service_role()
  );

-- 4) task_assignees/task_items: apply the same constraint to writes as reads
DROP POLICY IF EXISTS "task_assignees_all" ON public.task_assignees;
CREATE POLICY "task_assignees_all" ON public.task_assignees
  USING (
    ((auth.role() = 'service_role') OR EXISTS (
      SELECT 1
      FROM public.tasks t
      JOIN public.users u ON u.id = auth.uid()
      WHERE t.id = task_assignees.task_id
        AND (
          u.role = 'grand_admin' OR
          (u.tenant_id = t.tenant_id AND (
            u.role = 'firma_admin' OR
            (u.role IN ('sube_muduru', 'personel') AND (t.branch_id = u.branch_id OR task_assignees.user_id = u.id)) OR
            (u.role = 'bolge_muduru' AND EXISTS (
              SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
              WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
            ))
          ))
        )
    ))
  )
  WITH CHECK (
    ((auth.role() = 'service_role') OR EXISTS (
      SELECT 1
      FROM public.tasks t
      JOIN public.users u ON u.id = auth.uid()
      WHERE t.id = task_assignees.task_id
        AND (
          u.role = 'grand_admin' OR
          (u.tenant_id = t.tenant_id AND (
            u.role = 'firma_admin' OR
            (u.role IN ('sube_muduru', 'personel') AND (t.branch_id = u.branch_id OR task_assignees.user_id = u.id)) OR
            (u.role = 'bolge_muduru' AND EXISTS (
              SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
              WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
            ))
          ))
        )
    ))
  );

DROP POLICY IF EXISTS "task_items_all" ON public.task_items;
CREATE POLICY "task_items_all" ON public.task_items
  USING (
    ((auth.role() = 'service_role') OR EXISTS (
      SELECT 1
      FROM public.tasks t
      JOIN public.users u ON u.id = auth.uid()
      WHERE t.id = task_items.task_id
        AND (
          u.role = 'grand_admin' OR
          (u.tenant_id = t.tenant_id AND (
            u.role = 'firma_admin' OR
            (u.role = 'bolge_muduru' AND EXISTS (
              SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
              WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
            )) OR
            (u.role IN ('sube_muduru', 'personel') AND (
              t.branch_id = u.branch_id OR EXISTS (
                SELECT 1 FROM public.task_assignees ta
                WHERE ta.task_id = t.id AND ta.user_id = u.id
              )
            ))
          ))
        )
    ))
  )
  WITH CHECK (
    ((auth.role() = 'service_role') OR EXISTS (
      SELECT 1
      FROM public.tasks t
      JOIN public.users u ON u.id = auth.uid()
      WHERE t.id = task_items.task_id
        AND (
          u.role = 'grand_admin' OR
          (u.tenant_id = t.tenant_id AND (
            u.role = 'firma_admin' OR
            (u.role = 'bolge_muduru' AND EXISTS (
              SELECT 1 FROM public.branches b JOIN public.regions r ON r.id = b.region_id
              WHERE b.id = t.branch_id AND r.manager_id = u.id AND r.tenant_id = u.tenant_id
            )) OR
            (u.role IN ('sube_muduru', 'personel') AND (
              t.branch_id = u.branch_id OR EXISTS (
                SELECT 1 FROM public.task_assignees ta
                WHERE ta.task_id = t.id AND ta.user_id = u.id
              )
            ))
          ))
        )
    ))
  );
