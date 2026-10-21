import SwiftUI

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
            Group {
                if let page = WidgetPageGalleryView.screenshotPage {
                    // CI screenshots of one paged-widget view, medium and large.
                    WidgetPageGalleryView(page: page)
                } else if let stack = WidgetStackGalleryView.screenshotVariant {
                    // CI screenshots of one Smart Stack widget, every size.
                    WidgetStackGalleryView(variant: stack)
                } else if let gallery = WidgetGalleryView.screenshotVariant {
                    // CI screenshots of the home-screen widgets.
                    WidgetGalleryView(variant: gallery)
                } else if model.credentials == nil {
                    SignInView()
                } else {
                    RootView()
                }
            }
            // CI screenshots only: the app inside an iPhone Duo frame with a fake fold.
            .duoHarness()
            .environment(model)
            .publishesWindowSize()
            // A native app shows no scroll bars: every page, list and sheet
            // below inherits it (the Library keeps its own A–Z scrubber).
            .scrollIndicators(.hidden)
            // At the root, so a link that cold-launches the app is never
            // missed; RootView applies it once signed in and on screen.
            .onOpenURL { model.receiveDeepLink($0) }
            // The palette (Settings › Appearance): scheme, tint, Automatic.
            .paletteRoot(signedOut: model.credentials == nil)
            .task {
                DeepLinkProbe.log("launched")
                PerfProbe.startIfRequested(model: model)
            }
        }
    }
}
