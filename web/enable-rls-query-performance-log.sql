-- ============================================
-- MIGRATION: Enable RLS on query_performance_log
-- ============================================
-- This migration enables Row Level Security on the query_performance_log table
-- to fix the security issue where the table was publicly accessible without RLS.
--
-- Since this is a performance logging table, we enable RLS but don't create
-- public policies. Only service_role will have access by default.
-- If specific access patterns are needed, policies can be added in the future.

ALTER TABLE public.query_performance_log ENABLE ROW LEVEL SECURITY;

-- Optional: If authenticated users need read access to their own query logs,
-- uncomment the following policy:
--
-- CREATE POLICY "query_performance_log_select_own" ON query_performance_log
--     FOR SELECT USING (auth.uid() = user_id);
--
-- Note: This assumes the table has a user_id column. Adjust as needed.
