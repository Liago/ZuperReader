-- ============================================
-- MIGRATION: Add atomic counter functions for likes and comments
-- Date: 2025-12-07
-- Description: Adds RPC functions to atomically increment/decrement
--              like_count and comment_count to prevent race conditions
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
