import SwiftUI
import FusionhaKit

/// The v2 poster grid: one lazy grid over every poster, in sections under
/// their headers (`V2LibraryGridSection`), `columns` across. Each card is
/// keyed by its title, so a column change (a title opening beside the
/// Library on the open Duo) re-flows the cards already built instead of
/// building new rows of them. With a fold through the grid (book pose) each
/// column takes its track, so the fold lands in a gutter; flat open, the
/// grid simply widens across the display.
struct V2LibraryGrid: View {
    /// The Duo's column gap (mock `gap: 16px 14px`), and the fold tracks'.
    static let spacing: Double = 14
    let sections: [V2LibraryGridSection]
    let columns: Int
    var tracks: [FoldColumns.Track]?
    /// The grid's width (0 before it is measured).
    var width: CGFloat = 0
    let entrance: LibraryEntrance
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var phone: Bool { Self.isPhone(width: width, sizeClass: sizeClass) }
    private var columnGap: CGFloat { Self.columnGap(width: width, sizeClass: sizeClass) }
    private var cellWidth: CGFloat? { Self.cellWidth(width: width, columns: columns, sizeClass: sizeClass) }
    private var fitted: [FoldColumns.Track]? { tracks.flatMap { $0.count == columns ? $0 : nil } }

    /// The phone's grid (mock libPhone `gap: 18px 16px`): wider gaps than the Duo's.
    static func isPhone(width: CGFloat, sizeClass: UserInterfaceSizeClass?) -> Bool {
        width > 0 && width < 520 && !OuterDisplay.isFoldedDuo(sizeClass: sizeClass)
    }

    static func columnGap(width: CGFloat, sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        isPhone(width: width, sizeClass: sizeClass) ? 16 : CGFloat(spacing)
    }

    /// A poster's width in a grid `width` wide (nil before it is measured).
    /// The home's shelf uses it too, so its posters line up with the grid's.
    static func cellWidth(width: CGFloat, columns: Int, sizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        guard width > 0, columns > 0 else { return nil }
        let gap = columnGap(width: width, sizeClass: sizeClass)
        return (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
    }

    /// The columns: the fold's tracks (each its width, the gap to the next
    /// its spacing), or `columns` equal ones.
    private var gridItems: [GridItem] {
        if let tracks = fitted {
            return tracks.indices.map { i in
                let gap = i + 1 < tracks.count ? tracks[i + 1].x - tracks[i].maxX : 0
                return GridItem(.fixed(CGFloat(tracks[i].width)), spacing: CGFloat(gap), alignment: .top)
            }
        }
        return Array(repeating: GridItem(.flexible(), spacing: columnGap, alignment: .top), count: max(columns, 1))
    }

    var body: some View {
        let _ = PerfCount.hit("V2LibraryGrid.body")
        LazyVGrid(columns: gridItems, alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                Section {
                    ForEach(section.cells) { cell in
                        card(cell)
                    }
                } header: {
                    header(section.header)
                }
            }
        }
        .padding(.leading, CGFloat(fitted?.first?.x ?? 0))
        .scrollTargetLayout()
    }

    private func card(_ cell: V2LibraryGridCell) -> some View {
        let art: CGFloat? = width > 0 ? (fitted.map { CGFloat($0[cell.column % $0.count].width) } ?? cellWidth) : nil
        return V2PosterCard(item: cell.item, artWidth: art)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.bottom, phone ? 18 : 16)
            .libraryRowEntrance(entrance, id: cell.rowId)
    }

    @ViewBuilder
    private func header(_ header: V2LibraryGridSection.Header?) -> some View {
        if let header {
            switch header {
            case .status(let status, let count):
                StatusSectionHeader(status: status, count: count).frame(maxWidth: .infinity, alignment: .leading)
            case .letter(let letter, let count):
                LibraryLetterHeader(letter: letter, count: count).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// v2's poster columns: three on phones and the folded Duo (never four),
/// two in a narrow column, and wider than that as many as keep the posters
/// nearest 130pt, 14 apart (owner, 2026-11-05: six across the flat open
/// Duo's ~820, about 125pt each; no density setting).
enum V2LibraryColumns {
    static let targetPoster: CGFloat = 130

    static func count(for width: CGFloat) -> Int {
        guard width > 0 else { return 3 }
        if width < 300 { return 2 }
        if width < 520 { return 3 }
        let gap = CGFloat(V2LibraryGrid.spacing)
        return max(4, Int(((width + gap) / (targetPoster + gap)).rounded()))
    }

    /// A poster's width in a row `width` wide laid out as the grid would be:
    /// the title page's rails use it, so their cards match the Library's.
    static func posterWidth(for width: CGFloat) -> CGFloat {
        let n = CGFloat(count(for: width))
        let gap = CGFloat(V2LibraryGrid.spacing)
        return max(1, (width - gap * (n - 1)) / n)
    }
}

extension PosterRailMetrics {
    /// The v2 Library grid's cards (`V2LibraryColumns`, 14 apart, 12pt corners).
    static let v2Library = PosterRailMetrics(cardWidth: { V2LibraryColumns.posterWidth(for: $0) },
                                             spacing: CGFloat(V2LibraryGrid.spacing), radius: 12)
}
