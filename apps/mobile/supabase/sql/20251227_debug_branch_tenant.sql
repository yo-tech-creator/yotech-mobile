-- Debug helpers: inspect branch tenant and log session counts for a tenant.
-- Run in Supabase SQL editor.

SELECT id,
       tenant_id,
       name,
       city,
       created_at
FROM public.branches
WHERE id = 'b47fbc55-781e-48b4-b552-cd6b5a3329f5';

SELECT current_tenant_id() AS tenant,
       current_user_role() AS role;

SELECT COUNT(*) AS session_count
FROM public.store_scoring_sessions
WHERE branch_id = 'b47fbc55-781e-48b4-b552-cd6b5a3329f5';
