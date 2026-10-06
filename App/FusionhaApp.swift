import SwiftUI

@main
struct FusionhaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if let page = WidgetPageGalleryView.screenshotPage {
                    // CI screenshots of one paged-widget view, medium and large.
                    WidgetPageGalleryView(page: page)
                } else if let gallery = WidgetGalleryView.screenshotVariant {
                    // CI screenshots of the home-screen widgets.
                    WidgetGalleryView(variant: gallery)
                } else if model.credentials == nil {
                    SignInView()
                } else {
                    RootView()
                }
            }
            .environment(model)
            .tint(Theme.indigo)
            // fusionha's web app is dark-only; match it.
            .preferredColorScheme(.dark)
            .task { PerfProbe.startIfRequested(model: model) }
        }
    }
}
