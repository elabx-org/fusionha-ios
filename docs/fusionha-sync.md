# fusionha sync log

The iOS app follows the fusionha server and web app (elabx-org/fusionha), which
add screens and features faster than this app. This file records the last
fusionha commit the app was checked against, so the next catch-up starts there
instead of from scratch.

## Last sync

| | |
|---|---|
| fusionha branch | `main` |
| fusionha commit | `805f5da814abc5fa8ad58b7fdbeee77734a2cd81` |
| fusionha release | **0.4.187** (2026-10-13, "release language rules") |
| Checked on | 2026-10-14 |
| iOS commit after the sync | `9e6db84` (merged to `main`) |
| Source of the catch-up | the 0.4.187 handoff artifact (Claude), plus the fusionha repo at that commit |

`Packages/FusionhaKit/openapi.json` still reports `info.version` 0.2.0: the
catch-up added models and calls by hand (see below). Re-pin it from a tagged
fusionha release when you next touch the API layer.

## What that sync brought in

Done:
- Server times (naive UTC), coded error copy, `X-Next-Cursor` paging
  (`ServerTime`, `ErrorCopy`, `APIClient+Paging`).
- Queue truthfulness rules: phase vs byte mode, staged rail, strict
  `Linking (n/total)`, errors hold at the last stage (`QueueRules`).
- Queue clear / idle summary (`IdleSummary`, `QueueClearView`).
- Held downloads: proven-mislabel copy, release-group evidence, Block release
  group sheet and prompt decisions (`HeldCopy`, `ReleaseGroupModels`,
  `BlockReleaseGroupSheet`).
- Push deep links from web paths (`PushLink`).
- Shared episode codes `S01·E05` / `#28` (`EpisodeCode`).
- Calendar: Agenda default, new codes, rails.

Still open from 0.4.187 (pick these up before newer releases):
- Activity: history lifecycle sheet; optional queue-card fields; the remove
  sheet's three opt-ins.
- Requests and Issues revamp (mocks in `docs/design/redesign/requests.html`).
- Manual Import: native, or keep handing off to the web app (owner to decide).

## How to continue

1. In the fusionha repo: `git log --oneline 805f5da..origin/main` and read the
   release commits (`release: 0.4.x — …`) for new screens, endpoints and copy.
2. Diff the API: `git diff 805f5da..origin/main -- backend/` (routes and
   schemas) and the web client under `frontend/src/` (routes, `lib/api`).
3. Map each new screen or flow onto `docs/ui-plan.md` and build it in the
   redesign (`docs/design/redesign/DIRECTION.md`).
4. When done, update the table above with the new commit, release and date.
