-- Fix get_request_target_users function to work properly
-- The previous version had too complex conditions that returned empty results

CREATE OR REPLACE FUNCTION public.get_request_target_users(p_branch_id uuid DEFAULT NULL)
RETURNS TABLE (
    user_id uuid,
    user_name text,
    user_role text,
    branch_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_tenant_id uuid;
    v_current_user_id uuid;
BEGIN
    v_current_user_id := auth.uid();
    
    -- Get current user's tenant
    SELECT u.tenant_id INTO v_tenant_id
    FROM users u
    WHERE u.id = v_current_user_id;

    IF v_tenant_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        u.id AS user_id,
        CONCAT(COALESCE(u.first_name, ''), ' ', COALESCE(u.last_name, ''))::text AS user_name,
        u.role::text AS user_role,
        COALESCE(b.name, 'Merkez')::text AS branch_name
    FROM users u
    LEFT JOIN branches b ON b.id = u.branch_id
    WHERE u.tenant_id = v_tenant_id
    AND u.active = true
    AND u.id != v_current_user_id  -- Exclude current user
    AND u.role IN ('firma_admin', 'bolge_muduru', 'sube_muduru')  -- Only managers
    ORDER BY 
        CASE u.role 
            WHEN 'firma_admin' THEN 1
            WHEN 'bolge_muduru' THEN 2
            WHEN 'sube_muduru' THEN 3
            ELSE 4
        END,
        u.first_name;
END;
$$;

-- Ensure permissions
GRANT EXECUTE ON FUNCTION public.get_request_target_users(uuid) TO authenticated;

-- Add target_user_id column to branch_requests if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'branch_requests' 
        AND column_name = 'target_user_id'
    ) THEN
        ALTER TABLE public.branch_requests 
        ADD COLUMN target_user_id uuid REFERENCES public.users(id);
    END IF;
END $$;
