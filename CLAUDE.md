# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SuperReader is a multi-platform article reader application that uses Postlight Parser to extract clean article content from web pages. The app supports saving articles, reading preferences, social features (friends, sharing, comments, likes), and tag management.

## Architecture

```
SuperReader/
├── web/          # Next.js 16 frontend (React 19, Tailwind v4) → Deploy on Vercel
├── parser-api/   # Netlify serverless function wrapping Postlight Parser
├── parser/       # Postlight Parser library (local dependency)
└── ios/          # iOS SwiftUI app (separate git submodule)
```

### Data Flow
1. User submits URL in web app
2. Web app calls parser-api Netlify function
3. Parser-api uses Postlight Parser to extract article content
4. Parsed content is saved to Supabase database via web app
5. iOS app shares the same Supabase backend

### Key Integration Points
- **Supabase**: Authentication (magic link), database for articles, user profiles, friendships, shares, comments, likes, and user preferences
- **Parser API**: `POST /.netlify/functions/parse` accepts `{ url }` and returns parsed article data
- **Environment Variables** (web):
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `NEXT_PUBLIC_PARSE_FUNCTION_URL`

## Development Commands

### Web Frontend
```bash
cd web
npm install
npm run dev      # Start dev server
npm run build    # Production build
npm run lint     # ESLint
```

### Parser API (requires netlify-cli)
```bash
cd parser-api
npm install
netlify dev      # Local function development
```

### Parser Library
```bash
cd parser
yarn install
yarn build       # Lint + Rollup + tests
yarn test        # Run node + web tests
yarn test:node   # Jest tests only
```

## Web App Structure

- `src/app/` - Next.js App Router pages (articles, auth, friends, login, profile, shared)
- `src/components/` - React components (ArticleList, CommentsSection, TagManagement, etc.)
- `src/contexts/` - React contexts (Auth, Articles, ArticleFilters, Friends, ReadingPreferences, Theme)
- `src/lib/api.ts` - All Supabase API functions for articles, comments, likes, friends, shares
- `src/lib/supabase.ts` - Supabase client and TypeScript types for all entities

## Database Types (Supabase)

Key entities defined in `web/src/lib/supabase.ts`:
- `Article` - articles with reading_status, reading_progress, tags, is_favorite, like_count, comment_count
- `Comment`, `Like`, `Share` - social engagement
- `UserProfile`, `Friendship`, `ArticleShare` - user and social features
- `UserPreferences` - font, theme, line_height, content_width, view_mode settings

## Adding new Supabase tables

Supabase stops auto-granting `public.*` to the Data API roles on 2026-10-30. The repo
runs two SQL scripts (idempotent) to standardize the project:

- `web/supabase-grants.sql` — grants for `authenticated` + `service_role` on all
  current and future objects in `public` (via `ALTER DEFAULT PRIVILEGES`).
- `web/supabase-anon-hardening.sql` — REVOKE ALL from `anon` on `public.*`. anon is
  granted by exception only. The one exception today is public article links
  (`web/supabase-migration-public-articles.sql`): anon may only `execute`
  `get_public_article(token)` (SECURITY DEFINER, safe column subset), never read tables.

Template for every new table migration:

```sql
create table public.your_table (...);

alter table public.your_table enable row level security;

create policy "..." on public.your_table for select to authenticated using (auth.uid() = user_id);
-- ... additional policies as needed

grant select, insert, update, delete on public.your_table to authenticated;
grant all on public.your_table to service_role;
-- DO NOT grant to anon unless the table is intentionally read without an
-- auth session (e.g. public share tokens). If you do, also remember that
-- supabase-anon-hardening.sql has stripped anon's default grants on public.

-- For RPC functions:
grant execute on function public.your_function(...) to authenticated, service_role;
```

## Public article links

The owner of an article can publish it via an unguessable link `/p/<token>` readable
without an account (web: `PublicLinkButton` in the reader top bar; iOS: "Public Link" in
the reader's More menu → `PublicLinkSheet`).

- DB: `articles.public_share_token` (NULL = private) + `public_link_expires_at`
  (NULL = never) + RPCs `enable_article_public_link(p_article_id, p_expires_in_days)`
  (owner only; validity 1, 7 or NULL days; keeps the token while the link is active and
  returns `{ token, expires_at }`), `disable_article_public_link` and
  `get_public_article` (anon; expired links return no rows).
  `public_link_validity_days` stores the validity picked (NULL = never, or legacy link).
  Migrations, in order: `web/supabase-migration-public-articles.sql`,
  `web/supabase-migration-public-articles-expiry.sql`,
  `web/supabase-migration-public-articles-validity.sql`.
- "Public links" view listing active/expired links: web `/public-links` (sidebar),
  iOS `PublicLinksView` (You tab → Public links).
- `articles.user_id` is TEXT in this project: compare with `auth.uid()::text`.
- Web page: `web/src/app/p/[token]/page.tsx`, server-rendered, `force-dynamic` so
  revocation is immediate, `noindex`. Content is always passed through
  `sanitizeArticleHtml` (sanitize-html) because it is shown on our origin to anonymous
  and logged-in visitors.
- iOS always builds public links on `SupabaseConfig.publicWebUrl` (production), never
  on the Debug LAN URL.

## iOS App

Located in `ios/SuperReader/SuperReader/` with MVVM architecture:
- `Views/` - SwiftUI views
- `Models/` - Data models
- `Services/` - API services (Supabase integration)
- `Components/` - Reusable UI components

The iOS app uses the `azreader://` URL scheme for magic link authentication deep links.
