import SwiftUI
import FusionhaKit

// MARK: - A Discover / Search preview on the Spread's right page (S3)
//
// Discover and Search open a title they don't own as a preview sheet. In a
// Spread the preview goes on the right page instead (`AppModel.spreadPreview`,
// shown by `ShellDetailColumn`), and the tab's grid moves to the left page with
// the title outlined (the owner's mock: "Tap Dune"). Folding, rotating or
// switching to the Web layout hands the open preview back to its tab's sheet,
// and the reverse, so it stays open (DC3). In the Web layout on the open Duo
// the sheet sits on the right page (`duoPageSheet`), never on the fold.

extension AppModel {
    /// The right page holds something: a title or a preview.
    var rightPageHasItem: Bool { presentedItem != nil || spreadPreview != nil }

    /// The Spread ended: a preview its tab didn't take back as a sheet closes.
    func settleSpreadPreview() {
        Task { @MainActor in
            await Task.yield()
            spreadPreview = nil
        }
    }
}

extension View {
    /// A tab's preview sheet that opens on the Spread's right page while a
    /// Spread is on (`tab` owns it; `preview` is the tab's sheet item).
    func spreadPreviewHost(_ tab: AppTab, preview: Binding<PreviewRoute?>,
                           onOpenLibrary: @escaping (Int) -> Void) -> some View {
        modifier(SpreadPreviewHost(tab: tab, preview: preview, onOpenLibrary: onOpenLibrary))
    }
}

private struct SpreadPreviewHost: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    let tab: AppTab
    @Binding var preview: PreviewRoute?
    let onOpenLibrary: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .duoPageSheet(item: spread.isActive ? .constant(nil) : $preview) { route in
                PreviewSheet(route: route, onOpenLibrary: onOpenLibrary)
            }
            .onChange(of: preview, initial: true) { moveToRightPage() }
            .onChange(of: spread.isActive) { _, active in
                if active {
                    moveToRightPage()
                } else if model.tab == tab, let route = model.spreadPreview {
                    // Back to this tab's sheet before the shell closes leftovers.
                    model.spreadPreview = nil
                    preview = route
                }
            }
    }

    private func moveToRightPage() {
        guard spread.isActive, let route = preview else { return }
        preview = nil
        model.spreadPreview = route
    }
}

/// The right page's preview: the same page as the sheet, its ✕ closing the
/// page (the tab spans both pages again), "More like this" pushing within it,
/// and Add / Request opening on the pages, never over the fold.
struct SpreadPreviewColumn: View {
    @Environment(AppModel.self) private var model
    let route: PreviewRoute
    @State private var addPick: MediaSearchResult?
    /// "More like this" pushes: while any are open the edge swipe is the system Back.
    @State private var path: [PreviewRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            PreviewPage(route: route, onAdd: { addPick = $0 }, onOpenLibrary: { model.open($0) },
                        onClose: { model.spreadPreview = nil })
                .duoListToggleToolbar()
                .navigationDestination(for: PreviewRoute.self) { next in
                    PreviewPage(route: next, onAdd: { addPick = $0 }, onOpenLibrary: { model.open($0) })
                }
        }
        .preference(key: DuoPageAtRoot.self, value: path.isEmpty)
        .duoPageSheet(item: $addPick) { pick in
            AddTitleSheet(initialPick: .tmdb(pick), hideViewDetails: true,
                          providerOverride: DiscoverSession.shared.providerOverride) { id in
                model.open(id)
            }
        }
    }
}

extension MediaSearchResult {
    /// The title is open on a Spread's right page (as a preview, or as the
    /// library title it is), so its card is outlined in the grid.
    @MainActor
    func isPicked(in model: AppModel, libraryId: Int?) -> Bool {
        if let open = model.spreadPreview, open == PreviewRoute(self) { return true }
        if let libraryId, model.presentedItem?.id == libraryId { return true }
        return false
    }
}
