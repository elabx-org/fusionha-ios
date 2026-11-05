import SwiftUI
import FusionhaKit

/// The v2 Library above the grid (mocks browse.js home 'live', browse-lib.js):
/// the header (`V2LibraryPageHeader`: title, counts and kind control, then
/// the chip row and its tokens), the Needs-attention row, the "Coming up"
/// row (`V2ComingUpRow`), the poster shelf, then "All titles". The first
/// of those sits 16 under the chip row.
struct V2LibraryPageTop: View {
    let derived: LibraryDerived
    let home: V2LibraryHome
    let held: Set<Int>
    let filters: V2LibraryFilters
    let paneWidth: CGFloat
    /// The grid's poster width and gap: the shelf's posters match them.
    let gridPoster: (width: CGFloat, gap: CGFloat)?
    /// The page's side gutter.
    let gutter: CGFloat
    /// The hero and shelf show (posters, no search words).
    let showsHome: Bool
    @Binding var shelf: V2LibraryShelfSource
    /// The Coming up row's lead art, for the page's ground.
    @Binding var comingUpArt: URL?
    /// Scrolls to the "All titles" heading.
    let toGrid: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    /// The Coming up row is showing Recently added (nothing in the window).
    @State private var comingUpFallingBack = false

    private var showsAttention: Bool { !home.attention.isEmpty && filters.status != .attention }
    /// Something sits between the chip row and "All titles".
    private var showsModules: Bool {
        showsAttention || (showsHome && (!home.heroes.isEmpty || shelfSource != nil))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("library-top")
            V2LibraryPageHeader(derived: derived, filters: filters, paneWidth: paneWidth)
            if showsAttention {
                V2NeedsAttentionRow(items: home.attention, held: held) { see(.needsYou) }
                    .padding(.top, Self.firstGap)
                    .reveal(2)
            }
            if showsHome && !home.heroes.isEmpty {
                V2ComingUpRow(visibleIds: derived.visibleIds, recent: home.shelves[.recentlyAdded] ?? [],
                              width: paneWidth, gutter: gutter, leadArt: $comingUpArt,
                              fallingBack: $comingUpFallingBack)
                    .padding(.top, gap(after: showsAttention))
                    .reveal(3)
            }
            if showsHome, let shelfSource {
                V2LibraryShelf(home: home, source: shelfSource, paneWidth: paneWidth,
                               gridPoster: gridPoster) { see($0) }
                    // The carousel's frame keeps 24 for its shadow: 16 under the cards.
                    .padding(.top, showsHome && !home.heroes.isEmpty ? -8 : gap(after: showsAttention))
                    .reveal(4)
            }
            if derived.titleCount > 0 {
                V2LibrarySectionHead(title: filters.status == .attention ? "Needs attention" : "All titles",
                                     count: derived.titleCount, filters: filters)
                    .padding(.top, gap(after: showsModules))
                    .padding(.bottom, 6)
                    .id("library-grid")
            }
        }
        .animation(motion ? .snappy : nil, value: filters.tokens)
    }

    /// The shelf's source. While the Coming up row falls back to Recently
    /// added, a shelf on Recently added shows the next source with titles
    /// instead (the stored choice stays), or hides when there is none.
    private var shelfSource: Binding<V2LibraryShelfSource>? {
        let sources = home.sources
        guard !sources.isEmpty else { return nil }
        let rowShowsRecent = comingUpFallingBack && !home.heroes.isEmpty
        let shown = sources.contains(shelf) ? shelf : sources[0]
        guard rowShowsRecent && shown == .recentlyAdded else { return $shelf }
        guard let other = sources.first(where: { $0 != .recentlyAdded }) else { return nil }
        return Binding(get: { other }, set: { shelf = $0 })
    }

    /// The chip row to the first module: 16 (mock); between modules, 20.
    private static let firstGap: CGFloat = 16

    private func gap(after module: Bool) -> CGFloat { module ? 20 : Self.firstGap }

    /// A shelf's "See all" (and the attention row's Show all): the grid
    /// takes that shelf's filter and sort, and the page scrolls to it.
    private func see(_ source: V2LibraryShelfSource) {
        withAnimation(motion ? .smooth(duration: 0.3) : nil) {
            filters.status = source.seeAll.status
            filters.sort = source.seeAll.sort
        }
        toGrid()
    }
}
