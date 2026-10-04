# CLAUDE.md — fusionha-ios

Native iOS client for [fusionha](https://github.com/elabx-org/fusionha), the self-hosted
Sonarr + Radarr replacement. The server repo owns the product rules (multi-quality
editions, anime first-class, arr emulation); this repo owns how they look on iOS.

## Rules

- **SwiftUI, iOS/iPadOS 26+.** UIKit only where SwiftUI has no API (the push app delegate).
- **Stay close to the web app.** Same destinations, screens, flows and words as fusionha's
  mobile web layout. The screen-by-screen mapping lives in the UI plan
  (`docs/ui-plan.md`); follow it, and update it when a screen deviates.
- **Liquid Glass on controls, never on content.** Tab bar, toolbars, filter chips,
  segmented pickers, bulk-action bar, sheets and the downloads accessory are glass.
  Posters, edition cards and rows are solid content. Posters stay clean (no text on art).
- **Native controls are the point.** The web's "no native form controls" rule is a
  browser rule and does NOT apply here: use `Picker`, `Toggle`, `Menu`, `Form`.
- **Multi-edition state is always visible.** Every card, row and widget shows its
  HD/4K edition chips, coloured through `EditionStatus.color` (mirrors the web's
  `status.ts`). HD chip = purple, 4K chip = cyan.
- **Icons:** Monitor = `bookmark`/`bookmark.fill` (never a checkmark) · automatic search =
  `magnifyingglass` · interactive search = `person` · edit = `pencil` · refresh =
  `arrow.clockwise` · delete = `trash`.
- **Motion respects Reduce Motion.** Prefer system transitions (zoom, symbol effects).

## Layout

- `project.yml` — XcodeGen spec. The `.xcodeproj` is generated and git-ignored; never hand-edit it.
- `App/` app target · `Widgets/` widgets + Live Activity · `NotificationService/` rich push ·
  `Shared/` code compiled into the app and widgets (theme, Live Activity attributes).
- `Packages/FusionhaKit/` — Foundation-only API client, models and credential store.
  `openapi.json` is pinned from a tagged fusionha release; update it deliberately.

## Build

There is no local Mac. CI (`.github/workflows/build.yml`) runs `swift test` on FusionhaKit,
generates the project with XcodeGen and builds an **unsigned IPA**. It is installed by
sideloading with Feather, signed on-device with the owner's paid certificate.
Every push to `main` publishes a `build-N` GitHub release with the IPA and an AltStore-format
`source.json` (`scripts/make_source.py`); Feather's source URL is
`https://github.com/elabx-org/fusionha-ios/releases/latest/download/source.json`.

- Keep bundle IDs stable (`org.elabx.fusionha`, `.widgets`, `.notification-service`) and
  the App Group `group.org.elabx.fusionha`: push and widget sign-in depend on them.
- The API token is stored in the Keychain with the App Group as access group (no team
  prefix), so it survives re-signing with any team.

## API notes

- Auth: `POST /api/v1/auth/login` (session cookie) → `POST /api/v1/tokens` mints a
  per-device token → every call sends `X-Api-Key`.
- The decision-engine search is `POST /library/{id}/search` — **no** `/api/v1` prefix.
- No live stream on the server: poll `GET /api/v1/queue`.
- Edition statuses on the wire are `done` / `grabbing` / `wanted` / `upgrading`.
