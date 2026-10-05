-- ============================================
-- MIGRATION: DB retention (keep the project under the Free plan 500 MB)
-- ============================================
-- rss_articles was ~53% of the database and grew unbounded: the Vercel
-- cron (/api/cleanup-rss) ran with the anon key and RLS made it delete
-- nothing, and cleanup_old_rss_articles was never scheduled.
--
-- This migration (idempotent, run from the Supabase SQL Editor):
--   1. cleanup_rss_articles(): read > 14 days, unread > 30 days,
--      more than 100 items per (user, feed)
--   2. trigger that stops the RSS sync from re-inserting expired items
--      that are still published in the feed XML
--   3. cleanup_logs(): query_performance_log > 7 days,
--      activity_feed > 90 days
--   4. drops idx_articles_content_trigram (unused by web and iOS)
--   5. drops the superseded cleanup_old_rss_articles()
--   6. schedules everything nightly with pg_cron (03:30 UTC)
--
-- DELETE does not shrink the database size on its own. After the first
-- run, reclaim the space once (see the bottom of this file).

-- ============================================
-- 1. RSS articles retention
-- ============================================
create or replace function public.cleanup_rss_articles(
    p_read_days     integer default 14,
    p_unread_days   integer default 30,
    p_max_per_feed  integer default 100,
    p_batch         integer default 5000
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
    v_read     integer := 0;
    v_unread   integer := 0;
    v_trimmed  integer := 0;
    v_batch    integer;
    v_read_cutoff   timestamptz := now() - make_interval(days => p_read_days);
    v_unread_cutoff timestamptz := now() - make_interval(days => p_unread_days);
begin
    -- Read items past the read retention
    loop
        delete from public.rss_articles
        where id in (
            select id from public.rss_articles
            where is_read = true
              and coalesce(read_at, pub_date, created_at) < v_read_cutoff
            limit p_batch
        );
        get diagnostics v_batch = row_count;
        v_read := v_read + v_batch;
        exit when v_batch = 0;
    end loop;

    -- Unread items past the unread retention
    loop
        delete from public.rss_articles
        where id in (
            select id from public.rss_articles
            where coalesce(is_read, false) = false
              and coalesce(pub_date, created_at) < v_unread_cutoff
            limit p_batch
        );
        get diagnostics v_batch = row_count;
        v_unread := v_unread + v_batch;
        exit when v_batch = 0;
    end loop;

    -- Keep only the newest N items per (user, feed)
    loop
        delete from public.rss_articles
        where id in (
            select id from (
                select id,
                       row_number() over (
                           partition by user_id, feed_id
                           order by pub_date desc nulls last, created_at desc
                       ) as rn
                from public.rss_articles
            ) ranked
            where rn > p_max_per_feed
            limit p_batch
        );
        get diagnostics v_batch = row_count;
        v_trimmed := v_trimmed + v_batch;
        exit when v_batch = 0;
    end loop;

    return jsonb_build_object(
        'read_expired',   v_read,
        'unread_expired', v_unread,
        'trimmed',        v_trimmed,
        'total',          v_read + v_unread + v_trimmed
    );
end;
$fn$;

revoke all on function public.cleanup_rss_articles(integer, integer, integer, integer)
    from public, anon, authenticated;
grant execute on function public.cleanup_rss_articles(integer, integer, integer, integer)
    to service_role;

-- ============================================
-- 2. Do not re-insert expired items on sync
-- ============================================
-- Web (syncRSSArticles) and iOS (upsertRSSArticles) upsert every item
-- still present in the feed XML with ignoreDuplicates. Without this,
-- an item deleted by the retention comes back as unread on the next
-- refresh. Keep the interval aligned with p_unread_days above.
create or replace function public.rss_articles_skip_expired()
returns trigger
language plpgsql
set search_path = public
as $fn$
begin
    if new.pub_date is not null and new.pub_date < now() - interval '30 days' then
        return null; -- silently skip the row
    end if;
    return new;
end;
$fn$;

drop trigger if exists rss_articles_skip_expired on public.rss_articles;
create trigger rss_articles_skip_expired
    before insert on public.rss_articles
    for each row execute function public.rss_articles_skip_expired();

-- ============================================
-- 3. Log tables retention
-- ============================================
-- These tables were created by hand (no CREATE in the repo), so the
-- function checks that the table and its created_at column exist.
create or replace function public.cleanup_logs(
    p_perf_log_days  integer default 7,
    p_activity_days  integer default 90
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
    v_perf      integer := 0;
    v_activity  integer := 0;
begin
    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'query_performance_log'
          and column_name = 'created_at'
    ) then
        execute 'delete from public.query_performance_log where created_at < $1'
            using now() - make_interval(days => p_perf_log_days);
        get diagnostics v_perf = row_count;
    end if;

    if exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'activity_feed'
          and column_name = 'created_at'
    ) then
        execute 'delete from public.activity_feed where created_at < $1'
            using now() - make_interval(days => p_activity_days);
        get diagnostics v_activity = row_count;
    end if;

    return jsonb_build_object(
        'query_performance_log', v_perf,
        'activity_feed',         v_activity
    );
end;
$fn$;

revoke all on function public.cleanup_logs(integer, integer)
    from public, anon, authenticated;
grant execute on function public.cleanup_logs(integer, integer)
    to service_role;

-- ============================================
-- 4. Unused index
-- ============================================
-- Web searches on search_vector, iOS uses ilike on title/excerpt:
-- nothing uses the trigram index on the full content (~20 MB).
drop index if exists public.idx_articles_content_trigram;

-- ============================================
-- 5. Superseded function
-- ============================================
drop function if exists public.cleanup_old_rss_articles(integer, integer);

-- ============================================
-- 6. Nightly schedule (pg_cron)
-- ============================================
-- pg_cron is not enabled by default on the project (it is also available
-- from Dashboard > Integrations > Cron).
create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;

do $do$
begin
    perform cron.unschedule(jobname)
    from cron.job
    where jobname in ('superreader-db-retention', 'rss-articles-cleanup-daily', 'cleanup-rss-articles');
end;
$do$;

select cron.schedule(
    'superreader-db-retention',
    '30 3 * * *',
    $cron$select public.cleanup_rss_articles(); select public.cleanup_logs();$cron$
);

-- ============================================
-- ONE-OFF: reclaim the space (run manually, one statement at a time)
-- ============================================
-- VACUUM FULL cannot run inside a transaction or a function: run each
-- line on its own in the SQL Editor. It locks the table for a few
-- seconds while it rewrites it.
--
--   select public.cleanup_rss_articles();
--   select public.cleanup_logs();
--   vacuum full analyze public.rss_articles;
--   vacuum full analyze public.query_performance_log;
--   vacuum full analyze public.activity_feed;
--
-- Then re-run supabase-db-size-diagnostics.sql to confirm the size.
