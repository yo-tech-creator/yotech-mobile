-- ============================================================================
-- FIX v2: Completely recreate get_bug_reports function
-- ============================================================================

-- Drop the function completely
DROP FUNCTION IF EXISTS public.get_bug_reports(TEXT, INT, INT);

-- Recreate with proper column aliasing
CREATE FUNCTION public.get_bug_reports(
    p_status TEXT DEFAULT NULL,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    report_id UUID,
    report_tenant_id UUID,
    report_tenant_name TEXT,
    report_user_id UUID,
    report_user_name TEXT,
    report_user_email TEXT,
    report_title TEXT,
    report_description TEXT,
    report_device_info JSONB,
    report_app_version TEXT,
    report_status TEXT,
    report_priority TEXT,
    report_admin_notes TEXT,
    report_resolved_by UUID,
    report_resolved_by_name TEXT,
    report_resolved_at TIMESTAMPTZ,
    report_created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_role TEXT;
BEGIN
    v_user_id := auth.uid();
    
    SELECT role INTO v_role
    FROM public.users
    WHERE public.users.id = v_user_id;
    
    IF v_role != 'grand_admin' THEN
        RAISE EXCEPTION 'Bu işlem için yetkiniz yok';
    END IF;
    
    RETURN QUERY
    SELECT 
        br.id,
        br.tenant_id,
        t.name::TEXT,
        br.user_id,
        (u.first_name || ' ' || u.last_name)::TEXT,
        au.email::TEXT,
        br.title::TEXT,
        br.description::TEXT,
        br.device_info,
        br.app_version::TEXT,
        br.status::TEXT,
        br.priority::TEXT,
        br.admin_notes::TEXT,
        br.resolved_by,
        (ru.first_name || ' ' || ru.last_name)::TEXT,
        br.resolved_at,
        br.created_at
    FROM public.bug_reports br
    LEFT JOIN public.tenants t ON t.id = br.tenant_id
    LEFT JOIN public.users u ON u.id = br.user_id
    LEFT JOIN auth.users au ON au.id = br.user_id
    LEFT JOIN public.users ru ON ru.id = br.resolved_by
    WHERE (p_status IS NULL OR br.status = p_status)
    ORDER BY 
        CASE br.priority 
            WHEN 'critical' THEN 1 
            WHEN 'high' THEN 2 
            WHEN 'normal' THEN 3 
            ELSE 4 
        END,
        br.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$;
