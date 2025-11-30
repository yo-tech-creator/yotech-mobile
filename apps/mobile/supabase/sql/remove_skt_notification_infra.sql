begin;

-- Remove SKT-specific notification log and helper types.
drop table if exists public.skt_alarm_notifications cascade;
drop type if exists public.skt_alarm_stage cascade;

drop function if exists public.dispatch_skt_alarm_notifications();

-- These columns only served the legacy push dispatcher. Keeping alarm_days_before
-- so users can continue to configure uyarı aralığı while listelerden takip ediliyor.
alter table public.skt_records
  drop column if exists alarm_warn_sent,
  drop column if exists alarm_warn_sent_at,
  drop column if exists alarm_due_sent,
  drop column if exists alarm_due_sent_at,
  drop column if exists alarm_sent;

commit;
