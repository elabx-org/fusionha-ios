import SwiftUI
import UIKit
import FusionhaKit

/// The hologram scene on this display: where the hinge runs through Home's
/// container, the scale from the scene's 669-pt design width, and how far
/// the top half leans back. It carries a point of the scene
/// (`TabletopVec`) to each half's own layer and builds the transform that
/// draws a flat view onto four of them (`TabletopProjection.homography`).
struct V2HologramRig: Equatable {
    /// Which half a piece is drawn on. Each half is its own layer, clipped
    /// to the half: the top one starts at the container's top, the bottom
    /// one at the hinge.
    enum Half { case top, bottom }

    let size: CGSize
    /// The hinge line (the middle of the fold), in the container's coordinates.
    let hingeY: CGFloat
    let phi: Double

    init(space: V2TabletopSpace, hingeDegrees: Double) {
        size = space.size
        hingeY = (space.fold.lowerBound + space.fold.upperBound) / 2
        phi = TabletopProjection.phi(hingeDegrees: hingeDegrees)
    }

    var scale: Double { Double(size.width) / TabletopProjection.designWidth }
    var bottomHeight: CGFloat { max(0, size.height - hingeY) }

    func height(of half: Half) -> CGFloat { half == .top ? hingeY : bottomHeight }

    /// Where a point of the scene is drawn in `half`'s layer.
    func point(_ v: TabletopVec, on half: Half) -> CGPoint {
        let middle = Double(size.width) / 2
        switch half {
        case .top:
            let p = TabletopProjection.onScreen(v, phi: phi)
            return CGPoint(x: middle + p.x * scale, y: Double(hingeY) - p.y * scale)
        case .bottom:
            let p = TabletopProjection.onFloor(v)
            return CGPoint(x: middle + p.x * scale, y: p.y * scale)
        }
    }

    func quad(_ corners: [TabletopVec], on half: Half) -> [TabletopPoint] {
        corners.map { v in
            let p = point(v, on: half)
            return TabletopPoint(Double(p.x), Double(p.y))
        }
    }

    /// The transform that draws a `box`-sized view (at the layer's top-left)
    /// onto `corners` as the eye sees them on `half`.
    func transform(_ corners: [TabletopVec], on half: Half, from box: CGSize) -> ProjectionTransform {
        transform(quad(corners, on: half), from: box)
    }

    /// The transform that draws a `box`-sized view onto `quad`, four points
    /// of a half's layer (a poster part of the way through the lift).
    func transform(_ quad: [TabletopPoint], from box: CGSize) -> ProjectionTransform {
        let k = TabletopProjection.homography(width: Double(box.width), height: Double(box.height),
                                              quad: quad).map { CGFloat($0) }
        var m = CATransform3DIdentity
        m.m11 = k[0]
        m.m21 = k[1]
        m.m41 = k[2]
        m.m12 = k[3]
        m.m22 = k[4]
        m.m42 = k[5]
        m.m14 = k[6]
        m.m24 = k[7]
        return ProjectionTransform(m)
    }

    /// A point of the container, in the coordinates `quad(_:on:)` uses for
    /// the half it falls on.
    func locate(_ point: CGPoint) -> (half: Half, point: TabletopPoint) {
        if point.y < hingeY {
            return (Half.top, TabletopPoint(Double(point.x), Double(point.y)))
        }
        return (Half.bottom, TabletopPoint(Double(point.x), Double(point.y - hingeY)))
    }
}

extension View {
    /// Draws this view, laid out `box` large at its layer's top-left, through
    /// `transform` (a quad of the scene). Layout is untouched.
    func hologramPiece(_ transform: ProjectionTransform, box: CGSize) -> some View {
        frame(width: box.width, height: box.height)
            .projectionEffect(transform)
    }
}
