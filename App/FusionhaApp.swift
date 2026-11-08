import SwiftUI

/// fusionha (v1). v2's `@main` is `App/V2/FusionhaV2App.swift`, built only
/// into the FusionhaV2 target; both share `AppSceneContent`.
@main
struct FusionhaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel

    init() {
        #if DEBUG
        // CI's iPhone Duo harness: its launch settings land before any view reads them.
        DuoHarness.prepare()
        #endif
        // One window: one session (the app's data and pollers) and its one model.
        _model = State(initialValue: AppModel(session: AppSession()))
    }

    var body: some Scene {
        WindowGroup {
            AppSceneContent(model: model) { RootView() }
                // A sign-out the server caused (a 401) resets the screens too.
                .onChange(of: model.credentials == nil) { _, signedOut in
                    if signedOut { model.resetUI() }
                }
        }
    }
}
