# Handoff: Zuper Reader web UI revamp

## Overview

A structural and visual revamp of the **Zuper Reader web app** (`Liago/ZuperReader`, `web/` — Next.js App Router + Tailwind). iOS is out of scope.

The revamp does three things:

1. **Collapses the app chrome into one left sidebar.** Today the header carries a gradient wordmark, a theme dropdown, a "Riassunto" button, an "Add Article" button and four icon buttons; below it a floating toolbar carries the title, search, view toggle, a status segmented control, a favourites pill, a sort control, a "More" pill and an expandable tag/domain panel. All of that becomes one 264px rail: destinations at the top, reading state and tags below, account at the bottom.
2. **Quiets reading status.** Uppercase gradient badges over cover images become a 7px dot next to the domain plus a 4px progress bar on in-progress covers.
3. **Adds two things that were missing.** An ordered **Up next** queue (an alternative to a 248-item wall), and a reader **Focus** mode that removes all chrome.

Also decided in this pass, and worth a product confirmation before you build: **Shared with me** and **Friends** merge into one page, and **Reading Preferences** moves from a full-screen modal to a side sheet inside the reader so the text reflows live.

## About the design files

The files in this bundle are **design references written in HTML** — prototypes of intended look and behaviour, not production code to copy. The task is to **recreate them inside `web/`'s existing environment**: Next.js App Router, React client components, Tailwind, `lucide-react`, and the existing Supabase data layer. Do not port the prototype's markup, its inline styles, or its `support.js` runtime.

Two files:

- `Zuper Reader - Revamp.dc.html` — the target design. Open in a browser; it is interactive.
- `Zuper Reader - Current UI.dc.html` — today's UI rebuilt from the repo source, for side-by-side comparison. Read-only reference; nothing to build from it.

Both files need `support.js` and `_ds/organic-…/` (both included) as siblings to render.

## Fidelity

**High fidelity.** Colours, type sizes, radii, spacing and hover states are final and specified below. Recreate them exactly, expressed as Tailwind theme values / CSS variables rather than inline styles. Photographs are grey placeholder blocks — the real covers come from the existing `article.image_url` pipeline.

Two things are deliberately *not* final: the empty and loading states (none are drawn), and mobile/tablet breakpoints (the prototype is a fixed 1440×920 desktop frame). Both are noted under **Gaps** at the end.

---

## Design tokens

The revamp replaces the current violet/pink/blue gradient palette with the **Organic** design system: a warm cream ground, terracotta accent, sage second accent. Full token sheet is in `_ds/organic-5d845faa-eaf6-4be2-a3f5-9c40e2282f29/styles.css` — take values from there, not from this table alone.

### Colour — light theme

| Token | Value | Used for |
| --- | --- | --- |
| `--app-page` | `#f5ead8` | Page ground |
| `--app-rail` | `#efe2ca` | Sidebar ground |
| `--app-card` | `#fffaf1` | Cards, list containers, modals |
| `--app-line` | `rgba(32,30,29,.12)` | All 1px borders and dividers |
| `--app-muted` | `rgba(32,30,29,.58)` | Secondary text, meta rows |
| `--app-hover` | `rgba(32,30,29,.05)` | Row and nav hover |
| `--color-text` | `#201e1d` | Primary text |
| `--color-surface` | Organic surface | Inputs, inline placeholder blocks |
| `--color-accent` | `#c67139` | Primary actions, unread dot, progress |
| `--color-accent-2` | `#7a8a5e` | Finished state, second voice |

### Colour — dark theme

Same variable names, rebound:

| Token | Value |
| --- | --- |
| `--app-page`, `--color-bg` | `#23201c` |
| `--app-rail` | `#1c1a17` |
| `--app-card` | `#2b2823` |
| `--color-surface` | `#332f28` |
| `--color-text` | `#f3ebdf` |
| `--app-line` | `rgba(243,235,223,.14)` |
| `--app-muted` | `rgba(243,235,223,.6)` |
| `--app-hover` | `rgba(243,235,223,.06)` |
| `--color-accent` | `#e2975f` |
| `--color-accent-2` | `#a9bd8c` |

**Only these two themes ship.** Ocean, Forest and Sunset are removed; `ThemeSelector` becomes a single moon toggle at the bottom of the rail, and the reader's five-theme grid becomes a Cream/Dark pair. Migration: map Ocean/Forest/Sunset → Light, keep Dark, keep Auto behaviour as "follows system".

Ramp steps used for tinted fills: `--color-accent-100/200/300/700/800`, `--color-accent-2-200/700/800`, `--color-neutral-400`.

### Type

Organic's pairing: **Caprasimo** (`--font-heading`) for display, **Figtree** (`--font-body`) for everything else. Replaces Geist.

| Role | Size / line-height / weight |
| --- | --- |
| Page title (`h1`) | 34px / 1 / heading font |
| Reader article title | 44px / 1.06 / heading font / `-0.02em` |
| Login headline | 38px / 1.05 / heading font |
| Reader `h2` | 27px / 1.15 / heading font |
| Modal title | 24px / 1.1 (Save a link), 21px / 1.1 (Reading sheet) |
| Card title | 19px / 1.3 / 700 |
| List row title | 18px / 1.3 / 700 |
| Queue / feed row title | 16.5–17px / 1.3 / 700 |
| Body — reader prose | 18.5px / 1.75 |
| Body — card excerpt | 13.5px / 1.6 / `--app-muted` |
| Nav item | 14.5px / 600 (primary), 14px / 400 (sub) |
| Meta row | 12–12.5px / `--app-muted` |
| Section label | 11px / 700 / `0.12em` / uppercase / `--app-muted` |
| Stat figure | 34px / 1 / heading font |
| Blockquote | 21px / 1.5 / italic |

Body base is 15px. `text-wrap: pretty` on card titles and the reader headline.

### Radius

Pills `999px` (buttons, inputs, nav pills, tags, avatars, icon buttons). Cards and modals `28px`. Inner panels and side sheet sections `18–24px`. Cover thumbnails `14–16px`. Nav rows `12px`. Nothing sharp; no hairline-only geometry.

### Spacing

Rail `20px 14px 14px`, rail items `9px 12px`. Content areas `24–32px` vertical, `36px` horizontal. Card padding `18px 20px 16px`. List row padding `18px 22px`. Grid gap `22px`. Icons are Lucide at **stroke-width 2.75**.

### Elevation

Only three shadows appear: the shell frame, card hover `0 12px 32px rgba(46,43,37,.16)`, modal `0 24px 60px rgba(32,30,29,.28)`. Otherwise borders do the work. The current UI's `shadow-lg` gradient cards and glowing buttons are gone.

---

## Screens

The prototype frame is **1440×920**. Sidebar 264px fixed; content fills the rest and scrolls independently (`overflow-y: auto` per screen, not on the shell).

### 1. Sidebar (persistent)

**Purpose:** the single navigation surface. Present on every screen except when reader Focus is on.

**Layout:** 264px, `--app-rail`, 1px right border, flex column.

Top to bottom:

1. **Brand** — 34px terracotta circle with "Z" in the heading font, then "Zuper" at 21px heading font. 18px bottom padding.
2. **Save a link** — full-width terracotta pill, `11px 14px`, plus icon + label, heading font 14px. Opens the Save a link modal.
3. **Destinations** — Library (count 248), Up next (5), Feeds (badge 52 in sage), Shared with me (badge 2 in terracotta). Each: 18px Lucide icon, label, trailing count. `9px 12px`, radius 12px, 14.5px/600.
4. **Reading** section label, then five sub-items: Everything (248), Unread (64), In progress (11), Finished (173), Favourites (31). Each has a leading state mark — see **State marks** below.
5. **Tags** section label, then a wrapping row of outlined pills: archivi, culture (selected), design, web, ai.
6. **Account** — pushed to the bottom above a 1px divider: 30px sage avatar, name 13.5px/600, email 11.5px muted; then a 32px outlined circular moon button that toggles light/dark.

**Two distinct active treatments — this matters.** Destination items when active take a solid terracotta fill with `--color-bg` text (hover `--color-accent-600`). Reading sub-items when active take only `--app-hover` background, `--color-accent-800` text and `inset 2px 0 0 var(--color-accent)` — a left marker, not a fill. Filling both would put two solid terracotta blocks in the rail at once and destroy the sense of "where am I". In dark mode the sub-item active text is `--color-accent`.

All nav rows hover to `--app-hover`.

### 2. Library

**Purpose:** browse and scan everything saved.

**Header** — `26px 36px 18px`, 1px bottom border, flex row with baseline-aligned items:
- Left: "SAVED BY YOU" section label, then `h1` "Library".
- Right: a 264px search pill (`--app-card`, 1px border, search icon + "Search titles, tags, notes" at 13.5px muted); a "Newest ▾" sort pill (outlined, 13.5px/600); a view toggle — two 30px circular buttons inside a 4px-padded outlined pill container, grid and list icons, active button filled `--color-text` with `--app-page` icon.

Everything the current toolbar carried beyond these three controls now lives in the sidebar. There is no second filter row and no expandable panel.

**Grid view** — 3 columns, 22px gap, six cards. Each card: `--app-card`, 1px border, radius 28px, flex column.
- **Cover**: `aspect-ratio: 16/10`. With an image, the photo (Organic's `.washed` treatment). Without one, `--color-surface` with a 42px book icon at 0.5 opacity in the accent or sage. In progress adds a 4px bar pinned to the cover's bottom edge: `--app-line` track, terracotta fill at the read percentage.
- **Body** (`18px 20px 16px`): meta row — state dot, domain at 600, `·`, then reading time / `38% read` / `finished`; title 19px/700/1.3; excerpt 13.5px/1.6 muted; then a bottom row pushed down with `margin-top:auto` holding tag pills (3px 10px, accent-200/accent-2-200 fills with 800-step text) and a bookmark icon (filled terracotta when favourited, else 0.45 opacity outline).
- **Hover**: `translateY(-2px)` + `0 12px 32px rgba(46,43,37,.16)`, 180ms ease.

**List view** — one `--app-card` container, radius 28px, rows divided by 1px lines. Each row: 112×76 cover thumb (radius 16px), then a column with the meta row (state dot, domain, date, duration), 18px/700 title, 13.5px muted excerpt; trailing icon column (bookmark, plus-to-queue) at `--app-muted`. Finished rows drop the title to `--app-muted`. Row hover `--app-hover`.

### 3. Reader

**Purpose:** read one article.

**Progress** — a 3px bar across the very top of the content area: `--app-line` track, terracotta fill at scroll percentage.

**Top bar** — `14px 28px`, 1px bottom border: 34px outlined circular back button → Library; domain at 12.5px/700 terracotta; truncated title at 13.5px muted; then, right-aligned: a "42% · 7 min left" pill (`--color-accent-200` fill, `--color-accent-800` text, 12.5px/700); four 34px outlined circular buttons — **Aa** (opens the Reading sheet), Summarise (sparkle), Save (bookmark), Share; and a **Focus** pill with an eye icon, 12.5px/700, which fills `--color-text` when on.

**Body** — centred, 664px column, `44px 40px 60px`:
- Kicker: "Il Post · 14 August 2026 · 12 min read" as a section label.
- `h1` 44px/1.06.
- Byline: 34px sage avatar, name 14px/600; tag pills right-aligned; 26px bottom padding and a 1px divider.
- Prose at 18.5px/1.75. `h2` 27px/1.15 with `34px 0 14px`. Blockquote: 21px italic, `4px 0 4px 22px`, 3px sage left border — no tinted background box, unlike today.

**Right rail** — 236px, 26px gaps, three blocks:
1. **In this article** — outline entries, 6px 12px, 2px left border (terracotta on the current section, `--app-line` otherwise), 13.5px.
2. **Summary** — an `--app-card` panel, radius 22px: section label, one line of muted 13px explaining it is generated once and kept, then a full-width terracotta pill "Summarise" with a sparkle icon. This replaces the header's "Riassunto" button.
3. **Up next** — two rows, radius 16px, title 13.5px/600 + source line 11.5px muted.

**Focus mode** — hides the sidebar and the right rail; the 664px column and the top bar remain. Toggled by the Focus pill; also exits via the back button.

### 4. Up next (new)

**Purpose:** a short ordered queue, so the daily entry point isn't a 248-item grid.

Max 760px column. Section label "Five articles · 48 minutes", `h1` "Up next", then one muted paragraph explaining the model (drag to reorder; finishing one advances). Then an `--app-card` container, radius 28px, five rows divided by 1px lines. Each row: a 26px position circle — filled terracotta with `--color-bg` numeral for position 1, outlined with muted numeral otherwise — then title 16.5px/700 and a 12.5px muted source line. Position 1 gets a "Continue" pill (`--color-accent-200`); the rest get a drag handle at 0.4 opacity.

### 5. Feeds (RSS)

**Purpose:** read subscribed feeds. Replaces `/rss` and its own separate layout, header and 4-button grid.

**Two panes.** Left 250px pane, 1px right border, `26px 16px`, scrolls: "FOLDERS" label, then feed rows — 16px rounded colour swatch, name, unread count; active row filled terracotta. A second labelled group ("Italiano") shows folder grouping. Below, two outlined half-width pills: "Add feed", "Discover". Import/export moves to Profile settings.

**Right pane**, `26px 34px`, scrolls: section label "18 unread · refreshed 2 min ago", `h1` feed name, and an outlined "Mark all read" pill. Then rows divided by 1px lines: an 8px terracotta unread dot (muted at 0.35 when read), title 17px/700, meta 12.5px muted, and an optional 104×68 thumb (radius 14px) on the right. Read rows drop to 0.55 opacity. Footer: a centred outlined pill "Show 12 read articles".

The gradient wordmark, the second header and the "Manage your feeds" block are all gone — the app rail is the navigation.

### 6. Shared with me (merges today's `/shared` and `/friends`)

**Purpose:** see what friends sent, and manage friends.

Max 780px. Section label "2 new · 6 friends", `h1` "Shared with me". Then cards, 14px gap, `--app-card`, radius 24px, 20px padding:
- Unread cards take a 1px **terracotta** border instead of a "Nuovo" badge.
- Each: optional 120×88 cover (radius 16px); a sharer line — 24px avatar, "**Marco** shared this · 2 hours ago" at 13px; title 17px/700; and, if there's a note, a quote block with a 3px sage left border, italic 13.5px muted. Right column: a terracotta "Read" pill and an outlined "Queue" pill.

Below a 1px divider, a **Friends** section: avatar+name pills (`8px 14px 8px 8px`, outlined), then a "Find friends" pill on `--color-surface` carrying a terracotta count badge for pending requests. Search-users and requests are reached from here rather than from tabs.

### 7. Profile

Max 840px. Header row: 76px terracotta avatar with initial (heading font 32px), `h1` name, a muted line "email · member since March 2024", then outlined "Edit profile" and "Sign out" pills. The current banner + overlapping avatar treatment is dropped.

**Stats** — 4 equal `--app-card` cards, radius 22px, 20px padding, 14px gap: figure at 34px heading font, label 12.5px muted. Saved 248, Finished 173 (sage-700), Favourites 31 (accent-700), Shared out 18. No icon tiles.

**This month** — an `--app-card` panel, radius 24px: section label, a 96px bar chart of 12 bars with 7px gaps, radius `8px 8px 0 0`, `--color-accent-300` with one terracotta and one sage bar for emphasis, then a 12.5px muted summary line.

**Settings** — an `--app-card` container, radius 24px, three rows divided by 1px lines: label 14.5px/600 left, current value 13px muted right — Reading defaults, Appearance, Feed refresh. Replaces the three-tab layout.

### 8. Login

Centred 420px column, no card, no gradient background — the page ground is enough.

44px terracotta "Z" circle + "Zuper Reader" at 28px heading font; `h1` "Read what you saved." at 38px/1.05; one muted paragraph; a 12px "Email" label; a `--color-surface` input pill (`13px 18px`, 1px border); a full-width terracotta "Send magic link" pill (14px padding, heading font 15px); then a centred 12.5px muted line with a "Paste it here" link.

Copy is English throughout the app — the current mix of English and Italian UI strings is resolved to English. Article content stays in its own language.

### 9. Modal — Save a link

Backdrop `rgba(32,30,29,.42)`, centred; 520px panel, `--app-card`, radius 28px, modal shadow. Click backdrop or the 32px circular close button to dismiss; clicks inside must not bubble.

Header: `h2` "Save a link" 24px, sub-line "We'll fetch the title, cover and reading time." at 13px muted.

Body: a `--color-surface` input pill with a link icon and "https://" placeholder. Below it, when the clipboard holds a URL, a **clipboard suggestion** — `--color-accent-100` fill, 1px `--color-accent-300` border, radius 20px: clipboard-check icon, a 12px/700 "In your clipboard" label, the truncated URL at 12.5px, and a terracotta "Use" pill. Then a "TAGS" label and a wrapping row of outlined tag pills plus a dashed "+ New tag" pill.

Footer, above a 1px divider: a 34×20 terracotta toggle with "Add to Up next" at 13px muted, then outlined "Cancel" and terracotta "Save".

### 10. Side sheet — Reading

Replaces the full-screen Reading Preferences modal. Same backdrop, but the panel is top-right (`70px 40px`), 360px, radius 28px, 22px 24px padding — so the article stays visible and reflows as values change.

`h2` "Reading" 21px + close button. Then, each under a section label:
- **Typeface** — 2-up grid: Figtree (selected), Serif. Radius 18px, 12px padding.
- **Size** — a label row with the live value at 12.5px/700 accent-700, then a 6px track with terracotta fill and an 18px terracotta knob ringed 3px in `--app-card`. Range 12–50px as today; default 18.5px.
- **Line height** — a 3-option segmented pill: Tight / Comfortable (selected) / Loose. New; today only size and family are adjustable.
- **Surface** — Cream / Dark, 2-up.
- **Preview** — a `--color-surface` block, radius 20px, one sentence at the chosen size and line height.

### State marks (used everywhere)

| State | Mark |
| --- | --- |
| Unread | 7–8px solid `--color-accent` dot |
| In progress | 7px circle, 2px `--color-accent` ring, hollow centre; plus a 4px progress bar on the cover |
| Finished | 7px solid `--color-accent-2` dot; title drops to `--app-muted`, row to 0.55 opacity in feeds |
| Everything | 8px `currentColor` dot at 0.3 opacity |
| Favourite | Filled terracotta bookmark (Lucide `bookmark`), else 0.45-opacity outline |

No uppercase badges, no gradient chips, no coloured overlay on cover images.

---

## Interactions

| Trigger | Result |
| --- | --- |
| Sidebar destination | Switches screen; clears Focus when leaving the reader |
| Reading sub-item | Sets the status filter; does not change screen |
| Tag pill | Toggles a tag filter (multi-select) |
| Card / list row / queue row / feed row | Opens the reader |
| View toggle | Grid ↔ list; persist per user |
| Moon button | Toggles light/dark; persist |
| Save a link | Opens the modal; read the clipboard and offer it if it parses as a URL |
| Reader **Aa** | Opens the Reading side sheet; button shows an active fill while open |
| Reader **Focus** | Hides sidebar and right rail |
| Backdrop click / close button / `Esc` | Closes any overlay |
| Outline entry | Scrolls to that heading; the entry's left border becomes terracotta as it enters view |
| Queue drag handle | Reorders the queue |
| Finishing an article | Advances to the next queue item |

**Transitions.** Card hover is the only animation specified: `transform`/`box-shadow` at 180ms ease. Nav, pill and row hovers are instant colour changes. Screen changes are instant. Scroll progress and the reader's percentage pill update on scroll. Keep the prototype's restraint — no page transitions, no gradient sweeps.

**Focus states.** Organic mandates `:focus-visible { outline: 2px solid var(--color-accent); outline-offset: 2px; }` on every interactive element. The prototype does not draw them; you must add them. Never leave the browser default.

**Keyboard.** Not in the prototype; worth adding while you're here — `j`/`k` through the current list, `Enter` to open, `Esc` to close overlays, `f` for Focus.

---

## State

Prototype state, and where each belongs in the real app:

| State | Values | Where it should live |
| --- | --- | --- |
| `screen` | library, reader, queue, feeds, shared, profile, login | App Router route, not component state |
| `view` | grid \| list | User preference, persisted |
| `status` | all, unread, reading, done, fav | URL query param, so filters are shareable |
| `tags` | selected tag set | URL query param |
| `theme` | light \| dark (+ system) | Existing theme context, ramps reduced to two |
| `focus` | boolean | Reader-local |
| `modal` | null \| add \| type | Reader/shell-local |
| Reading prefs | family, size, lineHeight, surface | Persisted per user; `lineHeight` is new |
| Queue | ordered article ids | **New persistence — see below** |

**New data work.** Up next needs an ordered per-user queue: a position column or a join table, plus reorder and "advance on finish" mutations. Reading progress percentage and time-left are shown in three places (card bar, list, reader pill, queue) — if the current schema only stores a status enum, it needs a scroll-position or percentage field. The generated summary should be stored with the article, not regenerated per view, since the reader panel presents it as kept.

---

## Assets

- **Icons**: Lucide at stroke-width 2.75. `lucide-react` is already a dependency; the prototype hand-inlines equivalents. Icons used: book-open, list, rss, share-2, bookmark, heart, search, chevron-down, grid, arrow-left, sparkles, eye, moon, x, link, clipboard-check, plus, grip-lines, calendar, user.
- **Fonts**: Caprasimo + Figtree, loaded by the Organic stylesheet. Geist is dropped.
- **Photographs**: none included. Every cover in the prototype is a flat placeholder; real covers come from existing article metadata. Run them through Organic's `.washed` treatment.
- **Design system**: `_ds/organic-5d845faa-eaf6-4be2-a3f5-9c40e2282f29/styles.css` is the token source. Port its `:root` variables into the Tailwind theme rather than importing the stylesheet wholesale.

## Files in this bundle

| File | What it is |
| --- | --- |
| `Zuper Reader - Revamp.dc.html` | The target design, interactive |
| `Zuper Reader - Current UI.dc.html` | Today's UI rebuilt from repo source, for comparison |
| `support.js` | Runtime the two HTML files need to render. Not for production |
| `_ds/organic-…/styles.css` | Design tokens — the authoritative colour/type/spacing source |
| `_ds/organic-…/_ds_bundle.js` | Design-system component bundle used by the prototypes |
| `github.md` | Repo/branch record and a screen → source-file map |

## Source files this replaces

From `github.md`'s screen map, in `web/src/`:

- `app/page.tsx`, `components/ArticleList.tsx`, `ArticleCard.tsx`, `ArticleRow.tsx`, `SearchAndFilters.tsx`, `TagBadge.tsx`, `AvatarMenu.tsx`, `ThemeSelector.tsx` → Library + sidebar
- `app/articles/[id]/page.tsx`, `components/ReadingPreferencesModal.tsx` → Reader + Reading side sheet
- `app/rss/page.tsx`, `components/RSS/RSSLayout.tsx`, `RSSSidebar.tsx`, `FeedList.tsx` → Feeds
- `app/shared/page.tsx`, `app/friends/page.tsx` → Shared with me (merged)
- `app/profile/page.tsx` → Profile
- `app/login/page.tsx` → Login
- `components/AddArticleModal.tsx` → Save a link
- `app/globals.css`, `app/layout.tsx` → token layer

## Gaps to resolve before shipping

Not drawn in the prototype; decide these with the designer rather than inventing them:

1. **Empty states** — empty library, empty queue, no feeds, no shared articles, no friends.
2. **Loading and error states** — article fetch failure, unparseable URL on save, feed refresh failure, skeletons for the grid.
3. **Responsive behaviour** — the prototype is a fixed 1440×920 desktop frame. The sidebar needs a collapse or drawer below roughly 1100px; the 3-column grid needs 2- and 1-column steps; the reader's right rail needs somewhere to go on narrow screens.
4. **Two product decisions** noted in the overview: merging Friends into Shared with me, and moving Reading Preferences into a side sheet.
