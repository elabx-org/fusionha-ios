import SwiftUI
import FusionhaKit

/// All titles above the grid (mock browse-lib.js): the header
/// (`V2LibraryPageHeader`: title, counts and kind control, then the chip
/// row and its tokens), then the grid's heading with the sort and the
/// grid ⇄ list button, 16 under the chip row. Home's rows (Needs you,
/// Coming up, Recently added) live on Home (`V2HomeView`).
struct V2LibraryPageTop: View {
    let derived: LibraryDerived
    let filters: V2LibraryFilters
    let paneWidth: CGFloat
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("library-top")
            V2LibraryPageHeader(derived: derived, filters: filters, paneWidth: paneWidth)
            if derived.titleCount > 0 {
                V2LibrarySectionHead(title: sectionTitle, count: derived.titleCount, filters: filters)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                    .id("library-grid")
            }
        }
        .animation(motion ? .snappy : nil, value: filters.tokens)
    }

    /// The page is "All titles": the grid's heading names what it holds.
    private var sectionTitle: String {
        if filters.status == .attention { return "Needs attention" }
        return LibraryKind(rawValue: filters.kind)?.plural ?? "Every title"
    }
}
