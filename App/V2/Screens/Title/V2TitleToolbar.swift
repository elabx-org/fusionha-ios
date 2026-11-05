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
    let close: () -> Void
    let openWeb: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCancelButton(title: "Close", escapeCloses: escapeCloses, action: close)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            ToolbarActionButton(title: "Refresh", systemImage: "arrow.clockwise", busy: store.refreshing) {
                Task { await store.load() }
            }
            if canEdit && store.detail != nil {
                Button("Edit", systemImage: "pencil") { store.showingEdit = true }
            }
            ItemDetailMoreMenu(store: store, canEdit: canEdit, canSearch: canSearch, compact: true, openWeb: openWeb)
        }
    }
}

/// The page's toast, over the foot of the page (v1's `DetailPageChrome`).
struct V2TitleToast: View {
    let store: DetailStore
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            if let toast = store.toast {
                DetailToastView(toast: toast) { store.toast = nil }
                    .padding(.bottom, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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
