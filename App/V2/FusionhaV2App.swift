import SwiftUI

/// fusionha's `@main`. Since the cutover (owner, 2026-11-18) the v2 app ships
/// under v1's bundle ids, App Group, keychain group and URL scheme
/// (`docs/v2.md`, Cutover), so it upgrades v1 in place. The window content is
/// `AppSceneContent`.
///
/// v2 supports multiple windows (split screen): the app owns the one
/// `AppSession` (data and pollers), and every window builds its own
/// `AppModel` over it (`V2Window`). "Open in New Window" opens a window
/// for one title (`V2TitleWindow`).
@main
struct FusionhaV2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session: AppSession

    init() {
        #if DEBUG
        // CI's iPhone Duo harness: its launch settings land before any view reads them.
        DuoHarness.prepare()
        #endif
        _session = State(initialValue: AppSession())
    }

    var body: some Scene {
        WindowGroup(for: V2TitleWindow.self) { title in
            V2Window(session: session, title: title.wrappedValue)
        }
    }
}
