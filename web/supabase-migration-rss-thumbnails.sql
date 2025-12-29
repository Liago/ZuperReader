-- Add image_url field to rss_articles table for thumbnail support
ALTER TABLE rss_articles ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Add index for better query performance when filtering by images
CREATE INDEX IF NOT EXISTS idx_rss_articles_image_url ON rss_articles(image_url) WHERE image_url IS NOT NULL;
