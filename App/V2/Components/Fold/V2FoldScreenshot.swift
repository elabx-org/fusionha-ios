import SwiftUI
import FusionhaKit

/// CI shots only (DEBUG), for the fold continuity shots
/// (`scripts/v2_duo_shots.sh`, `fold-*`): `FUSIONHA_SCREENSHOT_DETAIL_TAB`
/// opens the title on a tab and `FUSIONHA_SCREENSHOT_TITLE_PAGE=season:<n>`
/// (or `episode:<season>:<id>`) pushes that page over it, once per launch,
/// so the harness can fold and unfold with it open.
struct V2FoldScreenshot: ViewModifier {
    let store: DetailStore
    @Environment(V2TitleStacks.self) private var stacks: V2TitleStacks?

    func body(content: Content) -> some View {
        #if DEBUG
        content.task(id: store.detail == nil) { seed() }
        #else
        content
        #endif
    }

    #if DEBUG
    @MainActor private static var seeded: Set<Int> = []

    private func seed() {
        let env = ProcessInfo.processInfo.environment
        guard store.detail != nil, env["FUSIONHA_SCREENSHOT_ITEM"].flatMap(Int.init) == store.itemId,
              !Self.seeded.contains(store.itemId) else { return }
        Self.seeded.insert(store.itemId)
        if let tab = env["FUSIONHA_SCREENSHOT_DETAIL_TAB"].flatMap(DetailTab.init(rawValue:)) { store.tab = tab }
        let parts = (env["FUSIONHA_SCREENSHOT_TITLE_PAGE"] ?? "").split(separator: ":").map(String.init)
        switch (parts.first ?? "", parts.count) {
        case ("season", 2): if let n = Int(parts[1]) { stacks?.push(.season(n), on: store.itemId) }
        case ("episode", 3):
            if let n = Int(parts[1]), let id = Int(parts[2]) {
                stacks?.push(.season(n), on: store.itemId)
                stacks?.push(.episode(season: n, episodeId: id), on: store.itemId)
            }
        default: break
        }
    }
    #endif
}
