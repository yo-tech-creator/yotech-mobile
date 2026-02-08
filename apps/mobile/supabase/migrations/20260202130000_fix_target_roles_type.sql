-- ============================================================================
-- FIX: Change target_roles from user_role[] to text[]
-- Sorun: Web panel string array gönderiyor, PostgreSQL enum'a otomatik cast yapamıyor
-- Çözüm: Kolonu text[] yapıp RLS politikalarında role'u text'e cast et
-- ============================================================================

-- 0. Önce tüm bağımlı politikaları düşür
DROP POLICY IF EXISTS "announcements_audience_read" ON public.announcements;
DROP POLICY IF EXISTS "announcement_reads_owner" ON public.announcement_reads;
DROP POLICY IF EXISTS "announcement_reads_owner_write" ON public.announcement_reads;
DROP POLICY IF EXISTS "announcement_reads_insert" ON public.announcement_reads;

-- 1. target_roles kolonunu text[] olarak değiştir
ALTER TABLE public.announcements 
  ALTER COLUMN target_roles TYPE text[] 
  USING target_roles::text[];

-- 2. RLS politikalarını güncelle - role'u text'e cast et

-- Drop existing policies
DROP POLICY IF EXISTS "announcements_audience_read" ON public.announcements;
DROP POLICY IF EXISTS "announcement_reads_owner" ON public.announcement_reads;
DROP POLICY IF EXISTS "announcement_reads_owner_write" ON public.announcement_reads;

-- Recreate announcements_audience_read with text cast
CREATE POLICY "announcements_audience_read" ON public.announcements
  FOR SELECT TO authenticated USING (
    EXISTS (
      SELECT 1
      FROM public.current_user_ctx() ctx
      WHERE ctx.tenant_id = announcements.tenant_id
        AND (announcements.target_branches IS NULL OR array_length(announcements.target_branches, 1) IS NULL OR ctx.branch_id = ANY (announcements.target_branches))
        AND (announcements.target_roles IS NULL OR array_length(announcements.target_roles, 1) IS NULL OR ctx.role::text = ANY (announcements.target_roles))
    )
    OR public.is_service_role()
  );

-- Recreate announcement_reads_owner with text cast
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
        AND (a.target_roles IS NULL OR array_length(a.target_roles, 1) IS NULL OR u.role::text = ANY (a.target_roles))
    )
  );

-- Recreate announcement_reads_owner_write with text cast
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
        AND (a.target_roles IS NULL OR array_length(a.target_roles, 1) IS NULL OR u.role::text = ANY (a.target_roles))
    )
  );

-- 3. notify_announcement_published trigger'ını güncelle (zaten text cast kullanıyor, ama emin olalım)
CREATE OR REPLACE FUNCTION notify_announcement_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target_users uuid[];
  v_notification_type notification_type;
  v_title text;
  v_body text;
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.published_at IS NOT NULL) 
     OR (TG_OP = 'UPDATE' AND OLD.published_at IS NULL AND NEW.published_at IS NOT NULL) THEN
    
    IF NEW.type = 'survey' THEN
      v_notification_type := 'survey';
      v_title := '📊 Yeni Anket: ' || NEW.title;
      v_body := COALESCE(NEW.summary, left(NEW.content, 100));
    ELSE
      v_notification_type := 'announcement';
      v_title := '📢 Yeni Duyuru: ' || NEW.title;
      v_body := COALESCE(NEW.summary, left(NEW.content, 100));
    END IF;

    SELECT array_agg(u.id)
    INTO v_target_users
    FROM users u
    WHERE u.tenant_id = NEW.tenant_id
      AND u.is_active = true
      AND (
        NEW.target_branches IS NULL 
        OR array_length(NEW.target_branches, 1) IS NULL 
        OR u.branch_id = ANY(NEW.target_branches)
      )
      AND (
        NEW.target_roles IS NULL 
        OR array_length(NEW.target_roles, 1) IS NULL 
        OR u.role::text = ANY(NEW.target_roles)
      );

    IF v_target_users IS NOT NULL AND array_length(v_target_users, 1) > 0 THEN
      PERFORM send_notification(
        NEW.tenant_id,
        v_target_users,
        v_notification_type,
        v_title,
        v_body,
        jsonb_build_object('announcement_id', NEW.id, 'type', NEW.type::text)
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- 4. v_survey_statistics view'ını güncelle
DROP VIEW IF EXISTS public.v_survey_statistics;
CREATE OR REPLACE VIEW public.v_survey_statistics AS
SELECT 
  a.id as announcement_id,
  a.title,
  a.tenant_id,
  a.published_at,
  COUNT(DISTINCT sr.user_id) as total_responses,
  (
    SELECT COUNT(DISTINCT u.id) 
    FROM public.users u 
    WHERE u.tenant_id = a.tenant_id
      AND u.is_active = true
      AND (
        a.target_scope = 'all_branches'
        OR (a.target_scope = 'selected_branches' AND u.branch_id = ANY(a.target_branches))
        OR (a.target_scope = 'region_managers_only' AND u.role = 'bolge_muduru')
      )
      AND (
        NOT a.managers_only 
        OR u.role IN ('sube_muduru', 'bolge_muduru', 'firma_admin')
      )
  ) as target_audience_count
FROM public.announcements a
LEFT JOIN public.survey_responses sr ON sr.announcement_id = a.id
WHERE a.type = 'survey'
GROUP BY a.id;

-- Grant permissions
GRANT SELECT ON public.v_survey_statistics TO authenticated;
