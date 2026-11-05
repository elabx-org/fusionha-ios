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
    /// The seam: three shallow scallops (0.9 deep) down the joint. Four
    /// 1.75 semicircles ran flat where they met, so at caption size the
    /// joined seam closed up and read as an "S" ("HD$4K") rather than a
    /// torn ticket edge.
    static let scallops = 3
    static let scallop: CGFloat = 0.9
    /// Joined: the gap between the interlocked edges, wide enough that a
    /// 1pt outline on each side still leaves the seam open.
    static let joinedGap: CGFloat = 2
    /// Apart: the left piece's room for its scallops, the row's item gap,
    /// the extra space before the right piece and that piece's own offset.
    static let leftOverhang: CGFloat = 1.2
    static let itemGap: CGFloat = 3
    static let apartExtra: CGFloat = 2
    static let rightOverhang: CGFloat = 1.0
    /// The letters: 9.5pt semibold, +0.3 tracking.
    static let letterSize: CGFloat = 9.5
    static let letterTracking: CGFloat = 0.3
    /// The left half's bulges down the seam, top to bottom (+1 out to the
    /// right). The right half follows the same line from the bottom up, so
    /// the halves nest.
    static var leftBulges: [CGFloat] { (0..<scallops).map { i -> CGFloat in i.isMultiple(of: 2) ? 1 : -1 } }

    /// The outline (1pt).
    static let stroke: CGFloat = 1

    /// A length snapped to whole device pixels (fractional gaps otherwise
    /// land on half pixels at @3x and blur).
    static func snap(_ value: CGFloat, _ displayScale: CGFloat) -> CGFloat {
        let s = max(displayScale, 1)
        return (value * s).rounded() / s
    }
}

/// One half of the HD/4K ticket. The left half's right edge and the right
/// half's left edge are the scalloped seam (out, in, out from the top on the
/// left; the same line on the right), so the two halves interlock. The
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
            Self.addSeam(&p, x: x1, from: y0, to: y1, depth: TicketMetrics.scallop * s,
                         bulges: TicketMetrics.leftBulges)
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
            // Bottom to top along the same line as the left half's seam.
            Self.addSeam(&p, x: x0, from: y1, to: y0, depth: TicketMetrics.scallop * s,
                         bulges: Array(TicketMetrics.leftBulges.reversed()))
        }
        p.closeSubpath()
        return p
    }

    /// Shallow scallops down the line x, from `start` to `end`, each
    /// bulging `depth` toward +x (1) or -x (-1). Each is a quadratic arc, so
    /// the seam crosses the line on a slant rather than running flat there,
    /// and the joined gap stays open along its whole length.
    private static func addSeam(_ p: inout Path, x: CGFloat, from start: CGFloat, to end: CGFloat,
                                depth: CGFloat, bulges: [CGFloat]) {
        let step = (end - start) / CGFloat(max(bulges.count, 1))
        for (i, bulge) in bulges.enumerated() {
            let ya = start + step * CGFloat(i)
            // A quadratic peaks at half its control's offset.
            p.addQuadCurve(to: CGPoint(x: x, y: ya + step),
                           control: CGPoint(x: x + bulge * 2 * depth, y: ya + step / 2))
        }
    }
}
