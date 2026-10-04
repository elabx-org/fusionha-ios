# fusionha for iOS

A native SwiftUI client for [fusionha](https://github.com/elabx-org/fusionha), built for
iOS 26 with Liquid Glass, widgets and Live Activities.

> Early days: sign-in, Library, item detail, the download queue, a two-week calendar,
> Wanted counts, a Downloads widget and a Downloads Live Activity. The full plan is in
> [`docs/ui-plan.md`](docs/ui-plan.md).

## Install

1. Download `Fusionha.ipa` from the latest [release](../../releases) (or the
   `Fusionha-unsigned-ipa` artifact of a CI run).
2. Sideload it with Feather (or similar), signing with your own Apple Developer certificate.
3. Open the app, enter your fusionha server address and sign in. The app creates a
   personal API token for this device; revoke it any time from fusionha's settings.

Push notifications, widgets and Live Activities need a certificate and profiles that
include the **Push Notifications** capability and the `group.org.elabx.fusionha` App
Group for `org.elabx.fusionha`, `org.elabx.fusionha.widgets` and
`org.elabx.fusionha.notification-service`. Don't let the signing tool change bundle IDs.

## Develop

No Mac needed: every push builds on GitHub Actions. With a Mac:

```sh
brew install xcodegen
xcodegen generate
open Fusionha.xcodeproj
```

Run the API package tests with `swift test --package-path Packages/FusionhaKit`.
