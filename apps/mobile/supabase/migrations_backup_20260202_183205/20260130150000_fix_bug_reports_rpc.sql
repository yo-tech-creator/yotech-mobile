-- ============================================================================
-- FIX: Ambiguous column reference in get_bug_reports function
-- ============================================================================

-- First drop the existing function to allow return type change
DROP FUNCTION IF EXISTS public.get_bug_reports(TEXT, INT, INT);

-- Recreate the function with fixed column references
CREATE OR REPLACE FUNCTION public.get_bug_reports(
    p_status TEXT DEFAULT NULL,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    report_id UUID,
    tenant_id UUID,
    tenant_name TEXT,
    user_id UUID,
    user_name TEXT,
    user_email TEXT,
    title TEXT,
    description TEXT,
    device_info JSONB,
    app_version TEXT,
    status TEXT,
    priority TEXT,
    admin_notes TEXT,
    resolved_by UUID,
    resolved_by_name TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
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
        br.id AS report_id,
        br.tenant_id,
        t.name::TEXT AS tenant_name,
        br.user_id,
        (u.first_name || ' ' || u.last_name)::TEXT AS user_name,
        au.email::TEXT AS user_email,
        br.title::TEXT,
        br.description::TEXT,
        br.device_info,
        br.app_version::TEXT,
        br.status::TEXT,
        br.priority::TEXT,
        br.admin_notes::TEXT,
        br.resolved_by,
        (ru.first_name || ' ' || ru.last_name)::TEXT AS resolved_by_name,
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
