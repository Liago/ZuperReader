repo: Liago/ZuperReader
branch: main
path: web

## Last sync
date: 2026-08-27T19:07:00Z

### Updated in this project
- Recreated today's web UI from source: library (grid + list), reader, RSS, login, profile, shared, friends, modals
- Built a revamp direction on the Organic design system: left-sidebar shell, English copy, light + dark only
- Merged the header icon row and filter toolbar into one sidebar; reading status became quiet marks instead of badges
- Added a proposed "Up next" reading queue and a reader focus mode

## Screen map
| Project screen | Built from |
| --- | --- |
| Current UI · 01 Library grid | web/src/app/page.tsx, components/ArticleList.tsx, components/ArticleCard.tsx, components/ThemeSelector.tsx, components/AvatarMenu.tsx, components/TagBadge.tsx |
| Current UI · 02 Library list | web/src/components/ArticleRow.tsx, components/ArticleList.tsx, components/SearchAndFilters.tsx |
| Current UI · 03 Article reader | web/src/app/articles/[id]/page.tsx |
| Current UI · 04 RSS reader | web/src/app/rss/page.tsx, components/RSS/RSSLayout.tsx, RSSSidebar.tsx, FeedList.tsx |
| Current UI · 05 Login and modals | web/src/app/login/page.tsx, components/AddArticleModal.tsx, components/ReadingPreferencesModal.tsx |
| Current UI · 06 Profile / Shared / Friends | web/src/app/profile/page.tsx, app/shared/page.tsx, app/friends/page.tsx |
| Revamp · all screens | the files above, restyled on _ds/organic-5d845faa-eaf6-4be2-a3f5-9c40e2282f29 |
| Tokens reference | web/src/app/globals.css, web/src/app/layout.tsx |
