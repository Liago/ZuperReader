-- ============================================
-- MIGRATION: RSS Feed Reader
-- ============================================

-- 1. Create rss_folders table
CREATE TABLE IF NOT EXISTS rss_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_rss_folders_user_id ON rss_folders(user_id);

-- 2. Create rss_feeds table
CREATE TABLE IF NOT EXISTS rss_feeds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES rss_folders(id) ON DELETE SET NULL, 
    title TEXT,
    url TEXT NOT NULL,
    site_url TEXT,
    icon_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Prevent duplicate feeds for same user
    UNIQUE(user_id, url)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_rss_feeds_user_id ON rss_feeds(user_id);
CREATE INDEX IF NOT EXISTS idx_rss_feeds_folder_id ON rss_feeds(folder_id);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE rss_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE rss_feeds ENABLE ROW LEVEL SECURITY;

-- RSS Folders Policies
CREATE POLICY "rss_folders_select_own" ON rss_folders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "rss_folders_insert_own" ON rss_folders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "rss_folders_update_own" ON rss_folders
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "rss_folders_delete_own" ON rss_folders
    FOR DELETE USING (auth.uid() = user_id);

-- RSS Feeds Policies
CREATE POLICY "rss_feeds_select_own" ON rss_feeds
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "rss_feeds_insert_own" ON rss_feeds
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "rss_feeds_update_own" ON rss_feeds
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "rss_feeds_delete_own" ON rss_feeds
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger to update updated_at for rss_folders
DROP TRIGGER IF EXISTS update_rss_folders_updated_at ON rss_folders;
CREATE TRIGGER update_rss_folders_updated_at
    BEFORE UPDATE ON rss_folders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update updated_at for rss_feeds
DROP TRIGGER IF EXISTS update_rss_feeds_updated_at ON rss_feeds;
CREATE TRIGGER update_rss_feeds_updated_at
    BEFORE UPDATE ON rss_feeds
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
