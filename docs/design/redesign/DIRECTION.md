# fusionha for iOS: redesign direction

Made with the `app-designer-pro` skill (`.claude/skills/app-designer-pro`).

## Brief (self-authored from the repos, the owner asked to see mock screens)

1. **App:** native iOS client for fusionha, a self-hosted Sonarr and Radarr replacement. For the person who runs the server and the people they share it with.
2. **Core action:** open it and see what changed. What landed, what's downloading, and which titles are missing a version (HD, 4K).
3. **Platform:** iPhone and iPad, iOS 26+, SwiftUI. iPhone only in these mocks.
4. **Feel:** *late, warm, sure.* References: a video rental shop after closing, the spine wall at Criterion, a cinema projection booth.
5. **Money:** free and self-hosted. No paywall, no onboarding carousel.
6. **Voice:** the person who runs the server, telling a housemate what's on.
7. **Already exists:** the gradient F logo (kept as-is), the web app's dark tokens, the status colours in `status.ts`, the tab glyphs in `App/Assets.xcassets/nav-*.svg`.
8. **Scope:** a few screens at the critic's bar. No store assets, no code.
9. **Image generation:** not used. The posters are drawn stand-ins for TMDB art (no text on art, same rule as the app).

## Current app

The iOS app mirrors fusionha's mobile web layout: cool near-black `#0C0D11` panels, a system UI face, the blue→violet→magenta→amber brand gradient on the ＋ orb and the login screen, status-tinted HD/4K chips, five tabs and a top bar with logo, search pill and avatar. It's competent, but it looks like a dark admin panel. The posters are the only richness, and they sit in small tiles under a lot of chrome.

**Slop faces it hits:** the gradient FAB orb (blue→violet→magenta), "everything is a panel", and a flat type scale (title 20, body 15, label 12).

### Keep list (a contract: every feature stays)

The owner's rule for this redesign: **no feature is lost.** This is a reskin and a re-weighting, not a rework of the information architecture. Every screen and control in `docs/ui-plan.md` §2 and §3 stays, including:

- [x] The five tabs in the web's order: Library · Discover · Calendar · Activity · Wanted. Requester role: Discover · My requests · You
- [x] The top bar: logo (tap = scroll to top), search pill scoped This library / Everything, avatar menu with the attention dot
- [x] The Activity queue badge, the Discover pending-requests badge, the attention bell and its sheet
- [x] Library: pulse chips (All · Downloading · Missing · Upcoming · Complete · Needs attention) with counts, the filter menu, Select mode and its bulk bar, the A–Z scrubber, grid and compact densities, the stats sheet
- [x] Long-press poster sheet: Automatic search, Interactive search, Monitor, Refresh metadata, Edit, Delete
- [x] Add (＋) on Library, Discover and Wanted. **Moved**, not removed: see decisions
- [x] Detail: hero, status chip, meta line, genres, action rail, Versions panel, tabs (Seasons · Files · History · Searches), episode rows with a per-episode monitor and one chip per version, the setup step strip
- [x] Activity: Queue · History · Blocklist · Tasks · Audit · Indexers, the bandwidth hero, section groups, progress with rate and ETA, held and stuck cards
- [x] Calendar: Month · Week · Forecast · Day · Agenda, kind filters, ‹ Today ›, iCal feed
- [x] Wanted, Discover, Settings, Interactive search, Add flow: unchanged structure, restyled by the tokens
- [x] Toasts, the setup progress pill, the downloads accessory, the Live Activity and widgets

The full web inventory (mobile and desktop) is in `before/FEATURES.md`, with screenshots in `before/` (stubbed data, placeholder posters).

### Fidelity to the web app (fusionha is the source of truth)

Checked against `before/web-mobile-*.png` and brought in line in rounds 3 and 4:

- [x] Library cell: one **rail per version** under the poster (tier chip · bar · have/total with ✓ / ↓ / ↑), plus year · kind glyph. Chips are coloured by **tier** (HD purple `#A78BFA`, 4K cyan `#22D3EE`); the rail carries the status colour.
- [x] Library header: "N titles · M versions", the stats button (beside the title), the All / HD / 4K segment, the kinds as an "All kinds ▾" menu with counts (the web's kinds bar lives in the stats sheet), Filters, grid / list, Select.
- [x] **Field-level audit (owner review):** every per-item field the web shows is on the iOS screen, or one tap away:
  - Activity download card: poster with progress ring, title, SxxEyy · episode, tier chip, big %, bar, transferred / total, speed, ETA, and, on tap (expanded in place), the release name, Size, Client, Indexer, Protocol, State, Queued, plus Interactive search, More (the web's ⋯ menu) and Remove. The web's poster-colour progress wash is kept.
  - Activity Pipeline card: "1 job queued · 3 downloading · speed", Step n/6, the six named stages, the ETA note. Up next card with the Downloading → Linking → Caching → Importing stepper and "Waiting to start…".
  - Library card: monitor bookmark (filled / outline, beside the year since iOS keeps art clean), year · kind glyph, Anime tag, the rails with ✓ ↓ ↑ or "Wanted"; "n need attention" in the header.
  - Detail: the monitor bookmark beside the title, Manual search / import and Refresh ▾ in the action rail, Versions footprint bar, "Tabs show all versions", Search all, Add version, per-version quality / media / CF chips and a per-version search, the Overview tab, Metadata via TMDB.
  - Calendar: the status legend and the Anime tag.
- [x] Activity: Manual import, the queue toolbar (refresh, Clear queue, Select) and the Pipeline job line (step n of 6) next to the bandwidth hero.
- [x] Monitor and in-flight state on the poster: the web shows small corner badges; iOS keeps posters clean (iOS rule), so monitor shows as the filled bookmark in the rail row and in-flight as the rail's ↓.
- [x] Detail: status chip, title + year, tagline, meta line ending "Metadata via TMDB", genres, overview, the item-action rail (Refresh ▾, Automatic search, Interactive search, Preview rename, Manage files, Report an issue, Edit, Delete) with "applies to all versions", then Versions with "Tabs show".

### Decisions for the owner (not made silently)

1. **The ＋ orb becomes a glass ＋ toolbar button** in the top bar on Library, Discover and Wanted. Same sheet, same three screens, no gradient. This is the one visible deviation from the web's mobile FAB.
2. **The brand gradient is kept inside the logo only.** It no longer paints buttons or the active tab.
3. **The kinds bar moves into a menu.** The web's Library shows a kinds bar and kind chips above the grid; iOS puts kinds in an "All kinds ▾" menu (with counts) so the posters start a third of the way down the screen. The bar stays in the stats sheet.
4. **Status is shown beside the chip, not inside it.** Chips are tier-coloured (HD violet, 4K cyan) as on the web; the status is the rail bar, the count and a coloured mark ("4K" + amber "wanted"). The in-flight chip fills with the episode's percentage (the signature).
5. **Display type changes** from the system face to a condensed grotesque (Bricolage Grotesque, OFL) on page titles and detail titles. UI text stays SF Pro.

## Exploration

Three concepts, three grounds, three faces, three accents (`explore.html`, `shots/explore/sheet.png`):

| | Concept | Family | Ground | Type | Accent | Richness |
|---|---|---|---|---|---|---|
| **A ✓** | fusionha is **a video rental shop after closing** | place | dark | condensed (Bricolage Grotesque) | neutral (warm house-light) | photo (poster art) |
| B | fusionha is **a light table of contact prints** | object | light | serif (Newsreader) | red | photo (framed prints) |
| C | fusionha is **a broadcast test card** | media | colour-field | expanded (Archivo) | yellow | shape (colour bars) |

**Why A won:** it is the most *this app*. Posters are the content and they glow on a warm dark ground. It keeps the web app's dark identity, so the "stay close to the web app" rule holds. And every hue on screen is left to the status palette, which is the app's real information.

- **B lost:** a light page fights the dark web app the owner wants iOS to match, and the white print frames make 347 posters into a stationery catalogue.
- **C lost:** the cobalt field fights both the poster art and the status colours (blue already means *upcoming*). It's memorable, but loud in the wrong place.
- **Taken from C:** the stacked status bar. It becomes the **coverage strip** under the Library title, a one-glance answer to "what state is the library in". It's built from the same counts as the pulse chips.

## The category default we refuse

Sonarr, Radarr, Overseerr and Plex-adjacent dashboards share a look: cool blue-grey panels, a sidebar of tables, a cyan or indigo accent, small posters inside bordered cards, and gradient buttons. The category's colour cliché is **cyan-on-slate tech blue** (and here, the indigo→magenta gradient). We refuse:

- cool slate panels → a **warm** black, like a shop with the lights down
- the gradient FAB and gradient active states → neutral warm-white chrome, colour only where it means state
- posters boxed in cards → posters as objects on the shelf, bigger, with nothing on the art

## Result

Four critique rounds by one fresh critic (`CRITIQUE.md`), done by the skill's stop rule in round 3 (12 of 14 lines at 4+, none below 3). Final renders: `shots/final/sheet.png` (iPhone 17 Pro), `shots/final-small/sheet.png` (375 x 667), and `before-after.png` (web today vs redesign).

## Tokens

**Colour (dark only, like the web app)**

| Role | Hex | Use |
|---|---|---|
| ground | `#0F0D0B` | screen |
| shelf | `#1A1714` | rows, panels that are objects (queue cards, version rows) |
| shelf-2 | `#24201C` | pressed and selected |
| ink | `#F4ECE1` | primary text, the selected chip, the primary button |
| ink-2 | `#B3A796` | secondary text (7.9:1 on ground) |
| ink-3 | `#857A6C` | tertiary text, captions (4.6:1) |
| hairline | `rgba(244,236,225,.08)` | dividers |

**Identity palette:** every saturated hue has one owner, the same on every screen, and these are the web's `status.ts` values unchanged:

| Hue | Owner |
|---|---|
| `#34D399` green | done (on disk) |
| `#22D3EE` cyan | grabbing (downloading) |
| `#F59E0B` amber | wanted (missing) |
| `#A78BFA` violet | upgrading |
| `#3B82F6` blue | upcoming (unaired) |
| `#F87171` red | danger, failures |

Kind accents (movie sky, series purple, anime pink) appear only as the 3pt kind tick on calendar rows, as on the web.

**Type**

- Display: **Bricolage Grotesque** 800, width 75, optical size 96. Page titles 56/0.95 at −1.2 tracking, detail titles 44/1.0 at −0.8.
- UI: SF Pro. 17 semibold (row titles), 15 regular (body), 13 medium (meta), 11 semibold mono (edition chips, SF Mono).
- Figures: SF Pro tabular for rates, sizes and ETAs.

**Layout:** 16pt side margin (as the web's page gutter at phone width). Spacing 4 · 8 · 12 · 16 · 24 · 32 · 48. Radii: chips are capsules, posters 8, shelf objects 20, sheets 34. Three depth levels: ground, shelf objects (a soft, warm two-layer shadow), Liquid Glass navigation.

## Richness

**The posters are the photography.** Grade: they sit on the warm black with a 1pt inner top highlight and a deep falloff shadow, like boxes on a lit shelf. Detail pages bleed the poster to the top edge and fade it into the ground. Nothing is printed on the art. Chips sit under it.

## Display face: options (`fonts.html`, `shots/fonts/sheet.png`)

All five are OFL, bundle in the app, and only set titles and the hero numbers; UI text stays SF Pro. Each is shown as a specimen and on the Library screen.

| Face | Character | Fit |
|---|---|---|
| **Bricolage Grotesque** Condensed 800 (current) | warm, slightly quirky, hand-cut | the shop's own lettering |
| **Big Shoulders Display** 800 | Chicago signage | the closest to a lit marquee; very tall, wraps sooner |
| **Archivo** ExtraCondensed 800 | neutral film-poster grotesque | the safest; reads well at 34pt too |
| **Anybody** Condensed 850 | VHS sleeve, squarer counters | the most retro |
| **Instrument Serif** | Criterion title cards | calmer and editorial; changes the mood the most |

A sixth option, **SF Pro Compressed** (native, no bundling), could not be rendered on this Linux machine.

## Liquid Glass (screen `liquid-glass`)

Glass stays on the navigation layer only (iOS 26 rule, CLAUDE.md), but the mock now shows what the app can use beyond the static tab bar:

- **Content under glass:** posters scroll beneath the top bar and its controls; a scroll-edge fade keeps the status bar legible. The large title collapses into a glass inline title.
- **Tab bar minimises on scroll** (`tabBarMinimizeBehavior(.onScrollDown)`, already in RootView) to the current tab, and the **downloads bottom accessory** (`tabViewBottomAccessory`) sits beside it: poster, "Andor · S2E10", tier, speed, ETA and a progress ring. Tapping it opens Activity.
- **Glass groups morph:** the All / HD / 4K segment, kind chips and toolbar groups live in a `GlassEffectContainer` with `glassEffectID`, so selection slides rather than swaps (Reduce Motion: instant).
- Posters, cards and rows stay solid.

## iPhone Duo (screens `duo-outer`, `duo-open`, `duo-portrait`, `duo-book`)

Follows Apple's HIG page *Designing for iPhone Duo* (2026-09-09, via the HIGAgentSkills reference the owner shared) and the existing `ShellSplitRule` / `DuoLayout.swift`. Sizes are the handoff's calculated ones (not Apple-published): outer ~466 x 678, inner ~890 x 626 landscape, ~626 x 890 portrait.

- **Closed (outer):** the phone layout, compact width. Bars go vertical on the trailing edge: status, then the toolbar (search, ＋, account), then the tab bar at the bottom. No custom top bar on this display.
- **Open, landscape:** Library leads; the open title is the trailing column at `clamp(56% of width, 360, 620)`. Only the title column (the container on the display edge) gets the vertical bar, with Close · Refresh · Manual import first (Close leads, per HIG).
- **Open, portrait:** the same split with horizontal bars: the tab bar along the bottom, the title's toolbar on top of its column.
- **Half open (book):** the fold is a reserved region; the two columns meet at it and nothing is drawn across it.
- Continuity: the open title and tab survive folding (sheet ↔ column), as built.

## fusionha 0.4.141 to 0.4.187 (handoff, 2026-10-13)

The handoff lists server and web changes the iOS app has not caught up with. The ones that change these screens are now in the mocks:

- **Activity** follows the queue contract: groups *Needs you* (held, first, with "Resolve all held"), Downloading, Up next, Just finished (20 s lane). Held rows say why in plain words ("Not really 2160p: the file is 1920x1080. Release says 2160p."), with a measured-vs-claimed grid, Manual import, Block release group and Remove; status as an ambient wash, never a border. The Pipeline card is phase mode: the stage count moves only when a stage completes, the current stage is indeterminate, no percent and no ETA.
- **Calendar** uses the new episode codes (`S05·E04`, anime `#30`).
- **Not designed yet:** the Requests revamp (Discover › Requests: Inbox swipe deck with 5-second Undo, Board, Me too, quota, threads, Report an issue), "Queue clear" (idle summary), Manual Import (phone 3-line rows, Duo list | file split), notification preferences. These are the next screens to design; the API catch-up in code is a separate task.

## Dense data: progressive disclosure

The web stacks every field of a download in a tall card. On iPhone the card is **compact by default** (what you check at a glance: progress, size, speed, ETA, and the source on one muted line) and **expands in place** on tap to show the release name, a labelled spec grid and labelled actions. Nothing is removed; the queue still fits on a screen. The same pattern applies to version rows on the detail page (tap to expand the spec grid: root, profile, cutoff, monitoring, files) and is the rule for any web card with more than two lines of metadata.

## Signature: the chip fills

An edition chip is also its own progress bar. While a version downloads, its cyan chip fills from left to right with the real percentage (`4K ▮▮▮▯ 62%`). When the import lands, the fill reaches the end, the chip turns green with a `symbolEffect(.bounce)` on a small checkmark, there's a `.success` haptic, and the toast says what landed: "Andor · 4K is on disk".

- Frames: `signature-1` (97%, filling) → `signature-2` (landed, toast)
- Timing: fill follows the queue poll; the colour swap is a 240ms crossfade, the bounce 400ms
- Reduce Motion: no fill animation and no bounce. The chip text changes and the colour swaps instantly.

## Voice

The person who runs the server, telling a housemate what's on.

1. **Says the thing and the number.** "4 downloading · 23 missing", never "Activity insights".
2. **Names the title and the version.** "Andor · 4K is on disk", never "Download complete!".
3. **The web's words win.** Labels match the web app exactly (Monitor, Automatic search, Interactive search, Versions). No new vocabulary on iOS.

## Content

- **Library:** 347 titles · 4 downloading · 23 missing. Chips All 347, Downloading 4, Missing 23, Upcoming 9, Complete 296, Needs attention 2. Grid: Andor (HD done, 4K 62%), Dune: Part Two (HD, 4K done), Frieren (HD), Shōgun (HD done, 4K wanted), Past Lives (HD), The Bear (HD upgrading), Severance (HD 18%, 4K wanted), Oppenheimer, Arcane, Slow Horses (HD wanted), Silo (4K upgrading), Perfect Days.
- **Detail (Andor):** Series · 2022 · 2 seasons · 24 episodes · TV-14 · TMDB 8.4. Genres: Sci-Fi, Drama, Thriller. Versions: HD·1080p, 24 of 24 on disk, 61.2 GB; UHD·4K, 21 of 24, grabbing S2E10 at 62%. Season 2: E8 "Who Are You?", E9 "Welcome to the Rebellion", E10 "Make It Stop".
- **Activity:** 41.6 MB/s · 4 in queue · 3.2 GB left. Andor S02E10 4K (62%, 28.4 MB/s, 3 min), Severance S02E01 HD (18%, 9.1 MB/s, 6 min), Dune: Part Two 4K remux (held: "Not enough free space on /media/4k"), Up next: Silo S02E04 4K.
- **Calendar:** week of 13 Oct. Today (Mon 13): Slow Horses S5E4 at 03:00 (on disk HD), Silo S2E9 at 08:00 (HD grabbing, 4K wanted). Wed 15: The Bear S4E2. Thu 16: Frieren S2E2 (simulcast). Fri 17: Severance S2E3.
- **Poster sheet (long-press Andor):** Automatic search, Interactive search, Monitor (on), Refresh metadata, Edit…, Delete….
