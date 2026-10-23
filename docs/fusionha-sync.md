# fusionha sync log

The iOS app follows the fusionha server and web app (elabx-org/fusionha), which
add screens and features faster than this app. This file records the last
fusionha commit the app was checked against, so the next catch-up starts there
instead of from scratch.

## Last sync

| | |
|---|---|
| fusionha branch | `main` |
| fusionha commit | `64ced709` |
| fusionha release | **0.4.222** (`v0.4.222`, 2026-10-19: solid status fills, status by wash; 0.4.221 shared palettes) |
| Checked on | 2026-10-19 |
| Previous sync | `4152c68a` / 0.4.220 (2026-10-19) |
| Last CI | build-362 on `2006eed`: green |
| Living fusion moves | synced to **v0.4.224** (`49c6170b`, 2026-10-20), see the 0.4.224 section; the rest of 0.4.223–0.4.224 is not yet checked |
| Handover doc | fusionha's shared Claude Doc, messages #1–#29 (the iOS ACKs are under "ACK from iOS") |

Since 0.4.201 releases are tagged `v0.4.N`; `frontend/openapi.json` at the tag
is the spec.

`Packages/FusionhaKit/openapi.json` is pinned at **`v0.4.222`** (`64ced709`,
`info.version` 0.4.222; re-pinned 2026-10-20 from the 0.2.0 spec). It is a
reference only: the FusionhaKit models are hand-written and nothing generates
or tests against it. The re-pin checked the fields that were typed ahead of
the old pin against the tagged schemas: `calendar_week_layout`
(`AppSettingsRead`, now read through `AppSettings.weekLayout`), `needs_you`
(`RequestCountsRead` / `NeedsYouRead`, `ImportSessionSummaryRead`),
`eta_seconds` (`QueueRead`, `LifecycleEntryRead`), `LifecycleEntryRead.quality`,
`last_message` (`ThreadItemRead` / `LastMessageRead`), insights `weeks` /
`window_start` (`RequestInsightsRead`) and the sync `counts`
(`SourceCountsRead`). All match; they stay optional or defaulted where an
older server omits them. `ui_theme` is a plain string in the spec (no
enum of names). `GET /api/v1/auth/providers` is still not in the spec (the
app tolerates its absence). Re-pin again from the next tag you sync to.

## Unified search (iOS, 2026-10-23; branch `duo-spread-s3-search`)

Built client-side against endpoints already in the pinned spec: `GET /api/v1/search`
(kind=all), `GET /api/v1/search/tvdb` (409 `tvdb_not_configured` = skip) and
`GET /api/v1/search/by-id` (new `APIClient.searchById`, asked once per kind: movie +
series for TMDB / IMDb ids, series for TVDB). Open with fusionha: web parity was
proposed to the peer, and a server `GET /search/unified` (fan-out, dedupe, caching)
may follow; when it lands, add one `UnifiedSearchSource` conformer
(`Packages/FusionhaKit/Sources/FusionhaKit/UnifiedSearchSource.swift`), no UI change.
The by-id route takes `kind` (default movie), so a `tt…` id costs two calls.

## Where the cloud session stopped (2026-10-18)

Every fusionha message up to #42 is read and ACKed (by direct message from #32 on). Everything below is
ported and green, and nothing is half done. Still to do:
- 0.4.214 is tagged and checked against the final shapes (doc #28): the own-request
  rule and the card scale matched. Two fixes followed: the swipe card's
  low-space warning at 12.5 pt, and the policy sheet's note when an admin's
  `auto_approve_tiers` is inherited from "admin".
- 0.4.215 sync progress is ported (see its section below).
- Coming from fusionha: requests phase 10b (MDBList, Trakt, other people's
  Plex lists, admin import lists). Port each one when its shapes are posted.
- Live Activity posters: the 4 KB state budget limits sharpness on
  Feather builds without the App Group (see the Live Activity notes in
  `docs/ui-plan.md` and `LiveActivityPosters` in
  `App/LiveActivityController.swift`).
- The redesign migration of the remaining screens (task "Migrate every
  screen to the redesign").

## 0.4.224: the Living fusion moves (synced at `v0.4.224`, `49c6170b`)

Read from `frontend/src/components/login/living/` at the tag: `fusion-dance.ts`
(+ test), `fusion-moves.ts`, `fusion-paint.ts`, `blade-art.ts`, `tv-art.ts`,
`quality-art.ts`, `moves.ts` and the owner-approved mock
`design/mocks/living-fusion-moves.html`.

- **Maths in FusionhaKit** (`Sources/FusionhaKit/Living/`): `FusionDance`
  (timeline, easing, the two clap times, `tvTime` without the CRT off/on,
  `qTime`/`qAlpha`, scales, flip, clapper morph) and `FusionDanceLayout`
  (outlines, layout, travel, motion, pose), `LivingMat` (the canvas affine
  maths), `LivingVector` (the traced F, resample/align/lerp, the clapper
  outlines) and `LivingMoveName.order(media:)` (`buildMoveOrder`).
  `FusionDanceTests` is `fusion-dance.test.ts` with the same numbers;
  `LivingMoveOrderTests` is the rotation block of `fusion-moves.test.tsx`,
  including the no-same-object-neighbour rule (wrap included).
- **Shared painters:** the `tv` move and fusionMedia both draw `LivingTVArt`
  (pose + painter); the `quality` move and fusionQuality both draw
  `LivingQualityArt` (`drawPix`, `drawBar`) on `LivingQuality.frame`; the
  `fusion` move and both fusion moves land with `LivingEngine.fuseFlash()`.
  New: `LivingBladeArt` (vector blades in the blade gradients, clapper
  stripes, board lines, clap), `LivingFusionPaint` (floor, contact spark +
  particles, merge whirl), `LivingFusionFrame` (one frame, the 2pt shake).
- **Rotation:** the web's order filtered to what iOS plays
  (`LivingEngine.playable`). Media off: arrivals, fusion, quality, pride,
  fusionQuality (the web's exactly). Media on: arrivals, fusion, pride, tv,
  quality, anime, fusionQuality, fusionMedia (Three kinds, Movie and Dragon
  are F2b), and the neighbour rule still holds (tested).
- **Deviations:** the clapper is drawn only by fusionMedia (the `movie` move
  itself is still F2b). The clap and CRT brightness use the app's existing
  `light × 0.45` mapping for CSS `brightness()`. Shadow blur radii follow the
  existing quality move (half the canvas `shadowBlur`).
- **Device-only checks:** the dance's look and timing, the vector F landing
  exactly on the image-masked mark at the end (no jump when the mark returns),
  the 4K copy's mirror and glow, the pixelated copies under the dance's
  transforms, and the frame rate of the fx canvas while dancing.

## 0.4.221–0.4.222 and the #54 parity audit

- **0.4.221** shared palettes: `design/palettes.json` is pinned at
  `Shared/palettes.json`; `SharedPalettesTests` asserts `PaletteTokens`
  match it. The stored `onAccent` is gone (computed by contrast). The web's
  mono status language (shade + pattern + glyph, `lib/status.ts`) is ported
  as `MonoStatus` (FusionhaKit) and a Mono-aware `actWash` (B8).
- **0.4.222** no gradient on status rails or meters, and status shown by an
  ambient wash, never a border or a left bar. iOS did this in B2 (combo rail
  in two solid segments, the poster attention ring now a soft glow).
- **#54 parity audit:** `docs/parity-audit.md` (table, batches, fusionha's
  #56 rulings). B1 blockers, B2 part 1 and B8 have shipped; B3–B7 and B9
  (Duo unfolded) are next. The empty Queue (#53) is ported.

## 0.4.218–0.4.220: no gradients, the deck stack, Proposal 2

- **0.4.218** no gradient on any control (owner rule). iOS already matched:
  solid `Theme.primary` + `Theme.onAccent`; the sync bar moved off `Theme.fusion`.
- **0.4.219** the phone Inbox deck as a stack. iOS did it first (`DeckEdges`,
  build-365); the web follows the same mock.
- **0.4.220** Proposal 2: Browse | Requests under the title, Issues as a
  Requests view (gated on `issues.manage`, old Issues links redirect), Inbox
  Cards | List (build-367). `GET /requests/counts` gains `needs_you {total,
  requests, issues, open_issues}`: the badge reads it, counting by hand on older
  servers (build-369); golden test on `request_counts_needs_you.json`.
  `NEEDS_ADMIN` reads "Needs an admin" on the accent (`IssueFormat.stateTone`
  `.accent`, chip text in `Theme.accentText`); reopened stays amber "Reopened".
- Next: 0.4.221 ships `design/palettes.json` (iOS palettes on the web); iOS pins a
  copy and asserts `PaletteTokens` match it.

## 0.4.216–0.4.217 and the Requests navigation Final

- The Requests navigation Final (owner-approved 2026-10-18, mock
  `requests-nav/index.html` Final v9) is built: the header row with a
  bottom-sheet view drawer (Inbox, Board, History, Threads, Insights, Mine,
  then Rules in Settings › Requests), a filter sheet per view that sends
  `source=` with the server aliases (`MANUAL`, `plex`, `letterboxd`), and
  the phone Board without a stage strip (the "9 pending · 1 downloading"
  summary, pinned stage headers, swipe with Undo, a context menu). History
  is grouped by day. Builds 357 and 362.
- 0.4.216: `eta_seconds` on the queue and the lifecycle (about N min left),
  `ThreadItemRead.last_message` (Author: text), insights `weeks` and
  `window_start`. Build 360.
- 0.4.217: `LifecycleEntryRead.quality` on Downloading rows, plus the
  web's copy (Approved X / Declined X, N decided this month, No requests
  match.). Build 362.
- Owner rules from this round, shared with the web: text on the accent is
  black or white by contrast (`Theme.onAccent = onFill(i1)`), and no
  gradient on any control (the gradient stays in the logo, sign-in and
  avatars).
- Open: the web's 0.4.218 no-gradient sweep needs no iOS change.

## 0.4.215: Watchlists & lists sync progress

Checked against `v0.4.215` (`frontend/openapi.json`, the approved mock
`design/mocks/requests-sync-progress.html` and the web diff
`v0.4.214..v0.4.215 -- frontend/src`).

Done:
- `sync {state, checked, total, started_at}` (`SourceSync`) and `counts
  {requested, owned, queued, waiting, skipped, baseline}` (`SourceCounts`) on
  the diary, the own watchlist (which also gains `next_check_at`), every
  linked Letterboxd source, the Plex watchlist and each Plex list. All
  optional: an older server decodes with nil and the screens show zeros.
- The rules live in the Kit (`SyncProgress`, the web's `sync-progress.ts` and
  `sync-copy.ts`): the state line ("Checking 24 of 38 · 6 requested so far",
  "Reading the source…", "Up to date · checked … · next check …", "Waiting
  for the first check", "Couldn’t read … · … · retrying …", "Paused · …"),
  the bar's percent, the five counts, the queued hint and the diary's
  baseline note.
- Account › Watchlists & lists: the state line (`SyncStatusView`, dot +
  line + bar) and the count tiles (`SyncCountGrid`) on the own watchlist,
  each linked source (Paused with the last counts while it is off) and the
  Plex watchlist; the line alone on the diary and on each Plex list. Pills
  read Syncing (grabbing) / Error (danger) while a pass runs or fails, Sync
  now reads "Syncing…" with "Runs on its own too; this follows it.". The
  screen re-reads every 2 s only while something runs (`.task(id:
  store.anyRunning)`), and stops once all are idle.
- Activity › Tasks › System: the admin-only **Watchlists & lists** card
  (`GET /api/v1/system/request-sources/summary`, `RequestSourcesSummary`,
  `WatchlistsTaskLogic`): the overall line and bar, one washed row per
  source, Today (Requested · Owned · Skipped · Errors) and the three jobs as
  mono labels with status dots. The three job runs leave Recent, with the
  web's "no longer clutter Recent" note. The tab polls at 2 s while a source
  runs.
- The bar fills with the accent gradient (`Theme.fusion`, the web's
  `--grad`); the running dot and pills use `Theme.grab` as on the web.
- Goldens: `letterboxd_me_syncing`, `plex_watchlist_me_syncing`,
  `request_sources_me_syncing`, `request_sources_summary` (new, in
  `SyncProgressTests`); the 0.4.215 versions of the existing Letterboxd /
  Plex / request-source fixtures, which gained the blocks.

Not ported:
- The admin status reads (`/users/{id}/plex-watchlist`,
  `/users/{id}/request-sources`) also carry `sync` / `counts`; the web
  shows nothing new there, so the app does not decode them yet.
- The web's count "tick" (a short lift and green tint when a number
  grows) is the system numeric roll here.

## 0.4.209–0.4.213: Account › Watchlists & lists (the user's own side)

Done: `/me/plex-watchlist` (+ sources, sync), `/me/letterboxd`,
`/me/request-sources` (+ preview, sync), the CSV/ZIP import (202 then
poll `GET …/preview/{token}`, commit) and `/me/suggestions`.
`App/Screens/Account/Watchlists/` has every read-model state, and
`fusionha://account#watchlist` opens it. Discover gets the "From your
Letterboxd" rail (`Discover/Letterboxd/`). Goldens are in
`WatchlistSourcesTests`.

## 0.4.209–0.4.214: automatic request sources (requests, approver, admin)

Checked against release 0.4.213 (`docs/API.md` phase 9 and 10a) plus the
0.4.214 notes. The user's own Account › Watchlists & lists, `/me/*` and the
Discover suggestions are a separate change.

Done:
- `source.owner` / `source_id` / `requested_again`, `PLEX_LIST` and
  `LETTERBOXD_WATCHLIST` (`RequestSourceWords`: the web's `sourcePhrase`,
  `source-words.ts`); badges on cards, the thread header, the deck and the
  decision card. "Request again" (`again_of`) on the owner's withdrawn
  automatic request; the withdraw label and toast name the source.
- `/requests/counts` `by_source[]` and the From source filter on My
  requests (`RequestSourceFilter`: `source=plex|letterboxd|<kinds>`,
  `source_id`, `source_label`).
- Request policy `auto_request_plex_watchlist`, `can_link_lists`,
  `max_linked_lists`; `inherited_from` `admin` → "Admin: always on" (unknown
  layers still decode).
- `WATCHLIST_APPROVE` "Watchlists & lists" with `params.sources[]`; a
  `plex_source`-only rule reads as its Plex classes (`RuleSource.of`).
- Admin: `/users/{id}/plex-watchlist` (+ `PATCH {paused}`),
  `/users/plex-watchlist/summary`, `/users/{id}/request-sources`,
  `/users/letterboxd/summary`, `/requests/watchlist-stats`,
  `/requests/letterboxd-stats`. `outcomes` keys are looked up letters-only
  because the snake-case decoder camel-cases dictionary keys.
- Settings: the four check intervals on the Rules lane (as on the web) and
  `flaresolverr_url` + `POST /settings/test-flaresolverr` under Indexers.
- 0.4.214: admins decide their own requests (`OwnRequestRule`); the inbox
  card scale; the policy sheet notes an admin's auto-approve of every tier
  (`inherited_from.auto_approve_tiers = "admin"`).
- Goldens: `request_from_plex_list`, `request_from_letterboxd_list`,
  `request_counts_by_source(_letterboxd)`, `plex_watchlist_admin`,
  `plex_watchlist_summary`, `letterboxd_admin`, `letterboxd_summary`,
  `letterboxd_stats`, `flaresolverr_test_ok` (`GoldenSourceFixtureTests`).

- Users list: per-row Plex watchlist and Letterboxd chips (dot, label,
  "N requested · …") and the Show filter All · Plex · Watchlist · Letterboxd
  (`UsersShowFilter`). The chips are display only; the row opens the account
  sheet, whose Automatic requests section opens the status.
- Thread `created` lines for automatic and re-requested rows (`data.source`,
  `data.again`; `RequestCreatedLine.swift`) and the auto-approved strip's
  source mark with its `stripPhrase` read aloud.

Open: nothing from 0.4.209–0.4.214.

## 0.4.204–0.4.205 (this sync)

Done:
- 0.4.204: `ManualImportRow.finding {code, label, text}` and `badges [...]`.
  The collapsed row's chips use the server's label, `text` is the
  accessibility label and the opened row's sentence; the glyph follows the
  code (`really_episode` ↪, `holds_episodes` ⇄, else ⚠). Older servers fall
  back to the app's own chip rules. Golden fixture `manual_import_row_finding`.
- 0.4.205: the app requests the Live Activity with `pushType: .token` and
  registers its push-to-start and per-activity tokens with
  `POST /api/v1/notifications/apns/live-activity` (prefs from Account ›
  Live Activity, re-sent when they change); an ended activity's token is
  deleted. `ApnsStatus.live_activity_enabled` decodes.
- 0.4.205: `POST /queue/pause` / `/queue/resume` (admins: a pause button in
  the Activity header, confirm before pausing, the reply's per-client answer
  as a toast). `GET /queue` `paused` / `paused_at`; the Live Activity shows
  a Paused capsule.

Open:
- Server pushes don't carry `thumbs`, so a server-started activity has no
  posters unless the widget saw them in an app-sent state this session.
- 0.4.206 changes `steps` to `{labels, done, current, detail}`; the app
  already reads `current` + `detail`.
- The owner's server has no APNs key yet (`configured: false`).

## 0.4.203: the client consistency bundle: the client consistency bundle the app asked for

Done:
- `held: {code, short, text}` on queue and history rows (`HeldDisplay`).
  The held card leads with `held.short` (code `other` reads its path-free
  sentence) and shows `held.text` under it when no detail panel explains
  it; the Live Activity's tag is `held.short`; a HELD history step reads
  "Held: …"; the library stats line uses the sentence. The app's own hold
  table stays only as the fallback for older servers.
- `requests_last30d` read beside `requests_30d`.
- fusionha's golden fixtures (`docs/fixtures/`) are copied to
  `Packages/FusionhaKit/Tests/FusionhaKitTests/Fixtures/golden/` and decoded
  in `GoldenFixtureTests`; re-copy them when fusionha changes them.

No change needed: `/threads` already paged on the body's `next_cursor`
(the new `X-Next-Cursor` header carries the same value); `evidence_list` is
top-level only with JSON-string values, so the manager's Evidence rows keep
walking `diagnosis` like the web's `evidence-rows.ts`. Not yet used:
`info.version` and `design/tokens.json` (compare with `Shared/Theme.swift`
when the redesign migration touches colours).

## 0.4.201 – 0.4.202

Done:
- **0.4.202 Manual Import, one file at a time**: per-row Import this file /
  Assign / Re-match / Keep current (remove, remove + blocklist, leave),
  per-download finish through `finish_disposition` or finish-rescue's
  `disposition`, Done receipts, pack progress, finding chips, the new footer
  (`ManualImportFinishPlan`). 0.4.201 was pure moves plus the search "+" fix.

The full catch-up of web-only screens (the user asked to stop porting one
release at a time) is under way. Native now, where the app used to open the web:
- Requests: approver chips, Requested-by strip and Message all, Rules (rules,
  guards, quota, auto-approved), Insights, Guardrails (Settings), the
  release-group Blocklist.
- Access: Users, Roles, per-user and per-role request policy, signed-in
  devices. Activity › Audit on the readable rows (counts, actors, sensitive).
- Notifications delivery (Immediate / Daily digest / Off) and the digest
  preview; download-client capabilities; episode numbering reset.
- Manage files / Manage episodes (edit, bulk set, replace, clean up, move to
  version, delete, re-scan, import loose files).
- Manual Import folder scan (path, Browse…, Scan), match to any library
  title, the selection menu. Tasks › Needs attention (enrichment issues).
- Queue pack episode list; history lifecycle sheet.

- Settings: Quality Profiles and Definitions, Custom Formats and TRaSH
  Guides, Naming, Security, Sign-in methods (server), Plex server and Import
  Library are native; every Settings panel is now native. A first-run setup
  wizard replaces "finish setup in the web app".

Still web-only: docs, the Postgres migration wizard and the arr-webhook
editor (Settings › Database / Connect).

## 0.4.200

Nothing to port: `193ed23b..b3c5ab8d` splits `api/schemas.py` into
`schemas_*` modules and TasksTab into `routes/tasks/` (pure moves, API
byte-identical).

Done in the app since 0.4.199:
- Requests step 4: the reporter side of issues, then the managers' Threads
  view, issue pane and 0.4.197's keep-old (staged) flow.
- Held Live Activity: overlapping posters, Review all in the corner, one line
  per title with a short hold tag. The tags are app-side
  (`QueueCardText.heldTag`), classified like `services/held_history.py`
  `reason_code_for` plus the holds it files under `other` (numbering review,
  sample runtime, busy slot, failed record, stuck publish, current file
  changed, unreadable resolution). A reworded server reason falls back to
  "needs a look"; see ask 1 below.

## 0.4.199

Done:
- **Manual Import decision wording.** The footer reads "N files need a
  decision" (was "Choose for N more files"); the held strip's "to decide" is
  the footer's own count (`ManualImportHeldStrip(scan:decide:)`), its upgrade
  count leaves out title-blocked, orphaning and unimportable rows; a collapsed
  row's reason names the real cause first: "File says 'Mafia' — that's S06E06
  in your library, not S06E05", then "This file holds E04 + E05 — assign both
  to replace the two-parter", then the orphan sentence.
- The rest of `16635380..193ed23b` is server-side split tooling (no API change).

Also since 0.4.198, the requests revamp (fusionha phases 1–7, already on the
server): steps 1–3 of the iOS plan are in (requester list, thread, sheet with
Me too / Watch / wishlist, Discover demand row; approver Inbox swipe deck,
Board, History). Still open: issues (step 4, incl. 0.4.197's keep-old flow),
Threads, Rules, Insights and the request policy panels (step 5).

## 0.4.197 – 0.4.198

Done:
- **0.4.198 queue sections and action rows.** The queue's card sections are
  the web's: Needs you (held + stuck) · Importing · In progress (decypharr
  phase jobs, non-terminal retries) · Downloading (real byte transfers) ·
  Failed (terminal phase errors), then Up next and Just finished
  (`QueueSections.swift`, routing as `queueCardGroup`). Every card's action
  row is the primary capsule filling the row plus three fixed 40pt icon slots
  (re-grab or an empty slot, remove, ⋯; on groups Remove all, ⋯, the
  expand chevron), so primaries share a right edge. Phone labels read
  "Review" / "Review all N"; Needs you's "Review all N" is an outline capsule.
  Remove all confirms with every download, sizes and the total, and offers
  delete-files (when any row has a file) and blocklist; the group's ⋯ has
  Open title and Copy release names.
- **0.4.197 error copy.** The phase-7 codes have the web's words.

Not yet: 0.4.197's issue keep-old replacement UI (staged compare, Use /
Discard / Re-grab, reporter fix progress, Guardrails) arrives with the app's
Requests / Issues revamp.

## 0.4.196

Done:
- **Held pack outcomes.** `QueueItem.packSummary`, `packMixed`,
  `packOutcomeRanges` and `QueuePackEpisode.outcome` (`QueuePackDecisions.swift`,
  wording from the web's `pack-decisions.ts`). A held pack's card reads
  "Pack · 13 files · 9 import-ready · 3 held · 1 already owned", then one
  capsule per outcome run ("E01–E09 import-ready": ok green, held amber, skipped
  dim). A pack whose files differ gets an amber "1080p · Mixed" chip; a tap
  shows "E03–E05 probe 1280×720, the other 10 probe 1920×1080".
- **Section counts count downloads.** Downloading counts each download in a
  group or 4K + HD pair, not cards.

Not ported: the expandable per-episode file list (the iOS card has no pack
expansion yet; `outcome` is decoded for when it does).

## 0.4.191 – 0.4.193

Done:
- **0.4.191 Plex re-auth.** A key-holding backup on a Plex-only account is
  confirmed with Plex (`reauthMethods`, `startPlexReauth`, `checkPlexReauth`;
  the grant goes to `downloadBackup(grant:)`); an account with both methods
  gets "Confirm with Plex" beside the password. Rotate's new refusal doesn't
  touch the app.
- **0.4.192 Web sign-in.** `FusionhaWebView` swaps the device token for a web
  session cookie (`POST /auth/session`, `WebSignIn`), reuses it until its
  `expires_at` or a 401 from `/auth/me`, and opens without one on
  `auth_not_active`. Session and demo accounts, and any refused swap, keep the
  old `X-Api-Key` page script. New codes have copy.
- **0.4.192 Calendar progress.** Grabbing rails read `↓ 42%` and fill to the
  percent; phase-mode jobs (null) keep the plain `↓`.
- **0.4.192 Edition on queue/history.** `QueueItem.edition` /
  `hasMultipleEditions` and `HistoryEntry.edition`; chips read `Extended · HD`
  (`VersionLabel`; Standard only when the title has several editions).
- **0.4.193 Manual Import title check.** Rows decode `title_check`,
  `runtime_check`, `recommended(_episodes)`, `episode_overridden`,
  `episode_title_dismissed`; `ManualImportTitleRules` ports `title-check.ts`
  (block, status, selection, held-strip bulk, orphan text, re-match, assign,
  summary) and the rescue sheet shows the title and assign notes, the runtime
  line and the strip summary. `keep_current_empty_slot` has copy. The
  season-level `numbering_mismatch` attention row needs nothing new.

- **0.4.194 Activity queue redesign.** `QueueLogic.group` ports
  `queue-groups.ts`: one title + episode in several versions folds into a pair
  card (always open), then separate downloads of one title + version into a
  group card, collapsed by default and remembered per section for the run.
  The header (`QueueGroupHeader`) has the version label, "N downloads · total",
  the states summary in the web's order (failures red), an 8-code episode
  strip and "Review all N / Review K held in Manual Import". Expanded rows are
  full queue cards without poster or title. `has_multiple_editions` drives
  "Standard". No pack summary line or "Mixed" marker yet (fusionha deferred them).

- **0.4.195 Capsule buttons.** The app's buttons were already capsules with
  round icon buttons; `ActButtonStyle`'s press is now scale 0.97 + dim (dim
  only with Reduce Motion). No API changes.

## 0.4.188 – 0.4.190

Done:
- **0.4.188 Security.** Backups that hold the secret key need the password
  again: `BackupRecord.keyIncluded/encrypted/keyFingerprint`, a "Contains key"
  badge, and a password prompt that downloads through `POST …/download`
  (`BackupDownloader`). Settings: the app API key panel is now `apikey`;
  `security` (secrets at rest), `plexserver`, and Sign-in methods' trusted
  proxies open as signed-in web panels.
- **0.4.189 Queue card (data).** `QueueItem` decodes `stages`, `last_phase`,
  `file_count`, `pack_ranges`, `grab_history_id` and `parsed`; `QueuePage`
  decodes `pipeline`. The rail now follows the server's stage plan (skipped
  stages greyed, "step N of M" over the stages that run), with `QueueRules`
  as the fallback for older servers. Cards show the release-fact chips and a
  pack's done / now / waiting ranges; ⋯ has Re-grab; the idle pipeline shows
  the last import. Settings › Download Clients has the decypharr stage switches.
- **0.4.190 Manual Import keep current.** Comes with the signed-in web sheet;
  the new codes (`rows_open`, `not_held`, `finish_in_progress`, `db_busy`)
  have plain copy in `ErrorCopy`.

Still open from 0.4.189 (queue card visuals): the "Needs you" group, the
source group, 4K+HD pair lanes, the narrow layout and the pack episode list
(`GET /queue/{id}/pack-episodes`, already in FusionhaKit as
`queuePackEpisodes`).

Still open from 0.4.187:
- Activity: history lifecycle sheet; the remove sheet's three opt-ins.
- Requests and Issues revamp (mocks in `docs/design/redesign/requests.html`).
- Manual Import native, step 2: the folder scan (`POST /scan`, `GET /browse`),
  re-match to any title (item search), the bulk Actions / Edit N selected
  sheet. Step 1 (held-download rescue) is native: `App/Screens/ManualImport/`,
  rules in FusionhaKit `ManualImport*.swift`.

## Waiting on fusionha

- Per-device sessions (`GET /auth/sessions`, `POST /auth/sessions/revoke-others`,
  …): additive; a candidate for the Account page.
- Monolith splits start after their requests Phase 7 merges.
- Live Activity pushes (push-to-start and throttled progress updates) and the
  pause/resume endpoints the Live Activity's Pause button needs. Until then the
  activity only updates while the app runs, and shows "updated … ago" when stale.

## Asks for fusionha

What would keep the web and iOS consistent with less hand-porting, most
valuable first. Each came out of a real catch-up or bug.

1. **Display copy from the server, beside the codes.** The web owns the words
   (request triage facts, issue states, staged-copy refusals, Manual Import
   decisions, queue holds) and iOS re-implements each rule in Swift, so every
   web wording change drifts until the next sync. Responses that carry the
   label next to the code would keep both clients identical. First case: the
   queue's held item sends only the raw `held_reason` sentence, while the
   server already computes a `reason_code` (for history only). Send e.g.
   `held: {code: "multi_episode_orphan", short: "splits an episode pair",
   text: "Would orphan other episodes…"}`.
2. **Publish `openapi.json` with every release.** The pinned spec here still
   says 0.2.0 and every model since was written by hand; decoding slips like
   `requests_30d` arriving as zeros came from that. A per-tag spec lets the
   app generate its API layer and turns a catch-up into a diff.
3. **A "client impact" note per release:** API changes, copy changes,
   new or changed screens. 0.4.200's "pure moves, API byte-identical" is the
   ideal: it told us at once there was nothing to port.
4. **One convention per thing.**
   - Paging: requests and issues send `X-Next-Cursor`, `/threads` sends
     `next_cursor` in the body. Pick one.
   - Keys: no digit after an underscore (`requests_30d` decodes as
     `requests30D` under convertFromSnakeCase).
   - Free-form maps (issue diagnosis evidence) as `[{key, value}]`, so keys
     survive client key conversion.
   - Errors: keep `{detail: {code, reason}}` everywhere and publish the code list.
5. **Live Activity pushes and pause/resume** (see Waiting on fusionha).
6. **One change feed** (`GET /api/v1/changes?since=` or SSE) instead of each
   client polling the queue (2 s), threads (15 s) and board (30 s): both
   clients update together, with less battery, and widgets can follow.
7. **Golden JSON fixtures** from backend tests (queue item, held item, request
   with triage, issue with a staged copy) that FusionhaKit tests decode, so
   the app tests the real shapes, not hand-typed ones.
8. Smaller:
   - Web routes as the canonical deep links in push payloads, so a
     notification opens the same screen in both clients.
   - Export the colour and status tokens (`status.ts`) as JSON, so HD
     purple, 4K cyan and the status colours come from one place.
   - A capabilities list in `/auth/me` (what this user can do, per surface),
     so both clients gate buttons identically instead of each checking
     permission names.

The three that matter most are 1, 2 and 3: together they make consistency
mostly automatic.

## How to continue

1. In the fusionha repo: `git log --first-parent --oneline 299b0251..origin/main` and read the
   release commits (`release: 0.4.x — …`) for new screens, endpoints and copy.
2. Diff the API: `git diff 299b0251 origin/main -- backend/` (routes and
   schemas) and the web client under `frontend/src/` (routes, `lib/api`).
3. Map each new screen or flow onto `docs/ui-plan.md` and build it in the
   redesign (`docs/design/redesign/DIRECTION.md`).
4. When done, update the table above with the new commit, release and date.
