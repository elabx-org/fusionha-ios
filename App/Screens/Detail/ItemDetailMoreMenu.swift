import SwiftUI
import FusionhaKit

/// The title bar's More (⋯) menu. Wide (open Duo, iPad): Open in the web app,
/// Interactive search, Preview rename and Delete, the rail carrying the rest
/// (web parity). Folded Duo / phone (`detailCompact`): the rail is gone, so
/// the menu carries every item action through the same store entry points
/// (`DetailStore.perform`), then Interactive search, Open in the web app and
/// Delete.
struct ItemDetailMoreMenu: View {
    let store: DetailStore
    let canEdit: Bool
    let canSearch: Bool
    let compact: Bool
    let openWeb: () -> Void

    /// The menu's order on the folded Duo; `ItemAction.rail` gates which show.
    private static let order: [ItemAction] = [.refresh, .previewRename, .manageEpisodes, .manageFiles,
                                              .checkNumbering, .reportIssue, .editionAliases, .edit]

    var body: some View {
        Menu {
            if let detail = store.detail {
                if compact {
                    actionItems(detail)
                    Divider()
                    searchItem
                    Button("Open in the web app", systemImage: "safari", action: openWeb)
                    #if V2
                    // v2's title page (compact More): this title in a window of its own.
                    OpenInNewWindowButton(itemId: store.itemId)
                    #endif
                } else {
                    Button("Open in the web app", systemImage: "safari", action: openWeb)
                    searchItem
                    if canEdit {
                        Button(ItemAction.previewRename.label(isSeries: detail.isSeries),
                               systemImage: ItemActionsRail.symbol(.previewRename)) { store.openRename() }
                    }
                }
                if canEdit {
                    Divider()
                    Button(ItemAction.delete.label(isSeries: detail.isSeries), systemImage: "trash", role: .destructive) {
                        store.showingDelete = true
                    }
                }
            } else {
                Button("Open in the web app", systemImage: "safari", action: openWeb)
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    @ViewBuilder
    private var searchItem: some View {
        if canSearch {
            Button("Interactive search", systemImage: "person") { store.openInteractiveSearch() }
        }
    }

    @ViewBuilder
    private func actionItems(_ detail: ItemDetail) -> some View {
        let allowed = Set(ItemAction.rail(isSeries: detail.isSeries, canEdit: canEdit,
                                          hasNonStandardEdition: detail.hasVersions))
        let actions = Self.order.filter { allowed.contains($0) }
        let flagged = detail.numberingMismatch == true
        ForEach(actions, id: \.self) { action in
            Button(action.label(isSeries: detail.isSeries, numberingFlagged: flagged),
                   systemImage: ItemActionsRail.symbol(action)) { store.perform(action) }
                .disabled(busy(action))
            if action == .refresh {
                Button("Refresh & scan files", systemImage: "list.bullet.rectangle") {
                    Task { await store.refresh(metadataOnly: false) }
                }
                .disabled(store.refreshing)
            }
        }
    }

    private func busy(_ action: ItemAction) -> Bool {
        switch action {
        case .refresh: return store.refreshing
        case .checkNumbering: return store.checkingNumbering
        default: return false
        }
    }
}
