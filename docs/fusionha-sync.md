# fusionha sync log

The iOS app follows the fusionha server and web app (elabx-org/fusionha), which
add screens and features faster than this app. This file records the last
fusionha commit the app was checked against, so the next catch-up starts there
instead of from scratch.

## Last sync

| | |
|---|---|
| fusionha branch | `main` |
| fusionha commit | `89901fa5` |
| fusionha release | **0.4.202** (2026-10-16, Manual Import: decide one file at a time) |
| Checked on | 2026-10-16 |
| Previous sync | `b3c5ab8d` / 0.4.200 (2026-10-15) |

Since 0.4.201 releases are tagged `v0.4.N`; `frontend/openapi.json` at the tag
is the spec.

`Packages/FusionhaKit/openapi.json` still reports `info.version` 0.2.0: the
catch-ups added models and calls by hand. Re-pin it from a tagged fusionha
release when you next touch the API layer.

## 0.4.201 – 0.4.202 (this sync)

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

Still web-only: Quality Profiles, Quality Definitions, Custom Formats, TRaSH
Guides, Naming, Security, Sign-in methods (server), Plex server, Import
Library (all being ported), plus the setup wizard and docs.

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
