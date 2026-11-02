import SwiftUI
import FusionhaKit

/// The title page's bar, in the sheet and the shell's column alike (D2):
/// Close · Search all (the one prominent action) · Refresh · More (⋯). On the
/// folded Duo it is the system column in that order (`docs/ui-plan.md`).
///
/// Every item runs an action the page itself already has: Search all is the
/// Versions panel's, the More items are the item actions rail's, and the
/// sheets they open are the store's (`DetailChildSheets`), so the bar and the
/// rail show the same dialog. The rail stays as it is (web parity) except on
/// the folded Duo / phone, where More carries it (`ItemDetailMoreMenu`).
struct ItemDetailToolbar: ToolbarContent {
    let store: DetailStore
    let canEdit: Bool
    let canSearch: Bool
    /// The folded Duo / phone layout: More carries the item actions.
    let compact: Bool
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
        ToolbarItem(placement: .topBarTrailing) {
            ItemDetailMoreMenu(store: store, canEdit: canEdit, canSearch: canSearch, compact: compact, openWeb: openWeb)
        }
        .barPriority(false)
    }
}
