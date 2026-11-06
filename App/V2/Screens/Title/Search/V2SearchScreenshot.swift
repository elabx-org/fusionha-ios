import SwiftUI
import FusionhaKit

/// CI shots only (DEBUG): `FUSIONHA_SCREENSHOT_AUTOSEARCH=searching` shows the
/// title's automatic search (and a series' Next up episode) running, `=done`
/// their outcomes, without sending a search to the server.
struct V2SearchScreenshot: ViewModifier {
    let store: DetailStore

    func body(content: Content) -> some View {
        #if DEBUG
        content.task(id: store.detail == nil) { seed() }
        #else
        content
        #endif
    }

    #if DEBUG
    private func seed() {
        guard let value = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_AUTOSEARCH"],
              let detail = store.detail, store.searchActivity.entries.isEmpty else { return }
        var targets: [SearchTarget] = [.title]
        if let next = V2TitleNextUp(detail: detail, store: store) { targets.append(.episode(next.episode.id)) }
        for (i, target) in targets.enumerated() {
            guard let token = store.searchActivity.begin(target), value == "done" else { continue }
            store.searchActivity.finish(target, token: token, i == 0 ? .grabbed(1) : .nothingNew)
        }
    }
    #endif
}
