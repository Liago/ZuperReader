# Handoff: ZuperReader iOS revamp (SwiftUI)

## Overview

A full visual and structural revamp of the ZuperReader iOS app (`ios/SuperReader/`, SwiftUI, iOS 16+, MVVM + Supabase). Ten screens are specified: Library (grid and list), Article reader, Focus mode, Reading preferences sheet, Feeds, People, You (profile), Save a link sheet, and Login.

The revamp does three things:

1. Replaces the purple/pink/blue `PremiumGradients` visual language with a single warm palette and one terracotta accent (the Organic design system, already used for the web revamp in this project).
2. Fixes the navigation: `MainTabView` currently gives both `SharedInboxView` and `FriendsView` `.tag(2)`, so one of the two is unreachable. Five tab items become four — Inbox and Friends merge into **People** with a segmented control.
3. Quiets reading state: the uppercase `StatusBadge` capsule on every card becomes a 7px dot plus a 2–3px progress bar, and reading preferences move from a full-screen `Form` to a half-height sheet applied live over the article.

## About the design files

The files in this bundle are **design references created in HTML** — a prototype board showing the intended look and behavior. They are not production code and nothing should be copied verbatim.

The task is to **recreate these designs natively in the existing SwiftUI codebase**, using its established structure (`Core/Theme/Theme.swift`, `Components/`, `Views/`, `ViewModels/`). Values in the HTML expressed in CSS px map 1:1 to SwiftUI points; radii, spacing and type sizes below are given in points, ready to drop into `Spacing` / `CornerRadius` / `Typography`.

## Fidelity

**High fidelity.** Colors, type sizes, spacing, radii and copy are final. Photography is represented by flat tinted blocks — real article thumbnails go in those slots, treated as described under Assets.

## Design tokens

Add these to `Core/Theme/Theme.swift`, replacing the existing `ColorTheme` cases and `PremiumGradients`.

### Palette — Cream (light)

| Role | Hex | Where |
| --- | --- | --- |
| `page` | `#F5EAD8` | screen background |
| `rail` | `#EFE2CA` | tab bar, grouped bars |
| `card` | `#FFFAF1` | cards, sheets |
| `text` | `#201E1D` | primary text |
| `muted` | `#201E1D` @ 58% | secondary text, meta |
| `line` | `#201E1D` @ 12% | hairlines, borders |
| `sink` | `#201E1D` @ 4.5% | search field, chip fills, icon buttons |
| `accent` | `#C67139` | selected state, primary action, "reading" |
| `accent-200` | `#F0CBA9` (accent ramp 200) | image placeholder tint |
| `accent-700/800` | `#8A4B22` / `#6B3A19` | accent-colored text on light fills |
| `accent-2` | `#7A8A5E` | second voice, "unread" dot |
| `accent-2-200` | `#D6DDC5` | alternate placeholder tint |

Ramp steps come from `styles.css` in `_ds/organic-…/` (`--color-accent-100…900`, `--color-accent-2-100…900`, `--color-neutral-*`). Use the ramp; do not mix ad-hoc tints.

### Palette — Dark

| Role | Hex |
| --- | --- |
| `page` | `#23201C` |
| `rail` | `#1C1A17` |
| `card` | `#2B2823` |
| `surface` | `#332F28` |
| `text` | `#F3EBDF` |
| `muted` | `#F3EBDF` @ 60% |
| `line` | `#F3EBDF` @ 14% |
| `sink` | `#F3EBDF` @ 5% |
| `accent` | `#E2975F` |
| `accent-2` | `#A9BD8C` |

### Palette — Sepia (reader only)

Page `#EFE0C4`, text `#3A2F1F`, accent as Cream.

`ColorTheme` becomes `.cream`, `.sepia`, `.dark`, `.system`. Ocean, Forest and Sunset are removed.

### Type

- Display / headings: **Caprasimo** (`--font-heading`) — screen titles, card titles in grid, sheet titles, stat numbers, primary button labels.
- UI and body: **Figtree** (`--font-body`) — everything else.
- Reader body: user-selectable — **Lora** (default), Figtree, system monospace.

| Use | Size / weight / line-height |
| --- | --- |
| Large screen title | Caprasimo 34pt, line-height 1.0 |
| Reader article title | Caprasimo 31pt, 1.14, tracking −0.01em |
| Grid card title | Caprasimo 20pt, 1.25 |
| Sheet title | Caprasimo 22pt |
| Stat number | Caprasimo 24pt |
| List row title | Figtree 15.5pt semibold, 1.35 |
| Body / excerpt | Figtree 14pt, 1.55, muted |
| Reader body | Lora 18.5pt, line-height 1.72 (Comfortable) |
| Focus body | Lora 19pt, 1.78 |
| Section label | Figtree 12pt, weight 800, tracking 0.10em, uppercase, muted |
| Field label | Figtree 11.5pt, weight 800, tracking 0.12em, uppercase, muted |
| Meta / caption | Figtree 12.5pt, muted |
| Tab label | Figtree 10.5pt, weight 700 (800 when selected) |
| Status bar | Figtree 14.5pt, weight 800 |

### Spacing, radii, elevation

- Screen horizontal padding: **20pt** (reader text column: **26pt**; Focus: **30pt**; login: **32pt**).
- Content top padding below the status bar: **26pt** (profile 30pt).
- Card radius **26**, sheet radius **32** (top corners only), list thumbnail **18**, small thumbnail **14**, segmented/pill/button **999**, icon button **999** at 38×38, tag pill **999**.
- Shadows: card `0 6 22 rgba(46,43,37,.08)`; floating reader bar `0 10 30 rgba(46,43,37,.16)`; sheet `0 −12 40 rgba(46,43,37,.22)`.
- Tab bar height **84** (10pt top padding, 1pt top hairline). Any scrolling content needs ≥100pt bottom inset.
- Minimum tap target 44×44 throughout; the reader action bar is 60pt tall with 44pt targets.

## Screens

### 01 · Library (grid)

Purpose: browse saved articles.

Layout, top to bottom: status bar → title row → search pill → filter chips → card stack, 16pt gaps, 100pt bottom inset above the tab bar.

- **Title row**: "Library" (Caprasimo 34) left; right two 38×38 circular buttons — view switch (`sink` fill, grid glyph) and add (`accent` fill, `page`-colored plus).
- **Search pill**: full width, `sink` fill, radius 999, padding 11×16, magnifier at 55% opacity, placeholder "Search 248 articles" in `muted`.
- **Filter chips** (7pt gaps, 13.5pt): "All" selected = `text` fill with `page` label; unselected = 1pt `line` border, transparent. "Unread" and "Reading" carry a 6pt leading dot (`accent-2` / `accent`); "Done" has none.
- **Card**: `card` fill, radius 26, clipped. Image area 150pt in `accent-200` with the source pill (`card` fill, 11pt weight 800, tracking 0.1em, uppercase, `accent-800`) at bottom-left. Directly under the image, a 3pt progress bar on a `line` track, filled `accent` to the read percentage. Content padding 16/18/18: state row (7pt dot + "Reading · 38%" in 12.5pt weight 700 muted, read time right-aligned) → title (Caprasimo 20) → excerpt (14pt muted, 2 lines) → footer with tag pills (`sink`, 12pt) and favorite/share icons at 55% opacity.
- **Compact card variant** (second item): 14pt padding, 66pt square thumbnail radius 18, meta row + title only. Use it for items with no hero image.

Copy in the prototype: "The quiet return of the personal website" / theverge.com / 7 min / tags web, culture; "What forests know about time" / nautil.us / 12 min.

### 02 · Library (list)

Same header; the view-switch button is filled (`text`) to show list mode is active. Rows are grouped under sticky-free section labels ("Today", "Earlier this week", 12.5pt weight 700 uppercase muted, 16pt above / 8pt below).

Row: 14pt vertical padding, 1pt `line` separator, 14pt gap. 66pt square thumbnail radius 18. Right column: meta row (state dot or a check glyph for completed, domain in 12pt weight 700 uppercase muted, read time right-aligned) → title (15.5pt semibold, 2 lines) → 2pt progress track, filled `accent` for in-progress, filled muted at 45% for completed. Completed rows also drop the title to `muted`.

Swipe actions: leading — toggle favorite; trailing — delete (destructive), matching the current `ArticleListView` behavior.

### 03 · Reader

Top bar (16pt padding, 12pt gaps): back circle (38×38 `sink`), source + read time (13pt weight 700 muted, truncating), typography button (`sink`), Focus toggle (filled `text`). Under it a 2pt progress hairline inset 18pt, filled `accent`.

Body column padding 26pt: title (Caprasimo 31) → byline row (30pt avatar circle + "Nilay Patel · 14 Aug", author in weight 700) → hero 158pt radius 22 → paragraphs at Lora 18.5/1.72, 18pt apart.

Floating action bar: pinned 22pt from the bottom, inset 18pt, 60pt tall, radius 999, `card` fill, 1pt `line` border. Five targets: favorite (filled `accent` when on), comments, share, AI summary, then a pill "Focus" (Caprasimo 13.5, `accent` fill, `page` label). This replaces the toolbar currently spread across `ArticleReaderView`.

Reading progress must persist: debounce scroll position (~500ms), write via `updateReadingProgress`, auto-complete at 85% — the gap flagged in `docs/ANALISI_IOS.md`.

### 04 · Focus

All chrome hidden; a 2pt progress line at the very top edge. Text at Lora 19/1.78, 30pt side padding, 78pt top padding, 22pt paragraph gaps, an optional 1pt `line` divider between sections. A "4 min left" pill (`sink`, 12.5pt weight 700 muted) floats 34pt from the bottom. Tapping anywhere restores the chrome; the transition is a 0.25s ease fade plus a 6pt slide on the bars.

### 05 · Reading preferences sheet

Half-height sheet (`.presentationDetents([.medium])`) over the dimmed article (`rgba(20,18,16,.28)`), radius 32 top, 22pt side padding, 30pt bottom, 42×5 grabber.

Controls: "Size" label with live value ("18.5 pt", 13pt weight 700 `accent-700`) over a 6pt track with a 24pt `accent` knob (4pt `card` border) → "Typeface" as three cards (Lora / Figtree / Mono, each an "Aa" specimen 19pt over an 11.5pt label; selected = `text` fill, `page` text; unselected = 1pt `line` border) → "Spacing" segmented pill (Tight / Comfortable / Loose) → "Theme" three swatches (Cream, Sepia, Dark; selected carries a 2pt inset `accent` ring).

Every change applies immediately to the article behind the sheet — no Done-to-commit. Persist through `ReadingPreferencesManager` (`@AppStorage` + Supabase upsert), unchanged.

### 06 · Feeds

Header: "Feeds" (Caprasimo 34) with a 13.5pt muted subtitle carrying the counts — "12 channels · 52 unread · synced 4 min ago" — which replaces the two `RSSStatCard`s. Add button (38×38 `accent`) on the right.

"All feeds" row: full-width `accent` fill, radius 22, 14/16 padding, RSS glyph, title (Caprasimo 16) + "Everything, newest first", unread count right (14pt weight 800).

Feeds group under folder labels ("Design", "Long reads"). Row: 36pt circular monogram (accent or accent-2 ramp 200 fill, 800-weight letter in the matching 800 step), title 15pt weight 700, domain 12.5pt muted, unread count in `accent` weight 800; fully-read feeds drop to 62% opacity and show a check glyph instead of a number.

Refresh is pull-to-refresh only — the orange and grey toolbar circles go away. Keep `RSSRefreshLoaderView` for the in-progress state, restyled on the tokens.

### 07 · People

Merged Inbox + Friends. Title "People", then a segmented pill (`sink` track, selected segment = `card` fill with `0 2 8 rgba(46,43,37,.1)`): "Shared with me" / "Friends".

Pending requests sit above the list as a bordered row (1pt `accent` border, radius 20): avatar, "**Marta** wants to connect", Accept pill (`accent`). This replaces the tab badge as the primary signal; the tab badge stays only as a count.

Share card: `card` fill, radius 24, 16pt padding. Header row = 32pt avatar, "**Luca** shared this", unread dot (8pt `accent`) right. Optional message in a `sink` bubble, radius 16, 14.5/1.55. Article strip = 56pt thumbnail radius 14 + title (14.5pt weight 700, 2 lines) + "longreads.com · 16 min". Read items drop to 75% opacity and lose the dot.

### 08 · You

Header row: 72pt `accent` avatar circle with Caprasimo 26 initials, name (Caprasimo 24), email (13.5pt muted), "Edit profile" pill (1pt `line` border).

Stats: one row bounded by 1pt `line` rules top and bottom, 18pt vertical padding, four equal columns split by 1pt dividers — Saved 248, Read 163, Shared 41, Friends 12 (Caprasimo 24 over an 11.5pt uppercase label). This replaces the eight colored `StatCard`s; the four dropped metrics move into their own screens.

Appearance: three 76pt tall swatches (Cream / Dark / System, radius 20, label bottom-left, selected = 2pt inset `accent` ring).

Settings list: full-width rows, 15pt vertical padding, 1pt `line` separators, 19pt leading glyph at 65% opacity — "Reading defaults" (chevron), "Feed sync" (value "Every hour"), "Sign out" in `accent-800`.

### 09 · Save a link

Sheet over the dimmed library. Title "Save a link" + close circle. URL field: 1.5pt `accent` border, radius 20, link glyph, with "Pasted from clipboard" as 12.5pt muted helper — the sheet reads the pasteboard on appear.

Preview card (`sink`, radius 20): 56pt thumbnail + title + "The Verge · 7 min read", shown as soon as parsing returns. Tags: accepted tags are `accent`-filled pills with an × ; suggestions are dashed-border muted pills prefixed "+" (this is the tag-suggestion service ported from web). Then an "Add to Up next" row with a 50×30 switch, and a full-width "Save article" button (Caprasimo 16, `accent`, radius 999).

Failure state: the border turns to the error treatment and the helper line explains the failure inline — no alert.

### 10 · Login

No gradient. `page` background with two soft circles bleeding off-screen: 280pt `accent-200` top-right (offset −90 / −70), 220pt `accent-2-200` bottom-left. Content padding 32pt, 150pt from the top: 64pt rounded-square logo (radius 22, `accent`, Caprasimo 30 "Z") → "Everything you meant to read." (Caprasimo 40, 1.06, three lines) → subtitle 16pt/1.6 muted, max 280pt wide → "Email" field label → pill field (`card` fill, 1pt `line`) → "Send magic link" (Caprasimo 16.5, `accent`, radius 999) → 12.5pt centered legal line.

`MagicLinkSentView` follows the same shell: same circles, same type, a confirmation line and a resend text button.

## Interactions and behavior

- **Tabs**: Library, Feeds, People, You. Fix the duplicate `.tag(2)`; tags become 0–3. Selected tab = `accent` icon and label at weight 800.
- **Card / row tap** → reader push. **Long press** → context menu (favorite, share, add to Up next, delete).
- **Press feedback**: 0.98 scale, spring response 0.3 (keep `ScaleButtonStyle`).
- **Focus toggle**: 0.25s ease fade of all chrome; status bar hidden in Focus.
- **Preferences**: live application, no commit step.
- **Pull-to-refresh** on Library, Feeds and People.
- **Haptics**: light impact on favorite, tag accept and Focus toggle.
- **Loading**: keep `SkeletonView` but restyle — skeleton blocks are `sink` fill at the real component's radius, with a 1.2s shimmer at 6% white; never a bare `ProgressView` on a full screen.
- **Empty states**: one 96pt circle in `sink` with a 40pt glyph at 35% opacity, a Caprasimo 22 line, a 15pt muted line, and one `accent` pill action. Applies to Library, Feeds, People.
- **Errors**: non-blocking toast above the tab bar (`card` fill, radius 999, 1pt `line`, 8pt shadow, auto-dismiss 4s) instead of console prints. Destructive confirmations stay as alerts.
- **Dark mode**: every screen ships in both palettes; the theme prop on the prototype toggles them.
- **Dynamic Type**: sizes above are the `.large` baseline; allow scaling up to `.accessibility1` on body and title text — card titles clamp to 3 lines.

## State

No new state layers. Per screen: `ArticleListViewModel` (filters, search, view mode, pagination) unchanged; `RSSViewModel` unchanged; `PeopleViewModel` is new and simply wraps the existing `getSharedWithMe`, `getPendingFriendRequests`, `getFriends` calls behind one `segment: .shared | .friends` enum. `ThemeManager` loses three cases and gains `.sepia`. `ReadingPreferencesManager` gains a `fontFamily` set reduced to three values (migrate stored legacy values: any serif → `.lora`, any sans → `.figtree`, mono → `.mono`).

## Assets

- **Fonts**: Caprasimo (display) and Figtree (UI) must be added to `Resources/Fonts/` and registered in Info.plist. Lora is already bundled. Crimson Text, Inter, Montserrat, Poppins, Roboto, Lato, Open Sans and Ubuntu can be removed with the reduced font set.
- **Images**: no imagery is supplied. Flat tinted blocks in the prototype are placeholders for article thumbnails — render real images filling the slot, corner radius per component, and keep the existing app-icon fallback for articles with no image.
- **Icons**: Lucide at stroke width 2.75 (the prototype draws them inline). Either bundle Lucide as SVG assets or match SF Symbols at `.semibold` weight — pick one and be consistent; the rounded Lucide set is closer to the intent.

## Files

- `Zuper Reader iOS - Revamp.dc.html` — the ten-screen design board (open in a browser). A `theme` control switches light/dark.
- `_ds/organic-…/styles.css` — the Organic token sheet: every color ramp, font, spacing and radius variable referenced above.
- `_ds/organic-…/_ds_bundle.js` — component bundle used by the prototype (not needed for the iOS build).
- `screenshots/` — one 2× PNG per screen (`01-library-grid` … `10-login`), matching the numbered sections above.
- `support.js` — prototype runtime only.
- `github.md` — repo association and the screen-to-source map (which Swift file each screen was derived from).

Source files this revamp replaces: `Core/Theme/Theme.swift`, `Views/Main/MainTabView.swift`, `Views/Main/HomeView.swift`, `Views/Articles/ArticleListView.swift`, `ArticleCardView.swift`, `ArticleRowView.swift`, `ArticleReaderView.swift`, `ArticlePreferencesView.swift`, `AddArticleSheet.swift`, `Views/RSS/RSSListView.swift`, `Views/Social/SharedInboxView.swift`, `FriendsView.swift`, `Views/Profile/ProfileView.swift`, `Views/Auth/LoginView.swift`.
