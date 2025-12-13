-- ============================================
-- MIGRATION: Add Reading Progress Tracking
-- ============================================
-- This migration adds a field to track the exact reading position (scroll percentage)
-- for each article, allowing users to resume reading from where they left off.

-- Add reading_progress column to articles table
-- Stores the reading progress as a percentage (0-100)
ALTER TABLE articles
ADD COLUMN IF NOT EXISTS reading_progress INTEGER DEFAULT 0
CHECK (reading_progress >= 0 AND reading_progress <= 100);

-- Add an index for potentially filtering by reading progress
CREATE INDEX IF NOT EXISTS idx_articles_reading_progress ON articles(reading_progress);

-- Add comment to document the column
COMMENT ON COLUMN articles.reading_progress IS 'Stores the reading progress as a percentage (0-100) representing scroll position in the article';
