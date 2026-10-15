# fusionha sync log

The iOS app follows the fusionha server and web app (elabx-org/fusionha), which
add screens and features faster than this app. This file records the last
fusionha commit the app was checked against, so the next catch-up starts there
instead of from scratch.

## Last sync

| | |
|---|---|
| fusionha branch | `main` |
| fusionha commit | `16635380` |
| fusionha release | **0.4.198** (2026-10-15, "queue action rows") |
| Checked on | 2026-10-15 |
| Previous sync | `818b8b7f` / 0.4.196 (2026-10-14) |

`Packages/FusionhaKit/openapi.json` still reports `info.version` 0.2.0: the
catch-ups added models and calls by hand. Re-pin it from a tagged fusionha
release when you next touch the API layer.

## 0.4.197 – 0.4.198 (this sync)

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

## How to continue

1. In the fusionha repo: `git log --first-parent --oneline 299b0251..origin/main` and read the
   release commits (`release: 0.4.x — …`) for new screens, endpoints and copy.
2. Diff the API: `git diff 299b0251 origin/main -- backend/` (routes and
   schemas) and the web client under `frontend/src/` (routes, `lib/api`).
3. Map each new screen or flow onto `docs/ui-plan.md` and build it in the
   redesign (`docs/design/redesign/DIRECTION.md`).
4. When done, update the table above with the new commit, release and date.
