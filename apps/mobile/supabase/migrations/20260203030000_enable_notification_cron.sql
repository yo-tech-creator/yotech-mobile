-- =====================================================
-- ENABLE CRON JOB: Send pending push notifications
-- =====================================================

-- Enable the cron job to run every minute
SELECT cron.schedule(
  'send-push-notifications',
  '* * * * *',  -- Every minute
  $$SELECT public.trigger_send_push_notifications()$$
);

-- Verify the job is scheduled
-- SELECT * FROM cron.job;
