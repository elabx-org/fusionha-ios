import SwiftUI
import FusionhaKit

/// The fold in book pose, with a title open beside the list, drawn as two
/// seas meeting (owner 2026-11-09, option 2 of the hinge mock; the book
/// gutter, 3c, before it). Each page's own ground runs into the fold
/// (`PaneGrounds`: what the page beside it really paints, not a guess from
/// the title), and the two meet along a line that meanders down it, with
/// eddies, currents, a faint seam and a light shadow down the hinge
/// (`FoldSeas`). A ground that is nearly black (a dark poster) is lifted so
/// the fold never reads as a black gap.
///
/// Decoration only: nothing in it takes a touch or is read out.
struct V2FoldSeam: View {
    let context: FoldSeamContext
    @Environment(AppModel.self) private var model
    @Environment(\.paneGrounds) private var grounds

    /// How far the seas run over each page's edge (under the pages' 20pt margins).
    static let blend: CGFloat = 16

    var body: some View {
        let _ = PerfCount.hit("V2FoldSeam.body")
        let gap = context.gap
        let start = max(0, gap.lowerBound - Self.blend)
        let end = min(context.size.width, gap.upperBound + Self.blend)
        let look = V2TitleShellGround.look(model, context.itemId)
        let leading = grounds?.leading(of: gap.lowerBound)
        let trailing = grounds?.trailing(of: gap.upperBound)
        let leadingPalette = leading?.palette ?? look.palette
        let trailingPalette = trailing?.palette ?? look.palette
        let meeting = FoldSeas.meeting(leading: V2GutterTone.lifted(leadingPalette.tint),
                                       trailing: V2GutterTone.lifted(trailingPalette.tint))
        ZStack(alignment: .topLeading) {
            V2SeaGround(report: leading, fallback: (look.palette, .listPane, nil), other: trailingPalette,
                        start: start, end: end, leading: true)
            V2SeaGround(report: trailing, fallback: (look.palette, .page, look.palette.fromArt ? look.art : nil),
                        other: leadingPalette, start: start, end: end, leading: false)
                .mask { V2FoldSeasLayer(kind: .sea, meeting: meeting) }
            V2FoldSeasLayer(kind: .shade, meeting: meeting)
        }
        .frame(width: max(0, end - start))
        .frame(maxHeight: .infinity)
        .mask { edgeFade }
        .clipped()
        .offset(x: start)
        .ignoresSafeArea(edges: .vertical)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The seas fade in over each page's own edge, so no line shows where a page stops.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: Self.blend)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: Self.blend)
        }
    }
}

/// One page's ground across the whole strip: laid out as the page lays it
/// out (from its own edge, the art at its top) and run on through the fold.
struct V2SeaGround: View {
    let report: PaneGrounds.Report?
    let fallback: (PagePalette, PageGround.Recipe, URL?)
    /// The other page's palette: a hue-less black ground borrows it, faintly.
    let other: PagePalette
    /// The strip's edges in the shell's coordinates.
    let start: CGFloat
    let end: CGFloat
    let leading: Bool

    var body: some View {
        let palette = report?.palette ?? fallback.0
        let frame = report?.frame
        // The leading page runs on past its trailing edge; the trailing one starts early.
        let minX = leading ? (frame?.minX ?? 0) : min(frame?.minX ?? start, start)
        let maxX = leading ? max(frame?.maxX ?? end, end) : (frame?.maxX ?? end + 400)
        let lift = FoldSeas.lift(luminance: V2GutterTone.luminance(palette.tint))
        PageGround(palette: palette, recipe: report?.recipe ?? fallback.1,
                   artURL: report.map { $0.palette.fromArt ? $0.art : nil } ?? fallback.2,
                   artHeight: report?.artHeight ?? 760, artOpacity: report?.artOpacity ?? .w1)
            .frame(width: max(1, maxX - minX))
            .brightness(lift)
            .overlay {
                if lift > 0, palette.isMono || V2GutterTone.saturation(palette.tint) < 0.12 {
                    other.tint.opacity(0.22).blendMode(.color)
                }
            }
            .offset(x: minX - start)
            .frame(width: max(0, end - start), alignment: .topLeading)
            .clipped()
    }
}
