-- ============================================
-- DIAGNOSTICS: database size (read-only)
-- ============================================
-- Run from the Supabase SQL Editor before and after the cleanup in
-- supabase-migration-db-retention.sql to see where the space goes.
-- The Free plan limit is 500 MB (pg_database_size).
--
-- The SQL Editor only shows the result of the LAST statement: select one
-- query at a time and run the selection to see each result.
--
-- If the project has already been switched to read-only because it is
-- over quota, run this first in the same SQL Editor session:
--   set session characteristics as transaction read write;

-- 1. Total database size
select pg_size_pretty(pg_database_size(current_database())) as database_size;

-- 2. Tables by total size (heap + TOAST + indexes)
select
    schemaname || '.' || relname                               as table_name,
    pg_size_pretty(pg_total_relation_size(relid))              as total,
    pg_size_pretty(pg_relation_size(relid))                    as heap,
    pg_size_pretty(pg_total_relation_size(relid)
                   - pg_relation_size(relid)
                   - pg_indexes_size(relid))                   as toast,
    pg_size_pretty(pg_indexes_size(relid))                     as indexes,
    n_live_tup                                                 as live_rows,
    n_dead_tup                                                 as dead_rows,
    last_autovacuum
from pg_stat_user_tables
order by pg_total_relation_size(relid) desc
limit 25;

-- 3. Largest indexes
select
    schemaname || '.' || indexrelname                          as index_name,
    relname                                                    as table_name,
    pg_size_pretty(pg_relation_size(indexrelid))               as size,
    idx_scan                                                   as scans_since_stats_reset
from pg_stat_user_indexes
order by pg_relation_size(indexrelid) desc
limit 25;

-- 4. rss_articles breakdown against the retention policy (14 / 30 / 100)
select
    count(*)                                                                  as total,
    count(*) filter (where is_read)                                           as read,
    count(*) filter (where is_read
        and coalesce(read_at, pub_date, created_at) < now() - interval '14 days') as read_expired,
    count(*) filter (where not coalesce(is_read, false)
        and coalesce(pub_date, created_at) < now() - interval '30 days')      as unread_expired
from public.rss_articles;

-- 5. Is pg_cron enabled? (no rows = not enabled yet; the retention
--    migration enables it). Only when enabled, you can list the jobs with:
--      select jobid, jobname, schedule, command, active from cron.job;
select extname, extversion from pg_extension where extname = 'pg_cron';
