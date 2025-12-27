-- ============================================
-- MIGRATION: RSS Articles Read Tracking
-- ============================================

-- Create rss_articles table to track individual feed items and their read status
CREATE TABLE IF NOT EXISTS rss_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_id UUID NOT NULL REFERENCES rss_feeds(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Article identification (guid from RSS feed is the unique identifier)
    guid TEXT NOT NULL,

    -- Article metadata
    title TEXT NOT NULL,
    link TEXT NOT NULL,
    pub_date TIMESTAMPTZ,
    author TEXT,
    content TEXT,
    content_snippet TEXT,

    -- Read tracking
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Prevent duplicate articles for same user/feed
    UNIQUE(user_id, feed_id, guid)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_rss_articles_user_id ON rss_articles(user_id);
CREATE INDEX IF NOT EXISTS idx_rss_articles_feed_id ON rss_articles(feed_id);
CREATE INDEX IF NOT EXISTS idx_rss_articles_is_read ON rss_articles(is_read);
CREATE INDEX IF NOT EXISTS idx_rss_articles_pub_date ON rss_articles(pub_date DESC);

-- Composite index for efficient unread count queries
CREATE INDEX IF NOT EXISTS idx_rss_articles_user_feed_read
    ON rss_articles(user_id, feed_id, is_read);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE rss_articles ENABLE ROW LEVEL SECURITY;

-- Users can only see their own RSS articles
CREATE POLICY "rss_articles_select_own" ON rss_articles
    FOR SELECT USING (auth.uid() = user_id);

-- Users can only insert their own RSS articles
CREATE POLICY "rss_articles_insert_own" ON rss_articles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only update their own RSS articles
CREATE POLICY "rss_articles_update_own" ON rss_articles
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can only delete their own RSS articles
CREATE POLICY "rss_articles_delete_own" ON rss_articles
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger to update updated_at timestamp
DROP TRIGGER IF EXISTS update_rss_articles_updated_at ON rss_articles;
CREATE TRIGGER update_rss_articles_updated_at
    BEFORE UPDATE ON rss_articles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to get unread count for a specific feed
CREATE OR REPLACE FUNCTION get_feed_unread_count(p_user_id UUID, p_feed_id UUID)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM rss_articles
        WHERE user_id = p_user_id
        AND feed_id = p_feed_id
        AND is_read = FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread counts for all feeds of a user
CREATE OR REPLACE FUNCTION get_all_feeds_unread_counts(p_user_id UUID)
RETURNS TABLE(feed_id UUID, unread_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT
        rss_articles.feed_id,
        COUNT(*) as unread_count
    FROM rss_articles
    WHERE rss_articles.user_id = p_user_id
    AND rss_articles.is_read = FALSE
    GROUP BY rss_articles.feed_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
