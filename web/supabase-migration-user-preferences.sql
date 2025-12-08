-- ============================================
-- MIGRATION: User Reading Preferences
-- ============================================
-- This migration adds a table to store user reading preferences
-- for cross-device synchronization

-- 1. Create user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    -- Reading preferences
    font_family TEXT NOT NULL DEFAULT 'serif' CHECK (font_family IN ('sans', 'serif', 'mono', 'roboto', 'lato', 'openSans', 'ubuntu')),
    font_size INTEGER NOT NULL DEFAULT 16 CHECK (font_size >= 12 AND font_size <= 50),
    color_theme TEXT NOT NULL DEFAULT 'light' CHECK (color_theme IN ('light', 'dark', 'ocean', 'forest', 'sunset')),
    line_height TEXT NOT NULL DEFAULT 'relaxed' CHECK (line_height IN ('compact', 'normal', 'relaxed', 'loose')),
    content_width TEXT NOT NULL DEFAULT 'normal' CHECK (content_width IN ('narrow', 'normal', 'wide')),
    view_mode TEXT NOT NULL DEFAULT 'grid' CHECK (view_mode IN ('grid', 'list')),
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster user lookups
CREATE INDEX IF NOT EXISTS idx_user_preferences_id ON user_preferences(id);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Users can read their own preferences
CREATE POLICY "user_preferences_select_own" ON user_preferences
    FOR SELECT USING (auth.uid() = id);

-- Users can insert their own preferences
CREATE POLICY "user_preferences_insert_own" ON user_preferences
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own preferences
CREATE POLICY "user_preferences_update_own" ON user_preferences
    FOR UPDATE USING (auth.uid() = id);

-- Users can delete their own preferences
CREATE POLICY "user_preferences_delete_own" ON user_preferences
    FOR DELETE USING (auth.uid() = id);

-- ============================================
-- TRIGGERS
-- ============================================

-- Update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_user_preferences_updated_at();

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE user_preferences IS 'Stores user reading preferences for cross-device synchronization';
COMMENT ON COLUMN user_preferences.font_family IS 'Font family for reading: sans, serif, mono, roboto, lato, openSans, ubuntu';
COMMENT ON COLUMN user_preferences.font_size IS 'Font size in pixels (12-50)';
COMMENT ON COLUMN user_preferences.color_theme IS 'Color theme: light, dark, ocean, forest, sunset';
COMMENT ON COLUMN user_preferences.line_height IS 'Line height: compact, normal, relaxed, loose';
COMMENT ON COLUMN user_preferences.content_width IS 'Content width: narrow, normal, wide';
COMMENT ON COLUMN user_preferences.view_mode IS 'Article list view mode: grid or list';
