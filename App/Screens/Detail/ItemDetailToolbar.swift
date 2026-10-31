import SwiftUI
import FusionhaKit

/// The title page's bar, in the sheet and the shell's column alike (D2):
/// Close · Search all (the one prominent action) · Refresh · More (⋯). On the
/// folded Duo it is the system column in that order (`docs/ui-plan.md`).
///
/// Every item runs an action the page itself already has: Search all is the
/// Versions panel's, Preview rename and Delete are the item actions rail's,
/// and the sheets they open are the store's (`DetailChildSheets`), so the
/// bar and the rail show the same dialog. The rail stays as it is (web parity).
struct ItemDetailToolbar: ToolbarContent {
    let store: DetailStore
    let canEdit: Bool
    let canSearch: Bool
    let escapeCloses: Bool
    let close: () -> Void
    let openWeb: () -> Void

    private var detail: ItemDetail? { store.detail }
    private var searching: Bool { store.flash?.phase == .searching }

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: "Close detail", escapeCloses: escapeCloses, action: close)
        }
        if canSearch, let detail {
            ToolbarItem(placement: .topBarTrailing) {
                // The Versions panel's "Search all": every monitored version.
                ToolbarActionButton(title: "Search all", systemImage: "magnifyingglass", busy: searching) {
                    Task { await store.search(label: "\(detail.title) — all monitored versions") }
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.i1)
                .accessibilityHint("Search all monitored versions")
            }
            .barPriority(true)
        }
        ToolbarItem(placement: .topBarTrailing) {
            // Reloads this page: the rail's Refresh metadata asks the server.
            Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.load() } }
        }
        .barPriority(false)
        ToolbarItem(placement: .topBarTrailing) { moreMenu }
            .barPriority(false)
    }

    private var moreMenu: some View {
        Menu {
            Button("Open in the web app", systemImage: "safari", action: openWeb)
            if let detail {
                if canSearch {
                    Button("Interactive search", systemImage: "person") { store.openInteractiveSearch() }
                }
                if canEdit {
                    Button(ItemAction.previewRename.label(isSeries: detail.isSeries),
                           systemImage: ItemActionsRail.symbol(.previewRename)) { store.openRename() }
                    Divider()
                    Button(ItemAction.delete.label(isSeries: detail.isSeries), systemImage: "trash", role: .destructive) {
                        store.showingDelete = true
                    }
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }
}
