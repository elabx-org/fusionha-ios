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
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            AppSceneContent(model: model) { RootView() }
        }
    }
}
