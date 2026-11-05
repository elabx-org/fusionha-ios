import SwiftUI
import FusionhaKit

/// One row of the v2 poster grid: `columns` posters, padded out with empty
/// cells on the last row. With a fold through the grid (book pose) each
/// poster takes its track, so the fold lands in a gutter; flat open, the
/// grid simply widens across the display.
struct V2LibraryGridRow: View {
    /// The Duo's column gap (mock `gap: 16px 14px`), and the fold tracks'.
    static let spacing: Double = 14
    let items: [MediaItem]
    let columns: Int
    var tracks: [FoldColumns.Track]?
    /// The grid's width (0 before it is measured).
    var width: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var phone: Bool { Self.isPhone(width: width, sizeClass: sizeClass) }
    private var columnGap: CGFloat { Self.columnGap(width: width, sizeClass: sizeClass) }
    private var cellWidth: CGFloat? { Self.cellWidth(width: width, columns: columns, sizeClass: sizeClass) }

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

    var body: some View {
        let _ = PerfCount.hit("V2LibraryGridRow.body")
        Group {
            if let tracks, tracks.count == columns {
                TrackRowLayout(tracks: tracks) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        V2PosterCard(item: item, artWidth: width > 0 ? CGFloat(tracks[i].width) : nil)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: columnGap) {
                    ForEach(0..<max(columns, items.count), id: \.self) { i in
                        if i < items.count {
                            V2PosterCard(item: items[i], artWidth: cellWidth).frame(maxWidth: .infinity, alignment: .top)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
            }
        }
        .padding(.bottom, phone ? 18 : 16)
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
        let gap = CGFloat(V2LibraryGridRow.spacing)
        return max(4, Int(((width + gap) / (targetPoster + gap)).rounded()))
    }
}
