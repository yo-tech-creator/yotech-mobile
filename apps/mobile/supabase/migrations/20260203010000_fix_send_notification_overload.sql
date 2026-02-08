-- =====================================================
-- FIX: send_notification function overload
-- =====================================================
-- Drop the text-based version, keep only notification_type version

-- First, check dependencies and drop the text version
DROP FUNCTION IF EXISTS public.send_notification(uuid, uuid[], text, text, text, jsonb);

-- The notification_type version will remain
-- public.send_notification(uuid, uuid[], notification_type, text, text, jsonb)

-- Update notify_announcement_published to use the correct type
CREATE OR REPLACE FUNCTION public.notify_announcement_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_target_users uuid[];
  v_notification_type notification_type := 'announcement';
  v_title text;
  v_body text;
BEGIN
  IF NEW.is_active = true AND (OLD IS NULL OR OLD.is_active IS NULL OR OLD.is_active = false) THEN
    
    v_title := 'Yeni Duyuru';
    v_body := NEW.title;

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
        jsonb_build_object('announcement_id', NEW.id)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;
