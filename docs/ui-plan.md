# fusionha for iOS: UI plan

Status: in progress (updated 2026-10-04). The app shell, screens and login now follow the web app's mobile layout and look.

## 1. Principles

1. **Same app, native skin.** Same destinations, same screens, same flows and the same words as the web UI's mobile layout (≤720px). Anyone who knows the web app should find everything in the same place.
2. **The app looks like the web app.** Same dark tokens, panels, chips, tier pills, coverage rails, page headers and layouts as the mobile web (checked against screenshots of the web app at phone width). Native Liquid Glass is used where iOS provides the control: the tab bar, sheets, menus and context menus.
3. **Liquid Glass sits on the controls, never on the content.** Apple's rule for iOS 26 is that glass is the navigation and control layer floating above content. So the tab bar, toolbars, filter chips, segmented pickers, the bulk-action bar, sheets and the downloads accessory are glass. Posters, edition cards and episode rows stay solid content, just like the web keeps posters clean.
4. **Multi-edition state is always visible.** Every card, row and widget shows its HD/4K edition chips in the status colours from `frontend/src/lib/status.ts`.
5. **Native controls replace custom web controls.** The web rule "no native form controls" exists because browser controls look bad. On iOS the native `Picker`, `Toggle`, `Menu` and `Form` are the point, and they pick up Liquid Glass automatically. This is a deliberate deviation.
6. **Motion maps onto system transitions.** The web's poster-to-hero morph becomes the iOS zoom transition. The web's "alive" cyan downloading pulse becomes `symbolEffect(.pulse)` plus a shimmer on progress bars. Both respect Reduce Motion and the server's `animations_enabled` setting.

Target: **iOS / iPadOS 26+**, since that is where the Liquid Glass APIs live (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass/.glassProminent)`, `tabViewBottomAccessory`, `tabBarMinimizeBehavior`, `backgroundExtensionEffect`, `ToolbarSpacer`).

## 2. App shell

| Web | iOS |
|---|---|
| Mobile bottom nav: Library · Discover · Calendar · Activity · Wanted | `TabView` with the native glass tab bar and **the same five tabs in the same order, with the web's own icons** (SVG template assets copied from `shell/destinations.tsx`) and the cyan active tint. |
| Discover page (search field + poster rails) | Its own **Discover tab**, like the web: kind filter, TMDB search, Browse rails and Requests. |
| Mobile top bar: logo · search pill · avatar | The same custom top bar on every tab. The search pill scopes to **This library** (filters the Library grid in place) or **Everything** (library matches plus TMDB titles to add). |
| Top bar hides on scroll down | The custom top bar slides away on scroll down (and the ＋ orb with it); the tab bar uses `.tabBarMinimizeBehavior(.onScrollDown)`. Tapping the logo scrolls to the top. |
| Activity pulse + queue count in the top bar | A queue-count badge ("99+" cap) on the Activity tab, plus the Live Activity and widget outside the app. **Deviation:** the native tab-bar badge replaces the web's gradient badge and pulsing ring, and Discover gets a native pending-requests badge for approvers. |
| Mobile FAB (＋ Add) on Library / Discover / Wanted | The same 56pt gradient ＋ orb, bottom right, on those screens. It opens the Add sheet. |
| Avatar menu → Settings, Log out | The avatar (Plex photo or initial, amber attention dot) opens a native `Menu`: username + role, Settings, Reset cache & reload, Log out, then the version and Open web app. Log out ends the session and revokes this device's token. |
| Omni search (search pill → "Everything") | A full-screen cover: library matches (prefix-first, year-aware, max 8) and the TMDB add lane, with the web's arming copy. On Library the pill filters the grid in place with a This library / Everything scope bar. |
| Toasts | One app-wide toast stack above the tab bar (`model.toast(_:title:variant:)`), with the web's variants and draining timer bar. |
| Attention control + health badge | A glass toolbar bell with a badge count, opening an **Attention sheet**. Sources: `GET /api/v1/library/attention`, `/system/runs/attention`, `/system/indexers/unavailable` and `GET /health`. |
| Requester role (Discover · My requests · You) | Tabs swap to **Discover · My requests · You**, driven by `request_scoped` from `GET /api/v1/auth/me`, the same rule as `REQUESTOR_DESTINATIONS`. |
| Park & Resume dock | Not in v1. A parked interactive search can later reuse the bottom accessory. |
| iPad | `.tabViewStyle(.sidebarAdaptable)`. The tabs become a sidebar, and Settings uses a split view like the desktop web sidebar. |

## 3. Screen by screen

### Library (`/`)
- **Layout:** large title "Library", with a `LazyVGrid` poster grid. Edition chips sit below each poster, never on the art. A compact list is available as the second density, mirroring `grid | compact`.
- **Library pulse:** a horizontally scrolling row of glass capsule chips in a `GlassEffectContainer`: All · Downloading · Missing · Upcoming · Complete · Needs attention. Each has a count, and the selected chip morphs with `glassEffectID`.
- **Search:** `.searchable` scoped to "This library", the same as the web's `SearchHeader`.
- **Toolbar:** a glass **Filter menu** (type, HD/4K, recency, sort and group-by-status, using the same values as `library-filters.ts`), **Select**, **＋**.
- **Alphabet rail:** when sorted by title, a glass scrubber on the trailing edge, with the same fisheye feel as the web touch scrubber.
- **Long-press a poster:** a context menu with a preview offering Automatic search (magnifier), Interactive search (person), Monitor/Unmonitor (bookmark), Refresh and Delete. This replaces the web's hover icons.
- **Select mode:** toggled from the toolbar (or a poster's menu). The tab bar and ＋ hide and a glass **bottom bar** (a bottom safe-area inset) shows the count, "of N filtered", Select all / Clear / Done and Monitor, Unmonitor, Refresh & Scan, Quality profile, Minimum availability, Change root…, Delete. This is the same set and copy as `BulkActionBar`.
- **Delete:** the web's DeleteItemDialog ("Delete {title}?" + delete-files checkbox) as a short sheet presented from the root, so every screen can call `model.confirmDelete`.
- **A–Z:** letters follow the web's `letterOf` (first character uppercased, non A–Z as #, no article stripping). **Deviation:** no sticky letter headers or rail scroll-spy, to keep scrolling smooth on large libraries.
- **Opening an item:** `.matchedTransitionSource` + `.navigationTransition(.zoom)`, so the poster grows into the detail page. This is the native form of the locked shared-element motion.
- **API:** `GET /api/v1/library`, `POST /library/{id}/search` (no `/api/v1` prefix), `POST /api/v1/library/{id}/refresh`, `DELETE /api/v1/library/{id}`, `POST /api/v1/library/bulk/*`.

### Item detail (`/library/:id`)
The web phone layout is a swipe-down bottom sheet (`MobileDetailFlyout`). On iOS it stays a **large sheet** (`.presentationDetents([.large])`, 14pt corners) presented from the Library, so swipe-down dismisses it exactly like the web. The content order follows `MobileDetailFlyout`. Code: `App/Screens/Detail/`.

- **Hero:** poster-first art that fades into the page, with a Ken-Burns entrance; a glass close button; status chip, title, year (no thousands separator), tagline, meta line (kind, editions, runtime, rating, certification, metadata provider) and genre pills. A compact glass title bar fades in once the hero scrolls away. The blurred poster repeats behind the page as an ambient backdrop.
- **Item actions:** a glass rail like `HeroActionRail`: Refresh (tap = metadata only; a menu adds Refresh & scan files), Preview rename, Manage files / episodes, Check episode numbering, Edition aliases, Report an issue, Edit (`pencil`) and Delete (`trash`), gated by the user's permissions. The rail's "acts on" label echoes the edition scope. Rename, Manage, Report and Aliases open the web app for now.
- **Quality editions (`EditionsSwitcher`):** a VERSION/CUT row (series versions, movie cuts) and an ACT ON row (**All · HD · 4K** pills with have/total fractions, plus an add chip). The scope persists like the web's `fusionha:detail-scope`; tapping the active pill folds the reveal. The reveal below is one of: scoped series (season chips, episode ticks, Root/Profile/Cutoff/Monitoring), series All, versions × tiers matrix, movie All (edition cards + disk footprint), scoped movie. Each has the per-edition rail: automatic search (`magnifyingglass`, with a `SearchModeMenu`), interactive search (`person`), monitor (`bookmark`).
- **Tabs:** Seasons · Files · History · Searches for series; Editions · Files · History · Searches (+ Collection) for movies, with an animated underline. Trailer, Collection, More like this and Cast rails sit under the editions like `DetailRailStack`.
- **Seasons:** collapsible season cards (size, done/total, coverage bar with stripes, ⋮ opens a season actions sheet with Search / State / View groups). Episode cards: monitored dot, left-aligned title, air time, **one status chip per edition**, download pill; tapping expands facts with search and interactive search. The full `EpisodeDetailDialog` is not ported yet.
- **Files:** per season × edition (series) or per edition (movies). Rows show the path (copy button), quality and media chips, dead-link cleanup and delete with a "Delete & blocklist" option. HD chips are purple, 4K cyan.
- **History / Searches:** timeline (day groups, provenance, regrab), lifecycle and insights views; the Searches tab lists decision runs touching the title.
- **Interactive search:** the web's Manual search as a sheet (see below).
- **Dialogs:** Edit item, Add an edition and Delete are native `Form` sheets with the web's fields and words.

### Interactive search
- **Layout (mobile web parity, `InteractiveSearch` + `InteractiveSearchModal`):** a full-height sheet titled "Manual search" with the scoped heading (`Title · HD·1080p`). From the top: the amber auto-search status strip (`.../releases/scope-status`), the indexer-cooldown notice (`/system/indexers/unavailable`), the HD/4K edition toggle (a glass pill group with a check on every searched edition) plus refresh, the "Searched:" strip with query times, then the scan banner (`querying indexers…` → `N releases · ranked by custom-format score`).
- **Filters:** a horizontally scrolling row — title field, glass menu chips for resolution, protocol (only when both are present), indexer (only when more than one) and `Sort:` (Score by default, descending), the sort-direction button and the Hide rejected (on by default) / Hide blocklisted switches. Filters reset when the edition changes.
- **Release cards (`ReleaseCard`):** monospace title, release group (purple) with the provenance chip once grabbed, the `→ UHD·4K` auto-target hint and the BLOCKLISTED badge; a meta row of quality chip, flags, size, age, indexer and seeders (torrent lists only); the rejection reason (amber ✕) or blocklist reason; the signed score (green / red) and the icon-only Grab tile: tray (Grab), warning triangle (Grab anyway, rejected or blocklisted) and a pulsing double chevron (Downloading). Grabs are optimistic like the web: no confirmation; a blocklisted release grabs with the override.
- **States:** pulsing scan banner while querying, "Search failed — try again." (plus the server's reason), "No releases found for this search.", "No releases match these filters.", the real-integrations-disabled box and the all-+0 custom-format warning. Toasts ("Sent to download client") show inside the sheet.
- **Not ported:** the "Last search passed over" skip-reason chips, the learn-edition-alias action, "remove from blocklist" (the server sends no blocklist id) and the web's links into Settings (shown as plain text).
- **API:** `GET /api/v1/library/{id}/releases`, `.../releases/scope-status`, `POST .../releases/grab`, `GET /api/v1/system/indexers/unavailable`.

### Add flow and preview (`/preview/:kind/:tmdbId`)
- **Preview:** the same layout as item detail but read-only, with **Add** or **Request** as a `.glassProminent` button in the bottom toolbar. If the title is already in the library, the button is **Open**.
- **As built (mobile web parity):** Preview opens as a full-height sheet like the web's `PreviewFlyout` (ambient art bleed, the shared phone hero, compact bar after 200pt, seasons, inline trailer, More like this pushes another preview, cast). Its "+ Add to library" opens the page's own Add sheet straight on the configure step (Discover's session provider, no "View details" link back); after the add the new item opens, like the web navigating to it.
- **Add sheet, Find:** the web's search: kind tabs, a TMDB / TVDB source switch (TVDB for series; shown but locked without a TVDB key), the trending grid (or list) while the field is empty, the "Added as · your default / · overridden for this session" note, and the amber key-missing notice in place of Trending or a search when a key is missing. A tile's eye pushes the title's preview inside the sheet, zooming out of the poster.
- **Add sheet, configure (Add title v2, 0.4.127–0.4.139):** the web's phone `AddConfigPanel`, one column: the shared phone hero (scrolls away, close ✕ + back ‹), "‹ Not this one? Search again" / "View details ›", then small-caps sections with counts: **Details** (Identified as id chips that copy, Series type and Metadata rows that expand in place, Folder with inline rename, Plex paths per version and the 409 collision wash, "Defaults from Settings → Default profiles"), **Versions** (HD·1080p / UHD·4K cards: Folder / Profile / Edition rows as native menus instead of the web's picker sheet, dashed "Add a 4K version", the HD row and the manual 4K availability row with its idle / checking / found / none / not-out-yet / error states and ↻; "⟲ Use last settings" with Undo), and **What to monitor** for series (the ten Sonarr chips + Custom as glass chips, the season list with tick bars and counts, press-and-hold-and-slide per season, tap a name for the whole season, "Different for 4K" with a native segmented row pick, live sentences) or **When to grab it** for movies (Announced / In cinemas / Released rail with the Today pill, caption and "Why?"). A sticky glass footer carries the live sentence, Search now and the Add button with the add moment (fill → "✓ Added" → close + toast). Light haptics on every choice.
- **Add ⇄ details morph:** "View details" pushes the title's preview inside the Add sheet's own `NavigationStack` with a native zoom transition out of the hero (`matchedTransitionSource` / `.navigationTransition(.zoom)`), and its button reads **Continue adding**, which pops back to the very same configure state (the flow object lives in the sheet, so no draft store is needed). With Reduce Motion or animations off the push is the system default.
- **Deviations:** no desktop art column or keyboard hints (phone layout only); the Settings links are plain text (no deep link into Settings from a sheet); the poster's "fly to the setting-up card" after adding is not ported (no setting-up card on iOS yet).
- **API:** `GET /api/v1/discover/preview`, `GET /api/v1/preview/tvdb/{tvdb_id}`, `GET /api/v1/search`, `GET /api/v1/search/tvdb`, `/rootfolders`, `/qualityprofiles`, `/config/add-defaults`, `/config/editions`, `GET /api/v1/settings`, `GET /api/v1/library/last-added`, `POST /api/v1/discover/check-4k` (tmdb_id or tvdb_id), `POST /api/v1/library` (`versions`, per-version `edition`, `season_monitor_from`), `POST /api/v1/requests`.

### Discover
- **Layout:** a glass segmented lens **Movies · Series · Anime**, then horizontal poster rails: Trending (Today/Week), Latest trailers, What's popular, Upcoming / On the air, Top rated, Collections. A Filters sheet covers genres and watch providers.
- **Cards:** an "In library" badge opens the detail page. Otherwise a glass ＋ corner button adds or requests. Long-press offers View details, Add/Request, Ignore and Check 4K.
- **Requests and Issues:** a segmented picker at the top (**Browse · Requests · Issues**), shown by permission, with a pending-count badge for approvers. Requests rows swipe to Approve or Reject.
- **As built:** the web's mobile layout one to one: Discover title, inline kind segmented control, the search field that opens the Add sheet (an inline search for requesters), "Add as" provider menu, Browse · Requests · Issues tabs with the pending badge, rails (Trending, Latest Trailers, What's Popular, Upcoming/On The Air, Top Rated, Complete your collections, Discover with filters). Cards open the Preview (requesters: the request modal); long-press is a context menu in the web's 0.4.133 order: View details, Add to library (the Add sheet straight on that title, with the "Add as" session provider), Check for 4K; an in-library card offers Open and Check for 4K; a requester's Request, Check for 4K, View details. Approver rows use a long-press menu for Approve/Reject (they are not in a List, so no swipe). Requesters' "My requests" tab is this page with Requests selected.
- Trailers play in a YouTube embed sheet.
- **API:** `GET /api/v1/discover`, `/discover/trailers`, `/discover/filter`, `/collections`, `/requests`, `POST /api/v1/requests/{id}/approve|reject`, `/issues`.

### Calendar (`/calendar`)
- **Views:** a glass segmented picker **Month · Week · Forecast · Day · Agenda** (the web's five), opening on the view last chosen on this device, else the server's `calendar_default_view`; grids start on `first_day_of_week`.
- **Week:** the web mobile `WeekMobile` pattern, a day strip with an agenda list below. The day strip is a glass bar that collapses as you scroll.
- **Month:** the web's grid: up to two event pills per day (kind strip, code, one unaired-aware dot per edition) and `+N more`. Tapping a pill opens the item; tapping a day's empty space opens that day in the **Day** view.
- **Agenda / Forecast / Day:** the web's grouped timeline: a date rail, a "now" marker in today's group, rows with a coverage rail per edition, opening scrolled to today.
- **Events:** poster thumb, SxxEyy (or absolute number), and one status colour per edition.
- **Toolbar:** the web's toolbar: All · Series · Movies · Anime glass chips, ‹ Today ›, **iCal feed** (admins only) and, in Week, the card-style menu (`PUT /api/v1/settings`), then the status and release-type legends.
- **iCal feed:** a menu with **Copy feed URL** (the web's action) and **Subscribe in Calendar**, which opens the `webcal://` form of `/api/v1/calendar/feed.ics?apikey=…` (the app API key from `GET /api/v1/settings/api-key`).
- **API:** `GET /api/v1/calendar?start&end`.

### Wanted (`/wanted`)
- **Layout (as the mobile web):** head "Wanted" + "{n} wanted titles · m missing, c below cutoff, u upcoming[, k seen in 4K]" from the state-independent totals (`GET /api/v1/wanted?page_size=1`, `GET /api/v1/wanted/4k-available?page_size=1`); the OverviewStrip; filter chips **Missing · Cutoff Unmet · Upcoming · 4K Available** with counts; the title search; the lead text; one GroupCard per title (tone wash, kind pill, state, per-edition HD/4K chips with a state dot, the context cue). Series on Missing list their missing episodes with a per-episode search. Infinite-scroll footer.
- **Actions:** "Search all missing / upgrades" (the web's loop: `GET /api/v1/wanted?page_size=500&state&q`, then `POST /library/{id}/search` per title); a native search-mode `Menu` per card (Search all / Search missing only / Search each episode, the last two via `POST /api/v1/library/{id}/search/gradual` with a live progress strip and Stop); Open in library; Why this decision.
- **4K Available:** cards with HD-owned / 4K-available rails, format tags, sightings and provenance, **Check for 4K now** (`POST /api/v1/library/{id}/check-4k`) and **＋ Add** (a native Form sheet: tier, root folder, quality profile, monitored, search now → `POST /api/v1/library/{id}/editions`). Observer off → "Turn on observing" (`PUT /api/v1/settings`).
- Deviation: the Add-edition sheet omits the web dialog's folder-name override, monitor level / minimum availability and version fields.

### Activity (`/activity`)
Header "Activity" with the live caption and a **Manual import** button, the shared title search (Queue / History / Blocklist, server-side `q=`), and the web's horizontally scrolling tab strip **Queue · History · Blocklist · Tasks · Audit · Indexers** (Audit needs `system.admin`, Indexers `integrations.manage`); the Queue tab carries the count badge (amber when a download is held). This replaces the earlier plan of a segmented picker with Audit/Indexers in a toolbar menu, to stay like-for-like with the web.

- **Queue:** toolbar (count, Process, Clear, Select), the bandwidth / pipeline hero, sections Working · Downloading · Retrying · Up next · Just finished, the web's card anatomy (wash, ringed poster, meta row, gradient progress with shimmer, rate / ETA / %), held and stuck cards, group cards, select mode with the glass bulk bar, Remove / Clear / bulk dialogs and the ⋯ menu (Interactive search, Blocklist, Copy release name). Polls 1.5s with active work, 4s idle, while visible.
- **History:** insight card (total, 14-day sparkline, KPIs), story chips, Stories | Raw log, the story timeline with Regrab (409 override), the Blocklist split action + dialog (with Undo), Search again, Why this decision, Copy release name.
- **Blocklist:** insight card with reason categories and Retry recoverable, category and Group/Flat segments, Show reasons, Select + bulk remove, Clear blocklist.
- **Tasks:** Playful | Plain voice toggle, System cards (Media enrichment, RSS Sync, Scheduled with live countdowns), the live backlog-search card with Stop, Scanning / Queued runs and the Recent timeline with grouped repeats, decision trails (verdict strip, reason groups) and Run again / Search again.
- **Audit:** outcome chips, timeline rows with actor avatar, action, target, times; Load older.
- **Indexers:** the Fleet overview (range segment, KPI tiles, grab-share leaderboard, activity chart). The web's protocol / efficiency / coverage / API budget / exclusive cards are not ported yet.
- **Manual import:** the web's large modal flow opens as the web page in an in-app Safari sheet (header button → `/activity`, a held download → `/activity?rescue={id}`).
- **Motion:** reveal-on-appear with stagger, sliding tab/segment indicators, progress fills (`cubic-bezier(.3,.7,.3,1)`), shimmer sweeps, indeterminate bars, pulsing live dots, spinning task icons, row insert/remove transitions; all stop under Reduce Motion or when the server's `animations_enabled` is off.

### Settings (`/settings/:panel`)
- **Layout:** a `NavigationStack` list grouped exactly like the web sidebar: General, Metadata · Media Management (Roots, Naming, File management, Library import) · Quality (Definitions, Custom formats, Release filters, Profiles, Default profiles, TRaSH) · Access (Users, Roles, Sign-in, Public access, Security) · Fetching (Download clients, Indexers, Connect, Notifications, Connections/instances) · System (Appearance, System, Database, Backup, Logs, About, Media versions, Experimental, Discover, Maintenance).
- **Search:** `.searchable` across panels, like `SettingsSearch`.
- **Presentation:** a full-screen cover from the avatar menu. Panels are pushed by slug through `settingsPanel(_:)` (`App/Screens/Settings/SettingsPanels.swift`).
- **Native now:** General, Metadata, File Management, Release Filters, Default Profiles, Security, Appearance, About, Media Versions, Experimental, Discover and Maintenance. Each is a dark `Form` with the web's section titles and field rows, and each control saves only its own key as soon as it changes.
- **Fetching and System panels, native:** Root folders, Download clients, Indexers (cards plus the fleet overview with Swift Charts; the web's table view is not ported), Connect, Notifications, Connections and API tokens, Public access, System, Database, Backup and Logs are card lists with Form sheets for add/edit, Test where the web has it and a confirm before delete. Notifications: "This device" is the app's own native push (APNs) state: enable, blocked in iOS Settings, server not set up, registered, plus **Send test**. Below it are your other iOS devices (removable), the shared event matrix, and the Web Push devices, read-only since the app is not a browser push subscription. Admins also get an "iOS app push (APNs)" card whose Configure sheet takes the Key ID, Team ID, bundle ID, environment and the pasted `.p8`. The arr-webhook editor, Add connection and the Postgres migration wizard open the web panel. Backup and log downloads go to the share sheet.
- **Opened in an in-app web view:** every panel that is not native yet, including the heavy editors (Naming, Library import, Quality definitions, Custom formats, Quality profiles, TRaSH, Users, Roles, Sign-in methods). The `fusionha_session` cookie saved at sign-in signs the web view in. Accounts that signed in before this change see the web login once.
- **Motion:** the group chevrons turn and the panel headings rise in like the web. All of it is switched off by Reduce Motion or by General → Enable animations.

### Sign-in, account and first run
- **Onboarding:**
  1. Enter the server URL.
  2. The app checks `GET /health` and `GET /api/v1/setup-status`.
  3. Sign in with username and password (`POST /api/v1/auth/login`), or Plex (`POST /api/v1/auth/plex/pin`, opening `authUrl` in `ASWebAuthenticationSession` and polling `.../check`).
  4. The app **mints a personal token** (`POST /api/v1/tokens`, named after the device) and stores it in the Keychain in a shared App Group, so widgets and extensions can call the API with `X-Api-Key`.
- **Demo:** when setup-status has `demo_mode`, an "Explore the demo" button (with the demo credentials form if `demo_require_credentials`) calls `POST /api/v1/demo/login`; the app replays the `fusionha_demo` cookie. OIDC buttons wait on the server's `/auth/providers` endpoint.
- **Uninitialised server:** if the server isn't set up yet, the first-run wizard opens in the web sheet. No native wizard in v1.
- **Account:** avatar, role badge, my requests, sign out. Sign out revokes the token (`DELETE /api/v1/tokens/{id}`).

## 4. Widgets and system surfaces

Widgets read the API with the shared token. Posters come straight from TMDB (`poster_url`; swap `/w500/` for `/w185/` in widgets). On iOS 26, home-screen widgets also render in the clear/tinted glass styles, so posters use `.widgetAccentedRenderingMode(.accentedDesaturated)` and status colours stay as accents.

| Surface | Sizes | Shows | Data source | Interactive |
|---|---|---|---|---|
| **Downloads** widget | S / M / L | Active count, then the top 1–4 downloads with poster, tier chip and progress. A stuck download turns orange. | `GET /api/v1/queue?page_size=4` (`items`, `total`, `progress`, `phase`, `stalled`, `poster_url`, `tier`) | "Process queue" button → `POST /api/v1/queue/process` |
| **Up next** widget | M / L, Lock Screen rectangular | Next episodes and releases for the coming 7 days, with an edition status dot | `GET /api/v1/calendar?start=today&end=today+7` | Tap → that day in Calendar |
| **Wanted** widget | S, Lock Screen circular | Missing / cutoff-unmet counts | `GET /api/v1/wanted?page_size=1` (`missing_count`, `cutoff_unmet_count`, `upcoming_count`) | "Search all" button (same loop as the web's Search all) |
| **Recently imported** widget | M / L | Poster row of the latest imports with tier chips | `GET /api/v1/history?event_type=IMPORTED&page_size=6` | Tap → item |
| **Health** widget | S, Lock Screen inline | "All good" or the count of things needing attention | `GET /health`, `/api/v1/library/attention`, `/system/runs/attention`, `/system/indexers/unavailable` | Tap → Attention sheet |
| **Disk space** widget | S, Lock Screen circular gauge | Free space per root folder (HD and 4K roots side by side) | `GET /api/v1/rootfolders` (`free_space`, `total_space`) | — |
| **Activity chart** widget | M | 14-day grabs/imports sparkline | `GET /api/v1/history/sparkline?days=14` | — |
| **Control Center controls** | — | Process queue · Search all wanted · Open Activity | Same as above | Yes |
| **Live Activity** | Lock Screen + Dynamic Island | "Downloading 3 · 62%". The Dynamic Island compact view shows a ring plus count; expanded shows the top download's poster, title, tier chip, phase and progress. It ends with an "Imported ✓" state using the queue's `just_finished` rows. | `GET /api/v1/queue` | Tap → Queue |
| **Push notifications** | — | Grabbed, Imported, Upgraded, Failed, Manual import needed, Needs attention, Request made, Request available. The poster is attached via a Notification Service Extension. Notifications group by title. Failures are Time Sensitive. | Same events and per-user preferences as Web Push | Actions: Failed → **Search again** / **Open**; Manual import → **Resolve**; Request made → **Approve** / **Reject**; others → **Open** |
| **Siri and Shortcuts** (App Intents) | — | "What's downloading?", "Search for missing", "Add a movie", "What's on this week?" | Same endpoints | — |
| **Spotlight** | — | Library titles are indexed, so searching "Dune" on the phone opens it in fusionha | `GET /api/v1/library` | — |
| **Share extension** | — | Share a TMDB, IMDb or Trakt link from Safari → "Add to fusionha" → Add sheet | `GET /api/v1/search?term=` | — |

**Refresh.** Widgets get a limited daily refresh budget. They refresh on a timeline: about 15 minutes for Downloads while it has work, hourly for the rest. The app also reloads them whenever it polls, and when a silent push arrives. iOS 26 may also let the server push widget updates directly; I haven't verified that yet and will check before building.

The Live Activity is **one aggregate activity, not one per download**. That keeps it inside Apple's update budget and matches the web's single activity pulse. While the app is open it can start the activity itself from polling. Starting it and updating it while the app is closed needs the backend work listed below.

## 5. Backend work the app needs (not started; your call)

1. **APNs channel (built: server branch `claude/apns-push`):**
   - `services/apns.py` adds an `ApnsChannel`, called inside `WebPushDispatcher.dispatch` alongside Web Push, so it reuses recipients, preferences, quiet hours, grouping and payload text.
   - Backend pieces: the `apns_devices` table, and `/api/v1/notifications/apns/{status,settings,devices,devices/token/{token},test}`.
   - App side: the app registers its token after sign-in and on every launch. It sends `sandbox` or `production` based on the embedded profile's `aps-environment`, and unregisters on sign-out.
   - Requirements: an Apple Developer account, and a signing profile with Push Notifications enabled for `org.elabx.fusionha`. Builds signed without that entitlement get no token, and the panel says so.
2. **Live Activity updates:** queue progress is not an event today. This needs throttled progress pushes from the download poll loop, plus registration of push-to-start and update tokens.
3. **Nice to have:**
   - An `eta` field on `QueueRead`. Today it has to be derived from `sizeleft` over time.
   - A light `GET /api/v1/library/stats` endpoint, so widgets don't download the whole library.
   - Returning the session token in the `/auth/login` body. Today it only comes back as a cookie, which works but is awkward.

## 6. Design tokens on iOS

- **Colours:** dark-first, a light theme follows the system. The app tint is indigo `#6366f1`, and the fusion gradient (indigo → cyan) is used only on the `.glassProminent` primary buttons and the brand mark.
- **Status colours:** shared asset colours. Done `#34d399`, Downloading `#22d3ee`, Missing `#f59e0b`, Unaired `#3b82f6`, Unmonitored `#6b7280`, On air `#fbbf24`, Premiere `#818cf8`, Stuck `#fb923c`, Danger `#f87171`, Anime `#f472b6`. Tier chips: HD = purple `#a78bfa`, 4K = cyan.
- **SF Symbols:**
  - Monitor = `bookmark` / `bookmark.fill` (never a checkmark)
  - Automatic search = `magnifyingglass`
  - Interactive search = `person`
  - Edit = `pencil`, Refresh = `arrow.clockwise`, Delete = `trash`
  - Downloading = `arrow.down.circle` with `.symbolEffect(.pulse)`, Missing = a dashed amber ring
- **Type:** SF Pro, with SF Mono for paths, release names, qualities and sizes, as on the web.

## 7. Repo, build and install

**Repo.** [`elabx-org/fusionha-ios`](https://github.com/elabx-org/fusionha-ios), **public**, created by Elmer on 2026-10-04. The server repo `elabx-org/fusionha` stays web and backend only.

- **Why separate:** fusionha is self-hosted, so app and server versions will drift whichever repo the code lives in. The two also release differently (a Docker image versus an IPA), and the server repo's CLAUDE.md and design rules are written for the React app.
- **Why public:** macOS CI minutes are free, Feather can pull IPAs straight from GitHub releases, and no Apple secrets ever reach the repo or CI because builds are unsigned.
- **API client:** the iOS repo pins a copy of `openapi.json` from a tagged fusionha release. At sign-in the app reads the server version and hides features the server doesn't have yet.
- **Backend changes** the app needs (section 5) are opened as normal PRs in `fusionha`.

**Layout:**

```
fusionha-ios/
  project.yml              XcodeGen spec (no hand-edited .xcodeproj)
  App/                     SwiftUI app target
  Widgets/                 WidgetKit + Live Activity (+ Control Center later)
  NotificationService/     rich push (poster image) extension
  Shared/                  theme + Live Activity attributes, compiled into app and widgets
  Packages/FusionhaKit/    Foundation-only API client, models, Keychain credential store
  .github/workflows/       test + unsigned IPA build, IPA attached to tagged releases
  CLAUDE.md                iOS-specific rules (Liquid Glass, native controls)
  docs/ui-plan.md          this plan
```

**No Mac needed.**
- GitHub Actions macOS runners with Xcode 26 run the package tests, run XcodeGen, build with code signing off and package an **unsigned IPA**. Every run uploads it as an artifact.
- Tags `v*` attach the IPA to a GitHub release, which Feather can install from directly. A Feather source JSON for in-app updates can follow.
- Next: simulator screenshots of the main screens attached to each run.

**Install with Feather, signed with Elmer's paid certificate:**
- Register explicit App IDs on developer.apple.com: `org.elabx.fusionha`, `org.elabx.fusionha.widgets`, `org.elabx.fusionha.notification-service`. Turn on **Push Notifications** and the App Group `group.org.elabx.fusionha`. Make profiles that include the phone.
- Don't change bundle IDs when signing. Push, and the widgets reading the shared sign-in token, depend on them.
- Development profiles use Apple's test (sandbox) push server and ad hoc profiles use production. The server's APNs settings need a matching choice.
- Not yet checked: how Feather signs extensions that each have their own profile. If that's awkward, the first version ships the main app plus push, and the widgets follow.

## 8. Suggested build order

1. **Foundation:** XcodeGen project and CI that produces an unsigned IPA (starter in progress); then app shell, sign-in and tokens, Library, Item detail (read, monitor, search), Activity → Queue with the downloads accessory.
2. **Core flows:** Interactive search, Add flow, Search/Discover, Calendar, Wanted, History.
3. **System surfaces:** widgets, Control Center controls, Spotlight, Share extension.
4. **Push:** the APNs backend channel and notification actions, then the Live Activity with server updates.
5. **Settings:** the native subset, then the heavier editors over time.

## 9. Open questions

1. **Settings scope in v1:** the native subset plus web sheets for the heavy editors (recommended), or everything native from the start?
2. ~~Where the code lives~~: decided, the public `elabx-org/fusionha-ios` repo (section 7).
3. **Tab layout:** is Discover-inside-Search right for you, or do you want Discover as its own tab with Wanted moved under Library's "Missing" filter?
