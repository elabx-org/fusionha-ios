import SwiftUI
import FusionhaKit

/// The strip in the fold in book pose, with a title open beside the list
/// (owner, 2026-11-09: option O of the hinge mock, "glass seam, blended
/// edges"). Instead of a black gap, the list pane's ground runs in from the
/// left and the title's page ground, with its art blurred across the top,
/// from the right; they meet in the middle under a faint shadow where the
/// hinge is. The strip reaches `blend` points over each page's edge and fades
/// out there, so there is no line where a page stops.
///
/// Decoration only: nothing in it takes a touch or is read out, and it is
/// drawn once per title (no live blur, no hinge-angle effects).
struct V2FoldSeam: View {
    let context: FoldSeamContext
    @Environment(AppModel.self) private var model

    /// How far the strip runs over each page's edge (under the pages' 20pt margins).
    static let blend: CGFloat = 16

    var body: some View {
        let _ = PerfCount.hit("V2FoldSeam.body")
        let look = V2TitleShellGround.look(model, context.itemId)
        let gap = context.gap
        let start = max(0, gap.lowerBound - Self.blend)
        let end = min(context.size.width, gap.upperBound + Self.blend)
        let width = max(0, end - start)
        ZStack(alignment: .topLeading) {
            // The list pane's ground as the list paints it, laid out at the list's width.
            PageGround(palette: look.palette, recipe: .listPane)
                .frame(width: gap.upperBound)
                .offset(x: -start)
                .frame(width: width, alignment: .topLeading)
                .clipped()
                .mask(meeting(width: width, from: .leading))
            // The title's ground with its art, laid out from the fold to the trailing edge.
            PageGround(palette: look.palette, recipe: .page,
                       artURL: look.palette.fromArt ? look.art : nil)
                .frame(width: context.size.width - gap.lowerBound)
                .offset(x: gap.lowerBound - start)
                .frame(width: width, alignment: .topLeading)
                .clipped()
                .mask(meeting(width: width, from: .trailing))
            // The hinge: a faint shadow down the middle of the fold.
            LinearGradient(stops: [.init(color: .clear, location: 0.3),
                                   .init(color: .black.opacity(0.16), location: 0.5),
                                   .init(color: .clear, location: 0.7)],
                           startPoint: .leading, endPoint: .trailing)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .clipped()
        .mask(edges(width: width))
        .offset(x: start)
        .ignoresSafeArea(edges: .vertical)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// One ground's share of the strip: solid on its own side, crossfading
    /// into the other across the middle of the fold.
    private func meeting(width: CGFloat, from edge: HorizontalEdge) -> some View {
        let solid: [Gradient.Stop] = [.init(color: .black, location: 0), .init(color: .black, location: 0.38),
                                      .init(color: .clear, location: 0.62)]
        return LinearGradient(stops: solid,
                              startPoint: edge == .leading ? .leading : .trailing,
                              endPoint: edge == .leading ? .trailing : .leading)
            .frame(width: width)
    }

    /// The strip fades in over each page's edge, so no line shows where it starts.
    private func edges(width: CGFloat) -> some View {
        let f = width > 0 ? Self.blend / width : 0
        return LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: f),
                                      .init(color: .black, location: 1 - f), .init(color: .clear, location: 1)],
                              startPoint: .leading, endPoint: .trailing)
    }
}
