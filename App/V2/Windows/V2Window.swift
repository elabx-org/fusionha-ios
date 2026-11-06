import SwiftUI
import FusionhaKit

/// One v2 window. v2 runs in several windows (the system split screen on
/// the open iPhone Duo and iPad-class multitasking), so each window has its
/// own `AppModel`: its tab, navigation, open title, sheets, selection and
/// toasts. They all sit on the app's one `AppSession` (the sign-in, library,
/// queue, shell and the pollers), so two windows never poll twice.
///
/// A window opened with "Open in New Window" carries a `V2TitleWindow` and
/// opens that title once (`openedTitle` remembers it across restoration, so
/// a title closed by hand stays closed).
struct V2Window: View {
    let title: V2TitleWindow?
    @State private var model: AppModel
    @SceneStorage("v2.window.openedTitle") private var openedTitle = 0

    init(session: AppSession, title: V2TitleWindow?) {
        self.title = title
        _model = State(initialValue: AppModel(session: session))
    }

    var body: some View {
        AppSceneContent(model: model) { V2RootView() }
            .modifier(V2KeyWindowTracker(model: model))
            // Signing out in one window signs out all of them: each resets its own screens.
            .onChange(of: model.credentials == nil) { _, signedOut in
                if signedOut { model.resetUI() }
            }
            .task(id: title) { openTitle() }
            // Which events an open window takes (its scene's activation
            // conditions). It prefers the app's own links (widget, Live
            // Activity, push: `AppSession.routeLink` then picks the window)
            // and allows anything else, including a plain launch from the
            // Home Screen icon. Allowing only the links made every icon tap
            // match no open window, so the system opened a new one each time.
            .handlesExternalEvents(preferring: Self.ownLinks, allowing: ["*"])
            #if DEBUG
            .modifier(V2SceneProbe())
            #endif
    }

    private static let ownLinks: Set<String> = ["\(AppIdentity.current.urlScheme)://"]

    /// The title this window was opened for, through the deep-link path so
    /// it waits for the sign-in and the shell like any other link.
    private func openTitle() {
        guard let id = title?.itemId, id != openedTitle, let url = WidgetLink.item(id) else { return }
        openedTitle = id
        model.receiveDeepLink(url)
    }
}
