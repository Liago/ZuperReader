-- ============================================
-- MIGRATION: Partial index on unread RSS articles
-- ============================================
-- Most hot-path queries (unread counts, mark-as-read updates,
-- "unread articles by feed" listings) filter by `is_read = FALSE`.
-- A partial index indexes only those rows, so it stays small even
-- as rss_articles grows, and Postgres can use it efficiently for
-- both SELECT and UPDATE plans.

CREATE INDEX IF NOT EXISTS idx_rss_articles_user_unread
    ON rss_articles (user_id, feed_id)
    WHERE is_read = FALSE;

-- Run ANALYZE so the planner picks up the new index without
-- waiting for autovacuum.
ANALYZE rss_articles;
