-- ============================================================
-- Security & Performance Advisor Fixes
-- Date: 2026-01-29
-- ============================================================

-- ============================================================
-- PART 1: FIX SECURITY DEFINER VIEW (ERROR)
-- The view v_survey_statistics is using SECURITY DEFINER which 
-- bypasses RLS. We need to recreate it as SECURITY INVOKER.
-- ============================================================

DROP VIEW IF EXISTS public.v_survey_statistics;

CREATE OR REPLACE VIEW public.v_survey_statistics 
WITH (security_invoker = true)
AS
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
      AND u.active = true
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

-- ============================================================
-- PART 2: FIX FUNCTION SEARCH_PATH (WARNINGS)
-- Set search_path to prevent SQL injection via search path
-- ============================================================

-- Fix get_current_user_profile
DROP FUNCTION IF EXISTS public.get_current_user_profile();
CREATE OR REPLACE FUNCTION public.get_current_user_profile()
RETURNS TABLE(branch_id uuid, tenant_id uuid, region_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT u.branch_id, u.tenant_id, b.region_id
    FROM public.users u
    LEFT JOIN public.branches b ON b.id = u.branch_id
    WHERE u.id = auth.uid();
END;
$$;

-- Fix get_tenant_regions
DROP FUNCTION IF EXISTS public.get_tenant_regions();
CREATE OR REPLACE FUNCTION public.get_tenant_regions()
RETURNS TABLE (id uuid, name text)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  SELECT u.tenant_id INTO v_tenant_id FROM public.users u WHERE u.id = auth.uid();
  
  RETURN QUERY
  SELECT r.id, r.name
  FROM public.regions r
  WHERE r.tenant_id = v_tenant_id
  ORDER BY r.name;
END;
$$;

-- Fix get_tenant_branches (both versions - with and without parameter)
DROP FUNCTION IF EXISTS public.get_tenant_branches();
DROP FUNCTION IF EXISTS public.get_tenant_branches(uuid);

CREATE OR REPLACE FUNCTION public.get_tenant_branches()
RETURNS TABLE (id uuid, name text, region_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  SELECT u.tenant_id INTO v_tenant_id FROM public.users u WHERE u.id = auth.uid();
  
  RETURN QUERY
  SELECT b.id, b.name, b.region_id
  FROM public.branches b
  WHERE b.tenant_id = v_tenant_id
    AND b.active = true
  ORDER BY b.name;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_tenant_branches(p_tenant_id uuid)
RETURNS TABLE(id uuid, name text, region_id uuid, code text)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_tenant_id uuid;
BEGIN
    v_tenant_id := COALESCE(p_tenant_id, (SELECT u.tenant_id FROM public.users u WHERE u.id = auth.uid()));

    RETURN QUERY
    SELECT b.id, b.name, b.region_id, b.code
    FROM public.branches b
    WHERE b.tenant_id = v_tenant_id
      AND b.active = true
    ORDER BY b.name;
END;
$$;

-- Fix get_branch_personnel
DROP FUNCTION IF EXISTS public.get_branch_personnel(uuid);
CREATE OR REPLACE FUNCTION public.get_branch_personnel(p_branch_id uuid)
RETURNS TABLE (
  id uuid,
  first_name text,
  last_name text,
  role text,
  branch_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.first_name, u.last_name, u.role::text, u.branch_id
  FROM public.users u
  WHERE u.branch_id = p_branch_id
    AND u.role = 'personel'
  ORDER BY u.first_name;
END;
$$;

-- Re-grant permissions
GRANT EXECUTE ON FUNCTION public.get_current_user_profile() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tenant_regions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tenant_branches() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tenant_branches(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_branch_personnel(uuid) TO authenticated;

-- ============================================================
-- PART 3: FIX DUPLICATE PERMISSIVE POLICIES (PERFORMANCE)
-- Merge multiple permissive policies into single optimized ones
-- ============================================================

-- Drop all existing announcement_reads policies
DROP POLICY IF EXISTS "Users can insert their own reads" ON public.announcement_reads;
DROP POLICY IF EXISTS "Users can view their own reads" ON public.announcement_reads;
DROP POLICY IF EXISTS "Managers can view all reads" ON public.announcement_reads;
DROP POLICY IF EXISTS "announcement_reads_owner" ON public.announcement_reads;
DROP POLICY IF EXISTS "announcement_reads_owner_write" ON public.announcement_reads;

-- Create single optimized SELECT policy (combining owner + manager views)
-- Using (SELECT auth.uid()) pattern for performance
CREATE POLICY "announcement_reads_select" ON public.announcement_reads
FOR SELECT USING (
  -- User can see their own reads
  user_id = (SELECT auth.uid())
  OR
  -- Managers can see all reads for their tenant's announcements
  EXISTS (
    SELECT 1 
    FROM public.users u
    JOIN public.announcements a ON a.id = announcement_reads.announcement_id
    WHERE u.id = (SELECT auth.uid())
      AND u.tenant_id = a.tenant_id
      AND u.role IN ('firma_admin', 'bolge_muduru', 'sube_muduru')
  )
);

-- Create single optimized INSERT policy
-- Using (SELECT auth.uid()) pattern for performance
CREATE POLICY "announcement_reads_insert" ON public.announcement_reads
FOR INSERT WITH CHECK (
  user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.announcements a
    JOIN public.users u ON u.id = (SELECT auth.uid())
    WHERE a.id = announcement_reads.announcement_id
      AND a.tenant_id = u.tenant_id
      AND (
        a.target_branches IS NULL 
        OR cardinality(a.target_branches) = 0
        OR u.branch_id = ANY(a.target_branches)
      )
      AND (
        a.target_roles IS NULL 
        OR cardinality(a.target_roles) = 0
        OR u.role = ANY(a.target_roles)
      )
  )
);

-- ============================================================
-- PART 4: FIX DUPLICATE INDEX (PERFORMANCE)
-- Remove the duplicate constraint (keeping the original unique key)
-- ============================================================

-- Drop the duplicate unique constraint (not just the index)
ALTER TABLE public.announcement_reads 
DROP CONSTRAINT IF EXISTS announcement_reads_unique;
-- Keep announcement_reads_announcement_id_user_id_key as it's the original constraint

-- ============================================================
-- PART 5: VERIFY RLS IS ENABLED
-- ============================================================

ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;
