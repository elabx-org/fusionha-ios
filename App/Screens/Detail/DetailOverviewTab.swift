import SwiftUI
import FusionhaKit

/// The Overview tab (D5, the web's `DetailOverview` at the tail of a library
/// title's tabs): the trailer, collection, more like this and cast rails
/// (`DetailRailStack`), or a quiet empty box when the title has none.
struct DetailOverviewTab: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail

    private var isEmpty: Bool {
        (detail.trailerKey ?? "").isEmpty
            && (detail.similar ?? []).isEmpty
            && (detail.cast ?? []).isEmpty
            && (detail.collection == nil || store.collection == nil)
    }

    var body: some View {
        if isEmpty {
            EmptyBox(message: "No trailer, cast or similar titles for this one yet.")
        } else {
            // The pane already sits 20pt under the tab row: the first rail's
            // section heading drops its own top gap.
            DetailRailStack(detail: detail)
                .padding(.top, -20)
        }
    }
}
