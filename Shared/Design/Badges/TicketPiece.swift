import SwiftUI

/// The T5 ticket geometry (owner 2026-11-04, mock badges-ticket.js), in
/// points at the default text size. Everything scales together by one
/// factor (`@ScaledMetric`), so the pieces still plug together at large
/// Dynamic Type.
enum TicketMetrics {
    /// Piece height and corner radius.
    static let height: CGFloat = 14
    static let radius: CGFloat = 3.5
    /// A piece's width: 18, or 23 when it carries "!" (held).
    static func width(held: Bool) -> CGFloat { held ? 23 : 18 }
    /// In a pair the left piece is 1.5 wider and the right 2.5 wider, so the
    /// letters stay centred clear of the scallops.
    static let leftExtra: CGFloat = 1.5
    static let rightExtra: CGFloat = 2.5
    /// The seam: four semicircles of radius 1.75 down the joint.
    static let scallop: CGFloat = 1.75
    /// Joined: the gap between the interlocked edges.
    static let joinedGap: CGFloat = 1.3
    /// Apart: the left piece's room for its scallops, the row's item gap,
    /// the extra space before the right piece and that piece's own offset.
    static let leftOverhang: CGFloat = 1.8
    static let itemGap: CGFloat = 3
    static let apartExtra: CGFloat = 2
    static let rightOverhang: CGFloat = 1.1
    /// The letters: 9.5pt semibold, +0.3 tracking.
    static let letterSize: CGFloat = 9.5
    static let letterTracking: CGFloat = 0.3
    /// The outline (1pt).
    static let stroke: CGFloat = 1

    /// A length snapped to whole device pixels (1.3pt gaps and 1.75pt arcs
    /// otherwise land on half pixels at @3x and blur).
    static func snap(_ value: CGFloat, _ displayScale: CGFloat) -> CGFloat {
        let s = max(displayScale, 1)
        return (value * s).rounded() / s
    }
}

/// One half of the HD/4K ticket. The left half's right edge and the right
/// half's left edge are the scalloped seam (out, in, out, in from the top on
/// the left; the mirror on the right), so the two halves interlock. The
/// shape's frame is the piece's body: the seam's bulges reach
/// `TicketMetrics.scallop` past it, outside the frame.
struct TicketPiece: Shape {
    enum Side: Sendable { case left, right }

    var side: Side

    func path(in rect: CGRect) -> Path {
        let s = rect.height / TicketMetrics.height
        let r = TicketMetrics.radius * s
        let x0 = rect.minX, x1 = rect.maxX, y0 = rect.minY, y1 = rect.maxY
        var p = Path()
        switch side {
        case .left:
            p.move(to: CGPoint(x: x0 + r, y: y0))
            p.addLine(to: CGPoint(x: x1, y: y0))
            Self.addSeam(&p, x: x1, from: y0, to: y1, bulges: [1, -1, 1, -1])
            p.addLine(to: CGPoint(x: x0 + r, y: y1))
            p.addArc(tangent1End: CGPoint(x: x0, y: y1), tangent2End: CGPoint(x: x0, y: y0), radius: r)
            p.addLine(to: CGPoint(x: x0, y: y0 + r))
            p.addArc(tangent1End: CGPoint(x: x0, y: y0), tangent2End: CGPoint(x: x1, y: y0), radius: r)
        case .right:
            p.move(to: CGPoint(x: x0, y: y0))
            p.addLine(to: CGPoint(x: x1 - r, y: y0))
            p.addArc(tangent1End: CGPoint(x: x1, y: y0), tangent2End: CGPoint(x: x1, y: y1), radius: r)
            p.addLine(to: CGPoint(x: x1, y: y1 - r))
            p.addArc(tangent1End: CGPoint(x: x1, y: y1), tangent2End: CGPoint(x: x0, y: y1), radius: r)
            p.addLine(to: CGPoint(x: x0, y: y1))
            // Bottom to top: in, out, in, out (mirrors the left half).
            Self.addSeam(&p, x: x0, from: y1, to: y0, bulges: [-1, 1, -1, 1])
        }
        p.closeSubpath()
        return p
    }

    /// Semicircles down the line x, from `start` to `end` (a quarter of the
    /// height each, so radius 1.75 at 14pt), each
    /// bulging +x (1) or -x (-1). Drawn as cubic quarter arcs, so the
    /// direction never depends on an arc's clockwise convention.
    private static func addSeam(_ p: inout Path, x: CGFloat, from start: CGFloat, to end: CGFloat, bulges: [CGFloat]) {
        let k: CGFloat = 0.552_284_75
        let step = (end - start) / CGFloat(bulges.count)
        let r = abs(step) / 2
        let dir: CGFloat = step >= 0 ? 1 : -1
        for (i, bulge) in bulges.enumerated() {
            let ya = start + step * CGFloat(i)
            let yb = ya + step
            let cy = (ya + yb) / 2
            let bx = x + bulge * r
            p.addCurve(to: CGPoint(x: bx, y: cy),
                       control1: CGPoint(x: x + bulge * k * r, y: ya),
                       control2: CGPoint(x: bx, y: cy - dir * k * r))
            p.addCurve(to: CGPoint(x: x, y: yb),
                       control1: CGPoint(x: bx, y: cy + dir * k * r),
                       control2: CGPoint(x: x + bulge * k * r, y: yb))
        }
    }
}
