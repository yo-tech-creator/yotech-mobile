-- Migration: Add missing foreign key indexes
-- Purpose: Improve performance for JOINs and CASCADE operations
-- These indexes are safe to add and don't affect existing functionality

-- ============================================================
-- PART 1: ADD MISSING FOREIGN KEY INDEXES (SAFE)
-- ============================================================

-- branch_requests table
CREATE INDEX IF NOT EXISTS idx_branch_requests_resolved_by 
  ON public.branch_requests(resolved_by);

CREATE INDEX IF NOT EXISTS idx_branch_requests_target_user_id 
  ON public.branch_requests(target_user_id);

-- break_sessions table
CREATE INDEX IF NOT EXISTS idx_break_sessions_tenant_id 
  ON public.break_sessions(tenant_id);

-- depot_notice_offers table
CREATE INDEX IF NOT EXISTS idx_depot_notice_offers_branch_id 
  ON public.depot_notice_offers(branch_id);

CREATE INDEX IF NOT EXISTS idx_depot_notice_offers_decision_by 
  ON public.depot_notice_offers(decision_by);

CREATE INDEX IF NOT EXISTS idx_depot_notice_offers_offered_by 
  ON public.depot_notice_offers(offered_by);

CREATE INDEX IF NOT EXISTS idx_depot_notice_offers_tenant_id 
  ON public.depot_notice_offers(tenant_id);

-- depot_notices table
CREATE INDEX IF NOT EXISTS idx_depot_notices_branch_id 
  ON public.depot_notices(branch_id);

CREATE INDEX IF NOT EXISTS idx_depot_notices_created_by 
  ON public.depot_notices(created_by);

-- merch_people table
CREATE INDEX IF NOT EXISTS idx_merch_people_created_by 
  ON public.merch_people(created_by);

CREATE INDEX IF NOT EXISTS idx_merch_people_tenant_id 
  ON public.merch_people(tenant_id);

-- skt_alarm_notifications table
CREATE INDEX IF NOT EXISTS idx_skt_alarm_notifications_record_id 
  ON public.skt_alarm_notifications(record_id);

CREATE INDEX IF NOT EXISTS idx_skt_alarm_notifications_user_id 
  ON public.skt_alarm_notifications(user_id);

-- skt_records table
CREATE INDEX IF NOT EXISTS idx_skt_records_deleted_by 
  ON public.skt_records(deleted_by);

-- store_scoring_form_versions table
CREATE INDEX IF NOT EXISTS idx_store_scoring_form_versions_created_by 
  ON public.store_scoring_form_versions(created_by);

-- store_scoring_forms table
CREATE INDEX IF NOT EXISTS idx_store_scoring_forms_created_by 
  ON public.store_scoring_forms(created_by);

-- store_scoring_session_items table
CREATE INDEX IF NOT EXISTS idx_store_scoring_session_items_item_id 
  ON public.store_scoring_session_items(item_id);

-- store_scoring_sessions table
CREATE INDEX IF NOT EXISTS idx_store_scoring_sessions_form_version_id 
  ON public.store_scoring_sessions(form_version_id);

-- tenant_modules table
CREATE INDEX IF NOT EXISTS idx_tenant_modules_enabled_by 
  ON public.tenant_modules(enabled_by);

CREATE INDEX IF NOT EXISTS idx_tenant_modules_module_code 
  ON public.tenant_modules(module_code);


-- ============================================================
-- PART 2: UNUSED INDEXES (OPTIONAL - COMMENTED OUT)
-- ============================================================
-- These indexes have never been used according to pg_stat_user_indexes.
-- However, removing them may cause issues if:
--   1. The application is still in development
--   2. Some features haven't been used yet
--   3. Queries will be added in the future
-- 
-- Benefits of removing unused indexes:
--   - Reduced storage space
--   - Faster INSERT/UPDATE/DELETE operations
--
-- Risks of removing:
--   - Queries may become slow if they start using these columns
--
-- UNCOMMENT ONLY IF YOU'RE SURE THESE INDEXES ARE NOT NEEDED:
--
-- DROP INDEX IF EXISTS public.idx_employee_score_period;
-- DROP INDEX IF EXISTS public.idx_branch_score_tenant_branch;
-- DROP INDEX IF EXISTS public.device_tokens_token_idx;
-- DROP INDEX IF EXISTS public.idx_attendance_tenant_branch;
-- DROP INDEX IF EXISTS public.idx_attendance_date;
-- DROP INDEX IF EXISTS public.idx_break_tenant_branch;
-- DROP INDEX IF EXISTS public.idx_tasks_status;
-- DROP INDEX IF EXISTS public.idx_tasks_due_date;
-- DROP INDEX IF EXISTS public.idx_shifts_week;
-- DROP INDEX IF EXISTS public.idx_leave_tenant_branch;
-- DROP INDEX IF EXISTS public.idx_leave_dates;
-- DROP INDEX IF EXISTS public.idx_form_templates_tenant;
-- DROP INDEX IF EXISTS public.idx_form_submissions_tenant_branch;
-- DROP INDEX IF EXISTS public.idx_form_submissions_template;
-- DROP INDEX IF EXISTS public.idx_malfunction_tenant_branch;
-- DROP INDEX IF EXISTS public.idx_malfunction_status;
-- DROP INDEX IF EXISTS public.idx_product_issue_tenant_branch;
-- DROP INDEX IF EXISTS public.idx_product_issue_status;
-- DROP INDEX IF EXISTS public.idx_employee_score_tenant_user;
-- DROP INDEX IF EXISTS public.idx_stockout_lists_tenant_branch;
-- DROP INDEX IF EXISTS public.idx_stockout_items_list;
-- DROP INDEX IF EXISTS public.idx_payroll_tenant_user;
-- DROP INDEX IF EXISTS public.idx_payroll_period;
-- DROP INDEX IF EXISTS public.idx_announcements_tenant;
-- DROP INDEX IF EXISTS public.idx_announcements_published;
-- DROP INDEX IF EXISTS public.idx_notifications_tenant_user;
-- DROP INDEX IF EXISTS public.idx_notifications_read;
-- DROP INDEX IF EXISTS public.idx_notifications_created;
-- DROP INDEX IF EXISTS public.idx_health_reports_tenant_id;
-- DROP INDEX IF EXISTS public.idx_products_name_trgm;
-- DROP INDEX IF EXISTS public.skt_records_deleted_at_idx;
-- DROP INDEX IF EXISTS public.idx_store_scoring_sessions_evaluated_user_id;
-- DROP INDEX IF EXISTS public.idx_todos_owner_id;
-- DROP INDEX IF EXISTS public.idx_todos_parent_id;
-- DROP INDEX IF EXISTS public.idx_branch_requests_status;
-- DROP INDEX IF EXISTS public.idx_branch_requests_category;
-- DROP INDEX IF EXISTS public.idx_shift_pattern_drafts_tenant_user;
-- DROP INDEX IF EXISTS public.idx_tasks_approved_by;
-- DROP INDEX IF EXISTS public.idx_task_attachments_uploaded_by;
