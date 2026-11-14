import SwiftUI
import FusionhaKit

/// Home's tabletop geometry (half folded, the fold side to side): the
/// container's size and where the fold runs through it, both in the
/// container's own coordinates, measured from `FoldInfo` (the pose signal;
/// no hinge API). Nil when the container holds no side-to-side fold: Home is
/// then its ordinary scrolling page (flat portrait, folded, a title open and
/// Home squeezed into the top half above it).
struct V2TabletopSpace: Equatable {
    let size: CGSize
    let fold: ClosedRange<CGFloat>

    /// Nothing interactive sits closer to the fold than this.
    static let clearance: CGFloat = 20

    init?(_ proxy: GeometryProxy) {
        guard let fold = FoldInfo(proxy).horizontal,
              fold.lowerBound > 0, fold.upperBound < proxy.size.height else { return nil }
        self.size = proxy.size
        self.fold = fold
    }

    /// The top half's height, kept clear of the fold: the stage. `top` is how
    /// far down the bar pushes the page's content (the scroll view's top
    /// inset; the container itself runs under the bar).
    func stageHeight(top: CGFloat) -> CGFloat { max(0, fold.lowerBound - Self.clearance - top) }
    /// The fold and the clearance either side of it, between stage and floor.
    var gapHeight: CGFloat { Self.clearance * 2 + fold.upperBound - fold.lowerBound }
    /// Where the bottom half's content starts (y), kept clear of the fold.
    var floorTop: CGFloat { fold.upperBound + Self.clearance }
    var floorHeight: CGFloat { max(0, size.height - floorTop) }

    /// Where the stage's flat carousel draws its posters, in the container's
    /// coordinates (`V2TabletopStage` and `V2TabletopCarousel`'s own layout:
    /// the row centred under the heading). The hologram's lift starts from
    /// these and ends on them, so no poster jumps at either end.
    func flatCarousel(top: CGFloat) -> TabletopLift.Flat {
        let stage = stageHeight(top: top)
        let m = V2ComingUpWideMetrics(tabletopHeight: V2TabletopStage.posterHeight(stage: stage), motion: true)
        let heading = V2TabletopStage.headingHeight
        return TabletopLift.Flat(centerX: Double(size.width / 2),
                                 centerY: Double(top + heading + (stage - heading) / 2),
                                 width: Double(m.size.width), height: Double(m.size.height), step: Double(m.step),
                                 scales: m.scales.map { Double($0) }, opacities: m.opacities.map { Double($0) })
    }
}

/// What the Coming up row needs to lay Home out across a tabletop's two
/// halves: the geometry, Home as one ordinary page for when there is nothing
/// coming up, and Home's sections for the bottom half (without the heading
/// and Coming up, which the stage replaces).
struct V2TabletopContext {
    let space: V2TabletopSpace
    let plain: AnyView
    let rest: AnyView
}
