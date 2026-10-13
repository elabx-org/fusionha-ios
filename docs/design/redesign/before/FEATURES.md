# fusionha web: "before" feature inventory

Captured 2026-10-13 from `fusionha/frontend` (React + Vite SPA) with a stubbed backend
(12 titles, 4 downloads, 9 calendar entries, 5 wanted). Screenshots in this folder:
`web-{mobile,desktop}-{library,detail,activity,calendar,wanted,discover}.png` plus
`web-mobile-library-full.png`. Mobile = 390×844 @2x touch; desktop = 1440×900. Posters are
generated gradient placeholders (TMDB art is not reachable offline), so art reads as flat colour.
In the full-page shot the fixed bottom nav and FAB sit mid-page; that's an artifact of how the
screenshot was captured, not a layout bug.

The layout switches at a single breakpoint, `@media (max-width: 720px)` / `useIsMobile()`.

## Visual tokens (`src/styles/tokens.css`, `src/lib/status.ts`)

- **Grounds (dark):** `--bg #0c0d11` page · `--panel #14161d` · `--panel2 #181b23` · `--card #151821`
  · hairline `--line rgba(255,255,255,.08)`. Light theme exists (`--bg #f5f6f8`, white panels).
- **Text:** `--txt #e9eaf0` · `--mut #9aa0ad` · `--dim #6b7280`.
- **Brand gradient:** `--grad linear-gradient(135deg, #6366f1 indigo → #22d3ee cyan)`. It's used on
  the logo mark, the active capsule nav pill, the FAB, the avatar, and the Pipeline step bar.
- **Status vocabulary (status.ts → tokens):** Downloaded `--done #34d399` green · Downloading /
  Available `--grab #22d3ee` cyan · Upgrading `--edition #a78bfa` violet · Missing / Dead link
  `--miss #f59e0b` amber · Unaired / Upcoming `--unaired #3b82f6` blue · Unmonitored `#6b7280`
  grey · On Air `#fbbf24` · Premiere `#818cf8` · Stuck `#fb923c`.
- **Tier chips:** HD = `--tier-hd #a78bfa` (purple outline + text), 4K/UHD = `--tier-uhd #22d3ee`
  (cyan). Small rounded-rect outline chips in mono type ("HD", "4K", "HD·1080p", "UHD·4K").
- **Kind colours** (library kind bar, stat chips): Movies cyan-blue, Series purple, Anime pink,
  Animation pink-magenta.
- **Type:** `--font-sans` = system UI stack (SF on Apple, Inter fallback); `--font-mono` =
  ui-monospace/Menlo. Mono is used for counts, chip text, release names, section eyebrows
  ("ITEM ACTIONS", "VERSIONS") and sizes. Titles are heavy sans (detail title about 34pt bold, with the year
  in `--mut`).
- **Radii:** `--radius-sm 9` · `--radius 11` · `--radius-lg 14`. Panels are about 14–20px rounded cards on `--panel`
  with a 1px `--line` border. Segmented controls are pill tracks with an indigo-tinted selected pill.
- **Washes:** Activity, Wanted and Calendar "today" cards carry a tinted wash from the poster
  colour or status; the detail hero blurs the backdrop into the ground.

## Shell / navigation

- **Mobile:**
  - Top bar: logo mark, a full-width **Search** pill (scope "This library" on Library, otherwise
    "Everything" omni), and a gradient avatar (UserMenu with Settings, Docs and Log out; amber
    attention dot). It hides on scroll down.
  - Floating **bottom capsule nav** (glassy, rounded): Library · Discover · Calendar · Activity · Wanted,
    with a web SVG icon and label for each. The active tab gets a tinted pill. Activity has a gradient count
    badge and a pulsing ring.
  - **FAB** "+": a 56px gradient orb, bottom right, on Library, Discover and Wanted. It opens the Add modal.
  - The setup-progress pill appears under the top bar, and a toast stack sits above the nav.
  - Select mode hides the nav and the FAB.
- **Desktop:**
  - Top bar: logo plus the **"fusionha"** wordmark ("ha" in cyan), and a centred **CapsuleNav** where the active
    destination expands to icon + label on the gradient and the others are icon-only.
  - Right cluster: a **Search** field, the **status cluster** HUD tray (OperationsPanel live-activity dot +
    count, AttentionControl, HealthBadge green dot), an outline **+ Add** button and the avatar. The tray drops
    below 900px.
  - **Desktop-only:** CapsuleNav, the wordmark, the status HUD (operations popover with running
    commands, downloads and runs), the inline Add button, the Park & Resume **Dock** (parked
    pages and interactive searches), ⌘K omni overlay and keyboard hints.
- Requester role swaps destinations to Discover · My requests · You.
- Routes: `/` · `/library/:id` (aliases `/movies/:id`, `/series/:id`) · `/discover` · `/calendar`
  · `/activity` · `/wanted` · `/settings/:panel` · `/account` · `/preview/:kind/:tmdbId` · `/docs/*`
  · `/login` · `/setup`.

## Library (`/`)

- **Header:** "Library" + "12 titles · 19 versions".
- **Mobile LibraryPulse card:**
  - Kind summary ("All kinds · 3 kinds") with an icon tile.
  - A stacked kind bar (movies/series/anime).
  - A horizontally scrolling kind chip row: All · n Movies · n Series · n Anime · n Animation.
  - A **chart button** (amber dot) opens the **Library stats sheet**: stat chips, health / 4K coverage /
    on-disk meters, In progress, and Needs attention.
- **Desktop LibraryPulse panel (inline, no sheet):**
  - Status stat chips: n titles · complete · downloading · missing · upcoming. Each has a coloured dot
    and is clickable as a filter.
  - Meters on the right: Library health (multi-colour bar + %), 4K coverage (purple→cyan bar, "7 / 12 titles")
    and On disk ("1.4 TB").
  - The kind bar and chips row sits below.
- **Toolbar, mobile:**
  - Select toggle (dotted-square glyph).
  - Tier segmented control **All · HD · 4K**.
  - "Needs attention · n" chip (only when n > 0).
  - **Filters** chip, which opens a dialog for recency, group and sort, with an active-count badge.
  - A second row with the **grid / list** density toggle.
- **Toolbar, desktop:**
  - Select, tier segment, recency segment **Any · Added · Released**, inline search, a **Group: Status**
    button, a sort select (Title A–Z · Year Newest/Oldest · Recently added · Recently released),
    grid/list toggle, and a display (rail style) popover.
- **Poster card:**
  - 2:3 art with clean art plus small corner badges: a **bookmark** monitor toggle (top-left), a **"4K"** badge
    (top-right, when the title has a UHD version), and a state glyph bottom-left (spinner while grabbing, ↑ while upgrading).
  - Below the art: title, year · kind glyph (tv / film / torii for anime), an "Anime" pink pill.
  - Then **one rail per version**: tier chip, a coloured progress bar, have/total + ✓ / ↓ / ↑, or the word "Wanted".
- **Grid:** 3 columns on phone; about 7 columns at 1440 desktop.
- **Desktop-only:** letter **section headers** (A, D, …) and a permanent **AlphabetRail** at the right
  edge. Mobile has no headers; a ScrollScrubber thumb appears only while scrolling.
- **List density:** LibraryCompactTable rows.
- **Hover (desktop):** poster hover icons. **Mobile:** long-press opens LibraryPosterSheet (Automatic
  search, Interactive search → season/episode → which version, Monitor, Refresh metadata, Edit…,
  Delete…).
- **Select mode:** BulkActionBar with count, Select all / Clear, Monitor, Unmonitor, Refresh & Scan, Quality
  Profile, Minimum availability, Change root folder, and Delete.
- **States:** skeleton grid, empty library, collection nudge, and the setting-up shimmer rail + ring on a
  new poster.

## Item detail (`/library/:id`)

- **Mobile:** opens as a **bottom-sheet flyout** (MobileDetailFlyout) over the Library. It has a grabber, a ✕ at the
  top-left, and a full-bleed backdrop hero. Below the hero, the content is stacked:
  - The status pill "RELEASED" (green outline, mono).
  - Huge title + muted year, then the tagline in italics.
  - The meta line: Movie · 2 versions · 167 min · ★ 8.2 · PG-13 · Metadata via TMDB.
  - Genre pills and the overview.
- **Desktop:** a full page (top bar stays) with a wide backdrop band, a ✕ at the top-right, and a **poster at the left**
  overlapping the band.
  - The title cluster has a **monitor bookmark button** beside the title.
  - The meta line with the TMDB logo, then genre pills and the overview.
  - A **Release timeline** strip (Cinema / Digital / Physical dates with ✓). On mobile this sits further down.
- **Item actions rail** (both layouts; icon-only, "applies to all versions"): Refresh metadata ▾ (refresh
  options), Manual search/import (download), Preview rename (T), Manage files (folder), Report an issue
  (flag), Edit & monitoring (pencil), Delete (trash). Overflow holds Edition aliases, Manage episodes, Park page.
- **Versions panel:**
  - Header: "2 versions · 2 on disk · 80.1 GB", a footprint bar, the "Tabs show **all versions**"
    scope chip, **Search all** and **+ Add version**.
  - One row per version: tier chip, status, size, quality / media / CF chips, and per-version search.
    Clicking a row focuses the page scope on that version.
  - Expanded row: Search ▾ (SearchModeMenu) · Choose (interactive) · Edit, plus a spec grid (root, profile,
    cutoff, monitoring, files) and the attention banner.
- **Tabs:** Overview · Seasons (series) · Files · History · Searches · Collection (movie in a collection).
- **Series:** SeasonsAccordion with a coverage bar per season and episode rows with a monitor toggle, status,
  and air time. Mobile uses MobileEpisodeList. There's also gradual season search progress.
- **Rails:** Cast, Similar, Collection completion, and Trailer.
- **Modals:** InteractiveSearchModal (desktop: can dock / PiP to the Dock), EditItem, EditQuality,
  AddVersion, DeleteItem, ManageFiles, Rename, MetadataSwitch, NumberingFix, EpisodeDetail.

## Activity (`/activity`)

- **Header:** "Activity" + "4 downloading · live", a **Manual import** (download) button, and a "Search by
  title…" field. On desktop the search sits beside the heading; on mobile it's full-width below.
- **Tab strip:** **Queue (badge) · History · Blocklist · Tasks · Audit · Indexers**. On mobile it scrolls
  horizontally, so Indexers is offscreen; on desktop the whole strip is visible.
- **Queue toolbar:** "4 downloads" in cyan mono, then refresh, an amber **Clear queue** (trash) and Select.
- **Pipeline hero:**
  - Indigo-washed card, "Pipeline", with "1 job · queued · 3 downloading · 0.0 MB/s".
  - "Step 1/6", a segmented step bar, and the stages QUEUED · PARSING · PROCESSED · LINKING · CACHING ·
    IMPORTING. Desktop shows the labels; mobile shows only dots for the later stages.
  - The ETA note.
- **Sections:** Downloading (count) · Up next · Retrying · Working · Just finished. Desktop adds
  right-side captions ("finishing soonest", "next to grab").
- **Download card:**
  - Poster-colour wash filling to the progress %, a poster with a progress ring, title + SxxEyy + the
    tier chip "UHD·4K", the mono release name, and a meta row (size, client, indexer, protocol, state, "queued 1h ago").
  - Then the gradient progress bar, transferred / total · %, ETA, the big %, a trash button and ⋯.
  - Desktop packs this into one row; mobile stacks it in a tall card.
- **Up next card:** a stepper (Downloading → Linking → Caching → Importing) and "Waiting to start…".
- **Other tabs:**
  - History: insights, a 14-day sparkline, Stories | Raw log, Regrab, and Blocklist.
  - Blocklist: reason categories, Group/Flat, and bulk remove.
  - Tasks: system cards, runs, and decision trails.
  - Audit: a timeline.
  - Indexers: fleet stats and charts.

## Calendar (`/calendar`)

- **Desktop:**
  - "October 2026", "9 scheduled · 1 today", and a status legend (Downloaded · Downloading · Missing
    · Unaired) plus a release-type legend (Theatrical · Digital · Physical).
  - Kind chips **All · Series · Movies · Anime**, view segment **Month · Week · Forecast · Day · Agenda**,
    ‹ **Today** ›, and **iCal feed**.
  - Month grid of rounded day cells. Each has "1 airing" and event pills (thumb, title, S02·E05, time, and one dot per
    version). The today cell has a cyan outline.
- **Mobile (screenshot opens on the Agenda list, scrolled to today):**
  - Day headers ("Today · Tue 13" in cyan), a "now 10:58 PM" cyan rule, and event cards (thumb, cyan time
    range, title, SxxEyy · episode title · Anime).
  - One rail per version: tier chip + segmented bar + state ("Wanted" amber, "Soon" blue clock).
  - Today's card has an amber wash.
  - The toolbar/legend is above the scroll position (not visible in the shot).

## Wanted (`/wanted`)

- **Header:** "Wanted" + "5 wanted titles · 4 missing, 1 below cutoff, 3 upcoming".
- **OverviewStrip:** a big total, plus metric bars for Missing (amber), Below cutoff (violet), Upcoming (blue) and
  4K Available (cyan). On desktop it's one row; on mobile it wraps to 2 rows.
- **Filter chips:** Missing · Cutoff Unmet · Upcoming · 4K Available, each with a dot and a count. The active one
  gets a coloured top border.
- Title search, **Search all missing**, and a lead sentence explaining the state.
- **GroupCard:**
  - Poster thumb, title, kind pill (ANIME pink / SERIES teal / MOVIE indigo), and the state word coloured.
  - Version chip with a state dot ("● HD·1080p"), and the cue "10 episodes aired · latest" (mono).
  - A chevron to expand to the missing episodes.
  - Footer: Open in library · search (magnifier) · ⋯.
  - The card wash is tinted by state.
- **4K Available tab:** HD-owned / 4K-available rails, Check for 4K now, and + Add.
- An infinite-scroll footer.

## Discover (`/discover`)

- **Header:** "Discover" + kind segment **All · Movies · Series · Anime**, the "Search TMDB to add movies,
  series & anime…" field, and an "Add as [TMDB logo] ▾" provider menu.
- **Tabs:** **Browse · Requests · Issues** (by permission; approvers see a pending badge).
- **Rails:**
  - Trending (Today / This Week).
  - Latest Trailers (Popular · Trending · Top Rated).
  - What's Popular (Streaming · On TV · For Rent · In Theatres).
  - Upcoming / On The Air, Top Rated, Complete your collections, and Discover with filters (genres,
    watch providers).
  - Each rail head has an icon, title, "n titles" and its own segmented control. The segment is right-aligned
    on desktop and sits under the title on mobile.
- **Card:** a poster with a corner badge (amber flame = trending, green ✓ = in library), title, and year ·
  kind glyph. Mobile shows about 2.5 cards per row; desktop shows 8.
- **Requests:** board/inbox (triage swipe deck, columns, bulk bar, threads). **Issues:** MyIssues + threads.
- **Modals:** RequestModal, TrailerModal, ApproveDialog, and Preview page.

## Settings (`/settings/:panel`)

- **Desktop:** sidebar + panel, with groups Media Management · Quality · Access · Fetching · System. A
  SettingsSearch box is above them.
- **Mobile:** a list → panel push.
- About 50 panels: general, metadata, roots, naming, quality defs / profiles / CFs / TRaSH, users / roles /
  sign-in / public access, download clients, indexers, notifications, instances, appearance / themes / login,
  backup, logs, database, maintenance, trash.

## iOS gaps vs web (cross-check with `docs/ui-plan.md`)

The iOS plan already mirrors most screens one-to-one. What it records as missing or different:

- **Park & Resume Dock** (desktop web): not in iOS v1.
- **In-app docs reader:** iOS opens `/docs` in the browser.
- **Manual import:** the iOS app opens the web page in a Safari sheet.
- **Settings heavy editors** run in a web view: Naming, Library import, Quality definitions, Custom formats,
  Quality profiles, TRaSH, Users, Roles and Sign-in methods. The Indexers table view isn't ported.
- **Activity › Indexers:** the protocol / efficiency / coverage / API-budget / exclusive cards aren't ported.
- **Add flow:**
  - No desktop art column or keyboard hints.
  - The poster doesn't fly to the setup card after adding.
  - The Add-edition sheet (Wanted 4K) has no folder-name, monitor-level or minimum-availability fields.
- **Login:** the living-logo media morphs aren't drawn natively.
- **Activity badge:** the native tab badge replaces the web's gradient badge + pulsing ring (deliberate).
- **Desktop-only web chrome with no iOS equivalent planned (by design for phone):**
  - The status HUD tray in the top bar (iOS uses the attention bell sheet + tab badge instead).
  - The permanent AlphabetRail + letter headers (iOS uses the scrubber, like mobile web).
  - The inline Library pulse meters (iOS uses the stats sheet, like mobile web).
  - The desktop Discover with 8 cards per row and the desktop month grid. iPad / Duo use the unfolded phone
    shell, not this layout.
- **Not called out in the plan; worth checking on device:**
  - The Pipeline hero's 6-stage labels.
  - The Calendar release-type legend icons.
  - Library "Display" (rail style) options.
  - The detail hero's Release timeline chip strip placement.
