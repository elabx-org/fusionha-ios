import SwiftUI

/// The app's window content, shared by v1's `FusionhaApp` and v2's
/// `FusionhaV2App`: the CI screenshot galleries, the sign-in gate, then `root`
/// (the signed-in shell), with the iPhone Duo harness, the window-size and
/// palette roots, deep links and the launch probes around it. Each `@main`
/// passes only its own shell, so both apps keep the same CI and link behaviour.
struct AppSceneContent<Root: View>: View {
    let model: AppModel
    @ViewBuilder let root: () -> Root

    var body: some View {
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
                root()
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
        // missed; the shell applies it once signed in and on screen.
        .onOpenURL { model.receiveDeepLink($0) }
        // The palette (Settings › Appearance): scheme, tint, Automatic.
        .paletteRoot(signedOut: model.credentials == nil)
        .task {
            DeepLinkProbe.log("launched")
            PerfProbe.startIfRequested(model: model)
        }
    }
}
