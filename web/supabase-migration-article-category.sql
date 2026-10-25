-- ============================================
-- MIGRATION: Article category (smart Library grouping)
-- ============================================
-- The iOS home groups the Library by topic (News, Science, Sports, …). The
-- category is computed on-device (Apple Foundation Models when available,
-- otherwise a keyword/domain/semantic heuristic) and stored here so every
-- device — and later the web app — sees the same grouping.
--
-- category_source records who picked it, so a better classifier never
-- overwrites a better answer:
--   'user'      → picked manually ("Move to…"), never overwritten
--   'model'     → on-device language model
--   'heuristic' → keyword/domain/semantic fallback, may be upgraded by 'model'
--
-- Idempotent. No new grants needed: `articles` is already granted to
-- authenticated + service_role (supabase-grants.sql) and its RLS policies
-- already restrict updates to the owner.

ALTER TABLE public.articles
ADD COLUMN IF NOT EXISTS category TEXT,
ADD COLUMN IF NOT EXISTS category_source TEXT;

ALTER TABLE public.articles DROP CONSTRAINT IF EXISTS articles_category_check;
ALTER TABLE public.articles
ADD CONSTRAINT articles_category_check CHECK (
  category IS NULL OR category IN (
    'news', 'politics', 'business', 'technology', 'science', 'health',
    'sports', 'culture', 'lifestyle', 'environment', 'other'
  )
);

ALTER TABLE public.articles DROP CONSTRAINT IF EXISTS articles_category_source_check;
ALTER TABLE public.articles
ADD CONSTRAINT articles_category_source_check CHECK (
  category_source IS NULL OR category_source IN ('user', 'model', 'heuristic')
);

CREATE INDEX IF NOT EXISTS idx_articles_user_category ON public.articles(user_id, category);

COMMENT ON COLUMN public.articles.category IS 'Topic used to group the Library (news, politics, business, technology, science, health, sports, culture, lifestyle, environment, other). NULL = not categorized yet.';
COMMENT ON COLUMN public.articles.category_source IS 'Who picked the category: user (manual, never overwritten), model (on-device LLM) or heuristic (fallback, upgradable).';
