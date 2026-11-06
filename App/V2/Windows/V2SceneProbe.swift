#if DEBUG
import SwiftUI
import UIKit

/// CI only (DEBUG, `FUSIONHA_SCENE_PROBE`): logs how many scenes the app has
/// connected each time a window comes to the foreground, so
/// scripts/v2_scene_check.sh can prove that launching the app again from the
/// Home Screen returns to its window instead of opening another one.
/// With `FUSIONHA_SCENE_PROBE_NEW_WINDOW` the first window also runs "Open in
/// New Window" once, which must still add a window.
struct V2SceneProbe: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @Environment(\.openWindow) private var openWindow
    private static let env = ProcessInfo.processInfo.environment
    @MainActor private static var openedNewWindow = false

    func body(content: Content) -> some View {
        if Self.env["FUSIONHA_SCENE_PROBE"] != nil {
            content
                .onChange(of: phase, initial: true) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        // Let a scene the system is still connecting show up.
                        try? await Task.sleep(for: .seconds(1))
                        Self.logScenes()
                    }
                }
                .task { await openNewWindowOnce() }
        } else {
            content
        }
    }

    private func openNewWindowOnce() async {
        guard Self.env["FUSIONHA_SCENE_PROBE_NEW_WINDOW"] != nil, !Self.openedNewWindow else { return }
        Self.openedNewWindow = true
        try? await Task.sleep(for: .seconds(4))
        DeepLinkProbe.log("open new window")
        openWindow(value: V2TitleWindow(itemId: 1))
    }

    @MainActor private static func logScenes() {
        let app = UIApplication.shared
        let states = app.connectedScenes.map { "\($0.activationState.rawValue)" }.sorted().joined(separator: ",")
        DeepLinkProbe.log("scenes \(app.connectedScenes.count) sessions \(app.openSessions.count) states \(states)")
    }
}
#endif
