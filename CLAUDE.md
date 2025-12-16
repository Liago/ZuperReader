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

## iOS App

Located in `ios/SuperReader/SuperReader/` with MVVM architecture:
- `Views/` - SwiftUI views
- `Models/` - Data models
- `Services/` - API services (Supabase integration)
- `Components/` - Reusable UI components

The iOS app uses the `azreader://` URL scheme for magic link authentication deep links.
