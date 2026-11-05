import SwiftUI

/// fusionha v2: a second app beside v1 (`docs/v2.md`), with its own bundle id,
/// App Group, keychain namespace and URL scheme (`AppIdentity`, from this
/// target's Info.plist). Built only into the FusionhaV2 target, which leaves out
/// `App/FusionhaApp.swift`; the window content is the same `AppSceneContent`.
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
