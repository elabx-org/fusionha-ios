import SwiftUI
import FusionhaKit

/// A rail's horizontal track: gap 14, padding 2 2 12, snaps to cards.
///
/// With the iPhone Duo's fold inside it (a Spread spanning both pages, or the
/// Web layout; flat or Book) the cards sit in pages that each end before the
/// fold's gutter and the track scrolls a page at a time
/// (`DiscoverFold.railPages`), so no card rests on the fold. Cards size
/// themselves with `.railCell(_:)`, which takes the page's column width there.
struct RailTrack<Content: View>: View {
    /// How many cards the track holds.
    let count: Int
    /// The cards' usual width (the narrowest a folded page's column may be).
    let cell: CGFloat
    @ViewBuilder var content: Content
    @State private var measured = GridFold()

    private static var spacing: CGFloat { 14 }

    private var pages: FoldColumns.Pages? {
        DiscoverFold.railPages(count: count, viewport: Double(measured.width), fold: measured.foldRange,
                               cell: Double(cell), spacing: Double(Self.spacing))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let pages {
                folded(pages)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: Self.spacing) { content }
                        .scrollTargetLayout()
                        .padding(.horizontal, 2)
                        .padding(.top, 2)
                        .padding(.bottom, 12)
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
                .scrollClipDisabled()
            }
        }
        .onGeometryChange(for: GridFold.self) { GridFold($0) } action: { measured = $0 }
    }

    /// Pages either side of the fold, resting on whole pages.
    private func folded(_ pages: FoldColumns.Pages) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            TrackRowLayout(tracks: pages.tracks) { content }
                .environment(\.railCellOverride, CGFloat(pages.columnWidth))
                .frame(width: CGFloat(pages.contentWidth(viewport: Double(measured.width))), alignment: .leading)
                .padding(.top, 2)
                .padding(.bottom, 12)
        }
        .scrollTargetBehavior(StrideScrollTarget(stride: CGFloat(pages.stride), maxOffset: CGFloat(pages.lastOffset)))
        .scrollClipDisabled()
    }
}

extension EnvironmentValues {
    /// A folded rail's column width (`RailTrack`): its cards fill it.
    @Entry var railCellOverride: CGFloat? = nil
}

private struct RailCell: ViewModifier {
    let width: CGFloat
    @Environment(\.railCellOverride) private var override

    func body(content: Content) -> some View {
        content.frame(width: override ?? width, alignment: .topLeading)
    }
}

extension View {
    /// A rail card's width: `width`, or its folded page's column (`RailTrack`).
    func railCell(_ width: CGFloat) -> some View {
        modifier(RailCell(width: width))
    }
}

extension SpreadContext {
    /// One page's width while the tab spans a Spread (rail cells are sized
    /// for a page, not the whole spread); `nil` otherwise.
    var spanPageWidth: Double? { spans ? pages?.left.width : nil }
}
