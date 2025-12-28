-- Migration: Add ai_summary field to articles table
-- Run this SQL in your Supabase SQL Editor

-- Add ai_summary column to articles table
ALTER TABLE articles
ADD COLUMN IF NOT EXISTS ai_summary TEXT;

-- Add ai_summary_generated_at timestamp to track when summary was created
ALTER TABLE articles
ADD COLUMN IF NOT EXISTS ai_summary_generated_at TIMESTAMP WITH TIME ZONE;

-- Add comment for documentation
COMMENT ON COLUMN articles.ai_summary IS 'AI-generated summary of the article content using Cohere API';
COMMENT ON COLUMN articles.ai_summary_generated_at IS 'Timestamp when the AI summary was generated';
