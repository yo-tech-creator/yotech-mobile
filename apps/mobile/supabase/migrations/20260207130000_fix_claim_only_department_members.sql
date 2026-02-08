-- Migration: Fix claim_request to allow only department members
-- Sadece departman üyeleri talep işleme alabilir (claim)

-- Talep atama fonksiyonunu güncelle (claim) - Sadece departman üyeleri alabilir
CREATE OR REPLACE FUNCTION "public"."claim_request"(
    p_request_id uuid
)
RETURNS "public"."branch_requests" AS $$
DECLARE
    v_request "public"."branch_requests";
    v_user_id uuid := auth.uid();
    v_user_department_id uuid;
    v_request_target_dept_id uuid;
BEGIN
    -- Kullanıcının departman ID'sini al
    SELECT department_id INTO v_user_department_id
    FROM "public"."users"
    WHERE id = v_user_id;
    
    -- Talebin hedef departman ID'sini al
    SELECT target_department_id INTO v_request_target_dept_id
    FROM "public"."branch_requests"
    WHERE id = p_request_id;
    
    -- Kullanıcı bir departmana ait değilse hata ver
    IF v_user_department_id IS NULL THEN
        RAISE EXCEPTION 'Sadece departman üyeleri talep işleme alabilir.';
    END IF;
    
    -- Talep bir departmana atanmış ve kullanıcı o departmanda değilse hata ver
    IF v_request_target_dept_id IS NOT NULL AND v_request_target_dept_id != v_user_department_id THEN
        RAISE EXCEPTION 'Bu talep sizin departmanınıza atanmamış.';
    END IF;
    
    -- Talep bir departmana atanmamışsa, sadece target_user_id ile eşleşen kullanıcı alabilir
    IF v_request_target_dept_id IS NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM "public"."branch_requests" 
            WHERE id = p_request_id 
            AND (target_user_id = v_user_id OR target_user_id IS NULL)
        ) THEN
            RAISE EXCEPTION 'Bu talep size atanmamış.';
        END IF;
    END IF;
    
    -- Talebi kontrol et ve ata
    UPDATE "public"."branch_requests"
    SET 
        assigned_to = v_user_id,
        assigned_at = now(),
        status = CASE 
            WHEN status = 'pending' THEN 'in_progress'::public.request_status
            ELSE status
        END,
        updated_at = now()
    WHERE id = p_request_id
    AND assigned_to IS NULL
    AND created_by != v_user_id -- Kendi talebini alamaz
    AND status = 'pending' -- Sadece bekleyen talepler alınabilir
    RETURNING * INTO v_request;
    
    IF v_request IS NULL THEN
        RAISE EXCEPTION 'Talep atanamadı. Talep zaten atanmış, beklemede değil veya mevcut değil.';
    END IF;
    
    RETURN v_request;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
