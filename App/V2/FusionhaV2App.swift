import SwiftUI

/// fusionha v2: a second app beside v1 (`docs/v2.md`), with its own bundle id,
/// App Group, keychain namespace and URL scheme (`AppIdentity`, from this
/// target's Info.plist). Built only into the FusionhaV2 target, which leaves out
/// `App/FusionhaApp.swift`; the window content is the same `AppSceneContent`.
@main
struct FusionhaV2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        #if DEBUG
        // CI's iPhone Duo harness: its launch settings land before any view reads them.
        DuoHarness.prepare()
        #endif
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            AppSceneContent(model: model) { V2RootView() }
        }
    }
}
