import SwiftUI
import FusionhaKit

/// Library / Discover poster columns for a content width: three on every
/// phone (unchanged), two in a narrow column, more as the width grows (the
/// web's `repeat(auto-fill, minmax(…))`).
enum PosterColumns {
    /// `evenForFold`: a fold crosses the grid's middle (`FoldInfo.crossesMiddle`),
    /// so an odd count drops by one and the fold lands in the centre gutter.
    static func count(for width: CGFloat, evenForFold: Bool = false) -> Int {
        let count = baseCount(for: width)
        return evenForFold && count % 2 == 1 ? max(2, count - 1) : count
    }

    private static func baseCount(for width: CGFloat) -> Int {
        guard width > 0 else { return 3 }
        if width < 300 { return 2 }
        if width < 520 { return 3 }
        return max(4, Int((width + 10) / 150))
    }
}

/// A grid's own width and the top-to-bottom fold through it, in its own
/// coordinates (the real fold x, so the Duo's off-centre fold is found too).
struct GridFold: Equatable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?

    init() {}

    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        fold = FoldInfo.verticalFold(proxy)
    }

    var foldRange: ClosedRange<Double>? { fold.map { Double($0.lowerBound)...Double($0.upperBound) } }
}

/// A poster grid whose column count follows its own width (`PosterColumns`):
/// three tracks on phones, more when unfolded. With the iPhone Duo's fold
/// through it the tracks split around the real fold (`PosterTracks`): the
/// usual count in the Web layout, 3 a side while a Spread spans both pages.
/// 22 × 10 gaps like the Library.
struct AdaptivePosterGrid<Content: View>: View {
    var spacing: CGFloat = 22
    var columnSpacing: CGFloat = 10
    @ViewBuilder var content: Content
    @Environment(\.spread) private var spread
    @State private var measured = GridFold()

    /// Spanning a Spread with the fold inside: 3 a side (the Library's span).
    private var spans: Bool { spread.spans && measured.fold != nil }
    private var columns: Int { PosterTracks.count(base: PosterColumns.count(for: measured.width), spans: spans) }
    private var tracks: [FoldColumns.Track]? {
        PosterTracks.tracks(count: columns, width: Double(measured.width), fold: measured.foldRange,
                            spans: spans, spacing: Double(columnSpacing))
    }

    var body: some View {
        Group {
            if let tracks, tracks.count == columns {
                TrackGrid(tracks: tracks, rowSpacing: spacing) { content }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: columnSpacing, alignment: .top),
                                         count: columns),
                          alignment: .leading, spacing: spacing) {
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: GridFold.self) { GridFold($0) } action: { measured = $0 }
    }
}

/// Children in rows on given tracks (`FoldColumns.Track`): child i in track
/// i % count, a new row every `tracks.count` children. The rows are lazy; a
/// row is as tall as its tallest child. A grid that keeps the fold in a gutter.
struct TrackGrid<Content: View>: View {
    let tracks: [FoldColumns.Track]
    var rowSpacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        Group(subviews: content) { subviews in
            let size = max(tracks.count, 1)
            let rows = stride(from: 0, to: subviews.count, by: size).map { $0..<min($0 + size, subviews.count) }
            LazyVStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(rows, id: \.lowerBound) { range in
                    TrackRowLayout(tracks: tracks) {
                        ForEach(subviews[range]) { $0 }
                    }
                }
            }
        }
    }
}
