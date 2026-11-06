import SwiftUI
import FusionhaKit

/// The title's release-group sheets (a sheet folded, a page cover on the
/// open Duo): Release groups from More, and "Block <GROUP>?" from a Files
/// or History row. Loads the blocks that apply here once the title is in,
/// so rows know which groups are blocked.
struct V2TitleGroupSheets: ViewModifier {
    @Environment(AppModel.self) private var model
    let presenter: DetailPresenter
    private var store: DetailStore { presenter.store }

    func body(content: Content) -> some View {
        content
            .duoPageSheet(isPresented: presenter.flag(\.showingReleaseGroups)) {
                if let detail = store.detail {
                    V2ReleaseGroupsSheet(detail: detail)
                        .environment(store)
                }
            }
            .duoPageSheet(item: presenter.item(\.blockGroup)) { target in
                V2BlockGroupSheet(target: target, title: store.detail?.title ?? "this title")
                    .environment(store)
            }
            .task(id: store.detail == nil) {
                guard store.detail != nil, model.mayBlockGroups, store.groupBlocks == nil else { return }
                await store.loadGroupBlocks()
                screenshotSheet()
            }
    }

    /// CI shots: `FUSIONHA_SCREENSHOT_GROUPS=list` opens Release groups,
    /// `=search` the interactive search (its blocked rows), `=<group>` the
    /// block sheet for that group.
    private func screenshotSheet() {
        #if DEBUG
        guard let value = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_GROUPS"] else { return }
        switch value {
        case "list": store.showingReleaseGroups = true
        case "search": store.openInteractiveSearch()
        default: store.blockGroup = GroupBlockTarget(group: value)
        }
        #endif
    }
}
