-- ============================================
-- MIGRATION: Cleanup function for old RSS articles
-- ============================================
-- rss_articles grows unbounded as feeds are refreshed. Once an article
-- has been read and is older than `retention_days`, there is no
-- reason to keep it: re-fetching the feed will skip it (composite
-- key user_id+feed_id+guid is the dedup) and the user has already
-- consumed it.
--
-- This function deletes read articles older than the threshold,
-- in batches to avoid long-running transactions and lock contention.

CREATE OR REPLACE FUNCTION public.cleanup_old_rss_articles(
    retention_days INTEGER DEFAULT 60,
    batch_size INTEGER DEFAULT 1000
)
RETURNS INTEGER AS $$
DECLARE
    deleted_total INTEGER := 0;
    deleted_in_batch INTEGER;
    cutoff TIMESTAMPTZ := NOW() - (retention_days || ' days')::INTERVAL;
BEGIN
    LOOP
        WITH victims AS (
            SELECT id
            FROM public.rss_articles
            WHERE is_read = TRUE
              AND read_at IS NOT NULL
              AND read_at < cutoff
            LIMIT batch_size
        )
        DELETE FROM public.rss_articles
        WHERE id IN (SELECT id FROM victims);

        GET DIAGNOSTICS deleted_in_batch = ROW_COUNT;
        deleted_total := deleted_total + deleted_in_batch;

        EXIT WHEN deleted_in_batch = 0;
    END LOOP;

    RETURN deleted_total;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.cleanup_old_rss_articles(INTEGER, INTEGER)
    TO service_role;

-- ============================================
-- Optional: schedule via pg_cron (run from SQL Editor as superuser)
-- ============================================
-- pg_cron is already enabled on this project. To run the cleanup
-- daily at 03:00 UTC, uncomment and run the following from the
-- Supabase SQL Editor:
--
-- SELECT cron.schedule(
--     'rss-articles-cleanup-daily',
--     '0 3 * * *',
--     $$SELECT public.cleanup_old_rss_articles(60, 1000);$$
-- );
--
-- To unschedule:
-- SELECT cron.unschedule('rss-articles-cleanup-daily');
