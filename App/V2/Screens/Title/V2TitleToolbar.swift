import SwiftUI
import FusionhaKit

/// The v2 title bar (mock `cbar`): Back / Close on the leading side, then
/// one glass capsule of Refresh, Edit (pencil) and More. More is v1's menu
/// in its compact form, so it carries every item action, Interactive
/// search, Open in the web app and Delete through the same store entry
/// points (`ItemDetailMoreMenu`).
struct V2TitleToolbar: ToolbarContent {
    let store: DetailStore
    let canEdit: Bool
    let canSearch: Bool
    let escapeCloses: Bool
    /// Collapsed tabs on the Duo (the column rule): only Close stays in the
    /// column; Refresh, Edit and More are in the arrow's list
    /// (`V2TitleView.columnItems`). Owner, build 1132: five buttons ran down
    /// over the tabs and covered the episodes' badges.
    var collapsed = false
    let close: () -> Void
    let openWeb: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: "Close", escapeCloses: escapeCloses, action: close)
        }
        if !collapsed {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ToolbarActionButton(title: "Refresh", systemImage: "arrow.clockwise", busy: store.refreshing) {
                    Task { await store.load() }
                }
                // There from the first frame (disabled until the title loads):
                // a bar whose items change as it loads is rebuilt, and on the
                // open Duo it showed in the page until the system column took it
                // again (owner, build 805).
                if canEdit {
                    Button("Edit", systemImage: "pencil") { store.showingEdit = true }
                        .disabled(store.detail == nil)
                }
                ItemDetailMoreMenu(store: store, canEdit: canEdit, canSearch: canSearch, compact: true, openWeb: openWeb)
            }
        }
    }
}

/// The page's toast, at the top of the page (v1's `DetailPageChrome`).
struct V2TitleToast: View {
    let store: DetailStore
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            if let toast = store.toast {
                DetailToastView(toast: toast) { store.toast = nil }
                    .padding(.top, 8)
                    .transition(.glassToast(reduceMotion: reduceMotion))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(toast.action == nil ? 3.5 : 6))
                        if store.toast?.id == toast.id { store.toast = nil }
                    }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: store.toast)
    }
}
