import SwiftUI

@main
struct FusionhaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if model.credentials == nil {
                    SignInView()
                } else {
                    RootView()
                }
            }
            .environment(model)
            .tint(Theme.indigo)
        }
    }
}
