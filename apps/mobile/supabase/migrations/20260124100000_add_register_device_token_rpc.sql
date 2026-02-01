-- Migration: Add RPC function for device token registration
-- This bypasses RLS issues when a device token belongs to another user (device change scenario)

-- Drop existing function if exists
DROP FUNCTION IF EXISTS public.register_device_token(uuid, uuid, text, text);

-- Create the RPC function with SECURITY DEFINER to bypass RLS
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_user_id uuid,
  p_tenant_id uuid,
  p_token text,
  p_platform text DEFAULT 'android'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_existing_id uuid;
  v_now timestamptz := now();
BEGIN
  -- Validate platform
  IF p_platform NOT IN ('android', 'ios', 'other') THEN
    p_platform := 'other';
  END IF;

  -- Check if token already exists for this user
  SELECT id INTO v_existing_id
  FROM device_tokens
  WHERE user_id = p_user_id AND token = p_token;

  IF v_existing_id IS NOT NULL THEN
    -- Token exists for this user, just update timestamps
    UPDATE device_tokens
    SET updated_at = v_now,
        last_seen_at = v_now
    WHERE id = v_existing_id;
    
    RETURN jsonb_build_object(
      'success', true,
      'action', 'updated',
      'id', v_existing_id
    );
  END IF;

  -- Check if token exists for another user (device changed hands)
  SELECT id INTO v_existing_id
  FROM device_tokens
  WHERE token = p_token AND user_id != p_user_id;

  IF v_existing_id IS NOT NULL THEN
    -- Delete the old token record (device now belongs to new user)
    DELETE FROM device_tokens WHERE id = v_existing_id;
  END IF;

  -- Delete old tokens for this user (keep only the current device)
  DELETE FROM device_tokens
  WHERE user_id = p_user_id AND token != p_token;

  -- Insert new token
  INSERT INTO device_tokens (user_id, tenant_id, token, platform, updated_at, last_seen_at)
  VALUES (p_user_id, p_tenant_id, p_token, p_platform, v_now, v_now)
  RETURNING id INTO v_existing_id;

  RETURN jsonb_build_object(
    'success', true,
    'action', 'inserted',
    'id', v_existing_id
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.register_device_token(uuid, uuid, text, text) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION public.register_device_token IS 
'Registers a device token for push notifications. 
Handles device ownership changes by removing old records.
Uses SECURITY DEFINER to bypass RLS restrictions.';
