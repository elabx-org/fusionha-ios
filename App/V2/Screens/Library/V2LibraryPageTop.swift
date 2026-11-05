import SwiftUI
import FusionhaKit

/// The v2 Library above the grid (mocks browse.js home, browse-lib.js and
/// filters-alt.js F1): the stats line, the library filter, the kind control
/// with its make-up bar, the F1 row and its tokens, the Needs-attention
/// row, the hero carousel, the poster shelf, then "All titles". Flat open,
/// the kind control and the F1 row share one line and the rails simply run
/// wider; in book pose that line splits at the fold.
struct V2LibraryPageTop: View {
    let derived: LibraryDerived
    let home: V2LibraryHome
    let held: Set<Int>
    let filters: V2LibraryFilters
    let paneWidth: CGFloat
    /// The page's side gutter.
    let gutter: CGFloat
    /// The hero and shelf show (posters, no search words).
    let showsHome: Bool
    @Binding var shelf: V2LibraryShelfSource
    /// Scrolls to the "All titles" heading.
    let toGrid: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.bookPose) private var bookPose
    @Environment(\.pagePalette) private var page
    @State private var kindCountsInSummary = false

    private var wideRow: Bool { paneWidth >= 700 }
    private var showsAttention: Bool { !home.attention.isEmpty && filters.status != .attention }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("library-top")
            titleRow
                .reveal(0)
            controls
                .padding(.top, 12)
                .reveal(1)
            V2LibraryFilterTokens(filters: filters)
                .padding(.top, filters.tokens.isEmpty ? 0 : 10)
            if showsAttention {
                V2NeedsAttentionRow(items: home.attention, held: held) { see(.needsYou) }
                    .padding(.top, 18)
                    .reveal(2)
            }
            if showsHome && !home.heroes.isEmpty {
                V2LibraryHeroCarousel(items: home.heroes, width: paneWidth, gutter: gutter)
                    .padding(.top, 20)
                    .reveal(3)
            }
            if showsHome && !home.sources.isEmpty {
                V2LibraryShelf(home: home, source: $shelf, paneWidth: paneWidth) { see($0) }
                    // The carousel's frame keeps 24 for its shadow: 16 under the cards.
                    .padding(.top, showsHome && !home.heroes.isEmpty ? -8 : 20)
                    .reveal(4)
            }
            if derived.titleCount > 0 {
                V2LibrarySectionHead(title: filters.status == .attention ? "Needs attention" : "All titles",
                                     count: derived.titleCount, filters: filters)
                    .padding(.top, 20)
                    .padding(.bottom, 6)
                    .id("library-grid")
            }
        }
        .animation(motion ? .snappy : nil, value: filters.tokens)
    }

    /// The stats line, then the library filter. Flat open (mock libInner)
    /// they share one line, the field 360 wide at the trailing end.
    @ViewBuilder
    private var titleRow: some View {
        let stats = V2LibraryStatsLine(derived: derived, kind: filters.kind)
        if wideRow && !bookPose {
            HStack(alignment: .center, spacing: 14) {
                stats
                Spacer(minLength: 0)
                LibraryFilterField(shown: .constant(false))
                    .frame(width: 360)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                stats
                LibraryFilterField(shown: .constant(false))
                    .frame(maxWidth: wideRow ? 420 : .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        let kinds = LibraryKindSegment(derived: derived, kind: filters.$kind, countsInSummary: $kindCountsInSummary)
        let row = V2LibraryFilterRow(filters: filters, attentionCount: derived.attentionCount)
        if wideRow && bookPose {
            FoldSpanRow(trailingAlignment: .center) { kinds } trailing: { row }
        } else if wideRow {
            HStack(alignment: .center, spacing: 14) {
                kinds.frame(width: 384)
                row
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                kinds
                row
            }
        }
    }

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

/// The line under the bar's title (browse-lib.js `statsLine`): "843 titles ·
/// 4,927 versions", "312 movies · 181 in 4K" or "96 anime · 40 animation",
/// then the downloads in the accent, linked to Activity.
struct V2LibraryStatsLine: View {
    let derived: LibraryDerived
    let kind: String
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    private var noun: String {
        let n = derived.titleCount
        guard let k = LibraryKind(rawValue: kind) else { return n == 1 ? "title" : "titles" }
        return n == 1 && k != .series && k != .anime && k != .animation ? String(k.plural.lowercased().dropLast())
            : k.plural.lowercased()
    }

    private var summary: String {
        let t = derived.titleCount.formatted()
        switch LibraryKind(rawValue: kind) {
        case .movie?:
            return "\(t) \(noun) · \(derived.pulse.fourKTitles.formatted()) in 4K"
        case .anime?:
            return "\(t) \(noun) · \((derived.kindTitles[.animation] ?? 0).formatted()) animation"
        default:
            let e = derived.editionCount
            return "\(t) \(noun) · \(e.formatted()) \(e == 1 ? "version" : "versions")"
        }
    }

    var body: some View {
        let downloading = derived.pulse.titleCounts[.downloading] ?? 0
        HStack(spacing: 0) {
            Text(summary)
                .contentTransition(.numericText())
            if downloading > 0 {
                Text(verbatim: " · ")
                Button { model.tab = .activity } label: {
                    Text("\(downloading) downloading").foregroundStyle(Theme.accentText)
                }
                .buttonStyle(.plain)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .font(.system(size: 13).monospacedDigit())
        .foregroundStyle(page?.inkMuted ?? Theme.mut)
    }
}
