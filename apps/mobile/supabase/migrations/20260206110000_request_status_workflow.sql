-- Extend request_status enum with 'rejected' and 'failed' states
-- Current states: pending, in_progress, resolved, cancelled
-- New states: rejected (reddedildi), failed (tamamlanamadı)

-- Add new enum values
ALTER TYPE public.request_status ADD VALUE IF NOT EXISTS 'rejected';
ALTER TYPE public.request_status ADD VALUE IF NOT EXISTS 'failed';

-- Create a function to get target users (managers and admins) for requests
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
    v_user_branch_id uuid;
    v_region_id uuid;
BEGIN
    -- Get current user's tenant and branch
    SELECT u.tenant_id, u.branch_id INTO v_tenant_id, v_user_branch_id
    FROM users u
    WHERE u.id = auth.uid();

    -- Use provided branch_id or current user's branch
    v_user_branch_id := COALESCE(p_branch_id, v_user_branch_id);

    -- Get branch's region
    SELECT b.region_id INTO v_region_id
    FROM branches b
    WHERE b.id = v_user_branch_id;

    RETURN QUERY
    SELECT 
        u.id AS user_id,
        CONCAT(u.first_name, ' ', u.last_name) AS user_name,
        u.role::text AS user_role,
        COALESCE(b.name, 'Merkez') AS branch_name
    FROM users u
    LEFT JOIN branches b ON b.id = u.branch_id
    WHERE u.tenant_id = v_tenant_id
    AND u.active = true
    AND u.id != auth.uid()  -- Exclude current user
    AND (
        -- Firma admin (headquarters)
        u.role = 'firma_admin'
        -- Region manager of user's region
        OR (u.role = 'bolge_muduru' AND EXISTS (
            SELECT 1 FROM regions r WHERE r.manager_id = u.id AND r.id = v_region_id
        ))
        -- Branch manager of user's branch
        OR (u.role = 'sube_muduru' AND u.branch_id = v_user_branch_id AND u.id != auth.uid())
    )
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_request_target_users(uuid) TO authenticated;

-- Create function to update request status with workflow validation
CREATE OR REPLACE FUNCTION public.update_request_status(
    p_request_id uuid,
    p_status text,
    p_resolution_note text DEFAULT NULL
)
RETURNS public.branch_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_request branch_requests;
    v_current_user_id uuid := auth.uid();
    v_user_role text;
    v_is_target boolean;
BEGIN
    -- Get the request
    SELECT * INTO v_request FROM branch_requests WHERE id = p_request_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Talep bulunamadı';
    END IF;

    -- Get current user's role
    SELECT role::text INTO v_user_role FROM users WHERE id = v_current_user_id;

    -- Check if current user is the target or has admin role
    v_is_target := (v_request.target_user_id = v_current_user_id)
        OR v_user_role IN ('firma_admin', 'grand_admin')
        OR (v_user_role = 'bolge_muduru')
        OR (v_user_role = 'sube_muduru');

    IF NOT v_is_target THEN
        RAISE EXCEPTION 'Bu talebi güncelleme yetkiniz yok';
    END IF;

    -- Validate status transition
    CASE v_request.status::text
        WHEN 'pending' THEN
            IF p_status NOT IN ('in_progress', 'rejected', 'cancelled') THEN
                RAISE EXCEPTION 'Bekleyen talep sadece işleme alınabilir veya reddedilebilir';
            END IF;
        WHEN 'in_progress' THEN
            IF p_status NOT IN ('resolved', 'failed', 'cancelled') THEN
                RAISE EXCEPTION 'İşlemdeki talep sadece tamamlanabilir veya tamamlanamadı olarak işaretlenebilir';
            END IF;
        ELSE
            RAISE EXCEPTION 'Bu talep artık güncellenemez';
    END CASE;

    -- Update the request
    UPDATE branch_requests
    SET 
        status = p_status::request_status,
        resolved_by = v_current_user_id,
        resolved_at = NOW(),
        payload = CASE 
            WHEN p_resolution_note IS NOT NULL 
            THEN COALESCE(payload, '{}'::jsonb) || jsonb_build_object('resolution_note', p_resolution_note)
            ELSE payload
        END,
        updated_at = NOW()
    WHERE id = p_request_id
    RETURNING * INTO v_request;

    RETURN v_request;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.update_request_status(uuid, text, text) TO authenticated;

-- Add target_user_id column if not exists (should exist based on model)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'branch_requests' 
        AND column_name = 'target_user_id'
    ) THEN
        ALTER TABLE branch_requests ADD COLUMN target_user_id uuid REFERENCES users(id);
        CREATE INDEX idx_branch_requests_target_user_id ON branch_requests(target_user_id);
    END IF;
END;
$$;
