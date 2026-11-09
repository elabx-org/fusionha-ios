import SwiftUI
import FusionhaKit

/// The fold in book pose, with a title open beside the list, drawn as an
/// open book's gutter (owner 2026-11-09, option 3c of the hinge mock;
/// option O before it). Each page's own ground runs to a crease down the
/// middle (`PaneGrounds`: what the page beside it really paints, not a guess
/// from the title), a soft shadow deepens toward it across both pages, a
/// thin highlight shows where each page turns, and pale binding thread shows
/// along the crease. How deep the book reads follows the hinge angle
/// (`V2HingeDepth`): opened almost flat the crease is faint; closed toward
/// 95° the shadow widens and deepens and the thread stands out. A ground
/// that is nearly black (a dark poster) is lifted so the fold never reads
/// as a black gap.
///
/// Decoration only: nothing in it takes a touch or is read out. Layout never
/// reads the angle; only this drawing changes, and only while the hinge moves.
struct V2FoldSeam: View {
    let context: FoldSeamContext
    @Environment(AppModel.self) private var model
    @Environment(\.paneGrounds) private var grounds
    @State private var depth = BookGutter.initialDepth

    /// How far the grounds run over each page's edge (under the pages' 20pt margins).
    static let blend: CGFloat = 16

    var body: some View {
        let _ = PerfCount.hit("V2FoldSeam.body")
        let gap = context.gap
        let crease = (gap.lowerBound + gap.upperBound) / 2
        let reach = CGFloat(BookGutter.shadowReach(depth))
        let start = max(0, min(gap.lowerBound - Self.blend, crease - reach))
        let end = min(context.size.width, max(gap.upperBound + Self.blend, crease + reach))
        let width = max(0, end - start)
        let look = V2TitleShellGround.look(model, context.itemId)
        ZStack(alignment: .topLeading) {
            V2GutterGround(report: grounds?.leading(of: gap.lowerBound),
                           fallback: (look.palette, .listPane, nil), other: look.palette,
                           from: gap.lowerBound - Self.blend, to: crease, origin: start, leading: true)
            V2GutterGround(report: grounds?.trailing(of: gap.upperBound),
                           fallback: (look.palette, .page, look.palette.fromArt ? look.art : nil),
                           other: grounds?.leading(of: gap.lowerBound)?.palette ?? look.palette,
                           from: crease, to: gap.upperBound + Self.blend, origin: start, leading: false)
            V2GutterShade(width: width, crease: crease - start, depth: depth)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .clipped()
        .offset(x: start)
        .ignoresSafeArea(edges: .vertical)
        .modifier(V2HingeDepth(depth: $depth))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One page's ground in the gutter: laid out as the page lays it out (from
/// its leading edge, the art at its top) and run on to the crease, faded in
/// over the page's edge so no line shows where the page stops.
struct V2GutterGround: View {
    let report: PaneGrounds.Report?
    let fallback: (PagePalette, PageGround.Recipe, URL?)
    /// The other page's palette: a hue-less black ground borrows it, faintly.
    let other: PagePalette
    let from: CGFloat
    let to: CGFloat
    /// The strip's leading edge in the shell's coordinates.
    let origin: CGFloat
    let leading: Bool

    var body: some View {
        let palette = report?.palette ?? fallback.0
        let pageMinX = report?.frame.minX ?? (leading ? 0 : from)
        let pageWidth = max(1, (leading ? to : (report?.frame.maxX ?? to + 400)) - pageMinX)
        let lum = V2GutterTone.luminance(palette.tint)
        let lift = BookGutter.lift(luminance: lum)
        PageGround(palette: palette, recipe: report?.recipe ?? fallback.1,
                   artURL: report.map { $0.palette.fromArt ? $0.art : nil } ?? fallback.2,
                   artHeight: report?.artHeight ?? 760, artOpacity: report?.artOpacity ?? .w1)
            .frame(width: pageWidth)
            .brightness(lift)
            .overlay {
                if lift > 0, palette.isMono || V2GutterTone.saturation(palette.tint) < 0.12 {
                    other.tint.opacity(0.22).blendMode(.color)
                }
            }
            .offset(x: pageMinX - from)
            .frame(width: max(0, to - from), alignment: .topLeading)
            .clipped()
            .mask {
                HStack(spacing: 0) {
                    if leading { fade }
                    Color.black
                    if !leading { fade }
                }
            }
            .offset(x: from - origin)
    }

    /// The ground fades in over the page's own edge.
    private var fade: some View {
        LinearGradient(colors: [.clear, .black],
                       startPoint: leading ? .leading : .trailing, endPoint: leading ? .trailing : .leading)
            .frame(width: V2FoldSeam.blend)
    }
}
