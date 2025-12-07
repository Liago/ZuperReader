-- ============================================
-- MIGRATION: Article Full-Text Search Index
-- ============================================
-- Adds full-text search capabilities for articles
-- Includes: title, content, excerpt, author, domain

-- Create a generated tsvector column for full-text search
-- This combines title, content, excerpt, author into a searchable format
ALTER TABLE articles
ADD COLUMN IF NOT EXISTS search_vector tsvector
GENERATED ALWAYS AS (
    setweight(to_tsvector('english', COALESCE(title, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(content, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(excerpt, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(author, '')), 'C') ||
    setweight(to_tsvector('english', COALESCE(domain, '')), 'D')
) STORED;

-- Create GIN index on the tsvector column for fast full-text search
CREATE INDEX IF NOT EXISTS idx_articles_search_vector
ON articles USING GIN (search_vector);

-- Create additional indexes to optimize filtering and sorting
CREATE INDEX IF NOT EXISTS idx_articles_tags
ON articles USING GIN (tags);

CREATE INDEX IF NOT EXISTS idx_articles_is_favorite
ON articles(is_favorite) WHERE is_favorite = true;

CREATE INDEX IF NOT EXISTS idx_articles_published_date
ON articles(published_date DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS idx_articles_like_count
ON articles(like_count DESC);

-- Composite index for common filter combinations
CREATE INDEX IF NOT EXISTS idx_articles_user_status_created
ON articles(user_id, reading_status, created_at DESC);
