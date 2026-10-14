# fusionha sync log

The iOS app follows the fusionha server and web app (elabx-org/fusionha), which
add screens and features faster than this app. This file records the last
fusionha commit the app was checked against, so the next catch-up starts there
instead of from scratch.

## Last sync

| | |
|---|---|
| fusionha branch | `main` |
| fusionha commit | `50d785bb` |
| fusionha release | **0.4.190** (2026-10-14, "Manual Import keep current") |
| Checked on | 2026-10-14 |
| Previous sync | `805f5da` / 0.4.187 (2026-10-13) |

`Packages/FusionhaKit/openapi.json` still reports `info.version` 0.2.0: the
catch-ups added models and calls by hand. Re-pin it from a tagged fusionha
release when you next touch the API layer.

## 0.4.188 – 0.4.190 (this sync)

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
- Manual Import native (the web flow opens signed in meanwhile).

## How to continue

1. In the fusionha repo: `git log --first-parent --oneline 50d785bb..origin/main` and read the
   release commits (`release: 0.4.x — …`) for new screens, endpoints and copy.
2. Diff the API: `git diff 50d785bb origin/main -- backend/` (routes and
   schemas) and the web client under `frontend/src/` (routes, `lib/api`).
3. Map each new screen or flow onto `docs/ui-plan.md` and build it in the
   redesign (`docs/design/redesign/DIRECTION.md`).
4. When done, update the table above with the new commit, release and date.
