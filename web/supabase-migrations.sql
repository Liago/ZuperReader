-- ============================================
-- MIGRATION: User Sharing & Friendship System
-- ============================================

-- 1. Create user_profiles table
-- This table stores additional user information beyond auth.users
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for searching users
CREATE INDEX IF NOT EXISTS idx_user_profiles_display_name ON user_profiles(display_name);

-- 2. Create friendships table
-- Status: 'pending', 'accepted', 'rejected', 'blocked'
CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Ensure no duplicate friendships
    UNIQUE(requester_id, addressee_id)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_friendships_requester ON friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON friendships(status);

-- 3. Create article_shares table
-- This tracks when users share articles with their friends
CREATE TABLE IF NOT EXISTS article_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    shared_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    shared_with UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    -- Prevent duplicate shares
    UNIQUE(article_id, shared_by, shared_with)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_article_shares_shared_by ON article_shares(shared_by);
CREATE INDEX IF NOT EXISTS idx_article_shares_shared_with ON article_shares(shared_with);
CREATE INDEX IF NOT EXISTS idx_article_shares_article ON article_shares(article_id);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS on all new tables
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_shares ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
-- Users can read all profiles (for search functionality)
CREATE POLICY "user_profiles_select_all" ON user_profiles
    FOR SELECT USING (true);

-- Users can insert their own profile
CREATE POLICY "user_profiles_insert_own" ON user_profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "user_profiles_update_own" ON user_profiles
    FOR UPDATE USING (auth.uid() = id);

-- Users can delete their own profile
CREATE POLICY "user_profiles_delete_own" ON user_profiles
    FOR DELETE USING (auth.uid() = id);

-- Friendships Policies
-- Users can see friendships where they are involved
CREATE POLICY "friendships_select_own" ON friendships
    FOR SELECT USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- Users can create friendship requests
CREATE POLICY "friendships_insert" ON friendships
    FOR INSERT WITH CHECK (auth.uid() = requester_id);

-- Users can update friendships they are involved in
CREATE POLICY "friendships_update" ON friendships
    FOR UPDATE USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- Users can delete friendships they initiated or received
CREATE POLICY "friendships_delete" ON friendships
    FOR DELETE USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- Article Shares Policies
-- Users can see shares they sent or received
CREATE POLICY "article_shares_select_own" ON article_shares
    FOR SELECT USING (auth.uid() = shared_by OR auth.uid() = shared_with);

-- Users can share articles
CREATE POLICY "article_shares_insert" ON article_shares
    FOR INSERT WITH CHECK (auth.uid() = shared_by);

-- Users can update shares (e.g., mark as read)
CREATE POLICY "article_shares_update" ON article_shares
    FOR UPDATE USING (auth.uid() = shared_by OR auth.uid() = shared_with);

-- Users can delete their own shares
CREATE POLICY "article_shares_delete" ON article_shares
    FOR DELETE USING (auth.uid() = shared_by);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to automatically create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, display_name)
    VALUES (NEW.id, SPLIT_PART(NEW.email, '@', 1))
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_friendships_updated_at ON friendships;
CREATE TRIGGER update_friendships_updated_at
    BEFORE UPDATE ON friendships
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- Create profiles for existing users
-- ============================================
INSERT INTO user_profiles (id, display_name)
SELECT id, SPLIT_PART(email, '@', 1)
FROM auth.users
WHERE id NOT IN (SELECT id FROM user_profiles)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- VIEW: Get user info with email from auth.users
-- ============================================
CREATE OR REPLACE VIEW user_profiles_with_email AS
SELECT
    up.id,
    up.display_name,
    up.avatar_url,
    up.bio,
    u.email,
    up.created_at,
    up.updated_at
FROM user_profiles up
JOIN auth.users u ON u.id = up.id;

-- ============================================
-- ATOMIC COUNTER FUNCTIONS
-- ============================================

-- Function to atomically increment like_count
CREATE OR REPLACE FUNCTION increment_like_count(article_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE articles
    SET like_count = like_count + 1
    WHERE id = article_id;
END;
$$ LANGUAGE plpgsql;

-- Function to atomically decrement like_count
CREATE OR REPLACE FUNCTION decrement_like_count(article_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE articles
    SET like_count = GREATEST(0, like_count - 1)
    WHERE id = article_id;
END;
$$ LANGUAGE plpgsql;

-- Function to atomically increment comment_count
CREATE OR REPLACE FUNCTION increment_comment_count(article_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE articles
    SET comment_count = comment_count + 1
    WHERE id = article_id;
END;
$$ LANGUAGE plpgsql;

-- Function to atomically decrement comment_count
CREATE OR REPLACE FUNCTION decrement_comment_count(article_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE articles
    SET comment_count = GREATEST(0, comment_count - 1)
    WHERE id = article_id;
END;
$$ LANGUAGE plpgsql;
