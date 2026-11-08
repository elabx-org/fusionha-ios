import SwiftUI
import FusionhaKit

/// All titles above the grid (mock browse-lib.js): the header
/// (`V2LibraryPageHeader`: title, counts and kind control, then the chip
/// row and its tokens), the wanted shelves (`V2WantedShelves`), then the
/// grid's heading with the sort and the grid ⇄ list button, 16 under the
/// chip row (or the last shelf). Home's rows (Needs you,
/// Coming up, Recently added) live on Home (`V2HomeView`).
struct V2LibraryPageTop: View {
    let derived: LibraryDerived
    let filters: V2LibraryFilters
    let paneWidth: CGFloat
    @Environment(\.motionEnabled) private var motion
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("library-top")
            V2LibraryPageHeader(derived: derived, filters: filters, paneWidth: paneWidth)
            V2WantedShelves(kind: filters.kind, gutter: paneWidth >= 700 ? 24 : 20, hidden: hidesShelves)
            if derived.titleCount > 0 {
                V2LibrarySectionHead(title: sectionTitle, count: derived.titleCount, filters: filters)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                    .id("library-grid")
            }
        }
        .animation(motion ? .snappy : nil, value: filters.tokens)
    }

    /// The wanted shelves step aside while the grid is being searched or
    /// selected from.
    private var hidesShelves: Bool {
        model.selectMode || !model.searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The page is "All titles": the grid's heading names what it holds.
    private var sectionTitle: String {
        if filters.status == .attention { return "Needs attention" }
        return LibraryKind(rawValue: filters.kind)?.plural ?? "Every title"
    }
}
