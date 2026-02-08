-- ============================================================================
-- Fix notifications table schema compatibility
-- The original table has 'message' column, but new functions expect 'body'
-- Also need to add 'data' jsonb column
-- Also add is_active to announcements for consistency
-- ============================================================================

-- 0. Add is_active to announcements table (rename from active for consistency)
DO $$
BEGIN
  -- Check if announcements has 'active' but not 'is_active'
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'announcements' 
    AND column_name = 'active'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'announcements' 
    AND column_name = 'is_active'
  ) THEN
    -- Add is_active column
    ALTER TABLE announcements ADD COLUMN is_active boolean DEFAULT true;
    -- Copy data from active
    UPDATE announcements SET is_active = active;
  END IF;
END $$;

-- 1. Add 'body' column as alias/replacement for 'message'
-- First check if 'body' already exists (from notification_system migration)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'body'
  ) THEN
    -- Add body column
    ALTER TABLE notifications ADD COLUMN body text;
    
    -- Copy existing message data to body
    UPDATE notifications SET body = message WHERE message IS NOT NULL;
  END IF;
END $$;

-- 2. Add 'data' jsonb column if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'notifications' 
    AND column_name = 'data'
  ) THEN
    ALTER TABLE notifications ADD COLUMN data jsonb DEFAULT '{}';
  END IF;
END $$;

-- 3. Ensure type column can handle notification_type enum values
-- The original table has type as text, which is fine - enum can be cast to text
-- But functions insert with enum type, so we need to make sure it's compatible

-- 4. Create index for data column if needed
CREATE INDEX IF NOT EXISTS idx_notifications_data ON notifications USING gin(data);

-- 5. Update send_notification function to use text type for compatibility
CREATE OR REPLACE FUNCTION send_notification(
  p_tenant_id uuid,
  p_user_ids uuid[],
  p_type text,  -- Changed from notification_type to text for compatibility
  p_title text,
  p_body text DEFAULT NULL,
  p_data jsonb DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_notification_id uuid;
  v_device_token record;
  v_notifications_created int := 0;
  v_queue_items_created int := 0;
  v_notification_pref text;
  v_pref_key text;
BEGIN
  -- Map notification type to preference key
  v_pref_key := CASE p_type
    WHEN 'visual_audit_task' THEN 'gorevler'
    WHEN 'visual_audit_photo' THEN 'gorevler'
    WHEN 'visual_audit_comment' THEN 'gorevler'
    WHEN 'visual_audit_completed' THEN 'gorevler'
    WHEN 'task_assigned' THEN 'gorevler'
    WHEN 'task_completed' THEN 'gorevler'
    WHEN 'task_approved' THEN 'gorevler'
    WHEN 'announcement' THEN 'duyurular'
    WHEN 'survey' THEN 'duyurular'
    WHEN 'skt_warning' THEN 'skt'
    WHEN 'depot_transfer' THEN 'depo'
    ELSE 'general'
  END;

  -- Process each user
  FOREACH v_user_id IN ARRAY p_user_ids
  LOOP
    -- Check user notification preferences (skip if function doesn't have access)
    BEGIN
      SELECT raw_user_meta_data->'notification_preferences'->>v_pref_key
      INTO v_notification_pref
      FROM auth.users
      WHERE id = v_user_id;
    EXCEPTION WHEN OTHERS THEN
      v_notification_pref := NULL;
    END;

    -- Skip if user disabled this notification type (null = enabled by default)
    IF v_notification_pref = 'false' THEN
      CONTINUE;
    END IF;

    -- Create notification record
    INSERT INTO notifications (tenant_id, user_id, type, title, body, data)
    VALUES (p_tenant_id, v_user_id, p_type, p_title, p_body, p_data)
    RETURNING id INTO v_notification_id;
    
    v_notifications_created := v_notifications_created + 1;

    -- Queue FCM notification for each device (if device_tokens table exists)
    BEGIN
      FOR v_device_token IN
        SELECT id, token, platform
        FROM device_tokens
        WHERE user_id = v_user_id
          AND updated_at > now() - interval '30 days'
      LOOP
        INSERT INTO notification_queue (device_token_id, notification_id, title, body, data)
        VALUES (
          v_device_token.id,
          v_notification_id,
          p_title,
          p_body,
          jsonb_build_object(
            'type', p_type,
            'notification_id', v_notification_id
          ) || COALESCE(p_data, '{}'::jsonb)
        );
        
        v_queue_items_created := v_queue_items_created + 1;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      -- device_tokens or notification_queue may not exist yet
      NULL;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'notifications_created', v_notifications_created,
    'queue_items_created', v_queue_items_created
  );
END;
$$;

-- 6. Update notify_announcement_published trigger to use text type
-- This is a simplified version that works with the existing announcements table schema
CREATE OR REPLACE FUNCTION notify_announcement_published()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_ids uuid[];
  v_notification_type text := 'announcement';
  v_title text;
  v_body text;
BEGIN
  -- Only trigger on publish (is_active changes to true or new record with is_active=true)
  IF NEW.is_active = true AND (OLD IS NULL OR OLD.is_active IS NULL OR OLD.is_active = false) THEN
    
    v_title := 'Yeni Duyuru';
    v_body := NEW.title;
    
    -- Get target users based on roles and branches
    SELECT array_agg(DISTINCT u.id)
    INTO v_user_ids
    FROM users u
    WHERE u.tenant_id = NEW.tenant_id
      AND u.is_active = true
      AND (
        -- Role filter
        NEW.target_roles IS NULL 
        OR array_length(NEW.target_roles, 1) IS NULL 
        OR u.role::text = ANY(NEW.target_roles)
      )
      AND (
        -- Branch filter
        NEW.target_branches IS NULL 
        OR array_length(NEW.target_branches, 1) IS NULL 
        OR u.branch_id = ANY(NEW.target_branches)
      );
    
    -- Send notifications
    IF v_user_ids IS NOT NULL AND array_length(v_user_ids, 1) > 0 THEN
      PERFORM send_notification(
        NEW.tenant_id,
        v_user_ids,
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

-- 7. Ensure trigger exists on announcements table
DROP TRIGGER IF EXISTS trigger_notify_announcement_published ON announcements;
CREATE TRIGGER trigger_notify_announcement_published
  AFTER INSERT OR UPDATE OF is_active ON announcements
  FOR EACH ROW
  EXECUTE FUNCTION notify_announcement_published();
