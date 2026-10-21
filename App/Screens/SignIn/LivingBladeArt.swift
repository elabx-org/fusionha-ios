import FusionhaKit
import SwiftUI

/// The F's vector blades (web `living/blade-art.ts` + `fusion-paint.ts`
/// `paintBlades`): three outlines in the blade gradients, with the clapper's
/// stripes, board lines and clap. Paints in box units (the caller sets the
/// transform). The blades on the mark are masks of the logo image; this is the
/// vector twin the fusion moves draw while the mark is hidden.
@MainActor
enum LivingBladeArt {
    /// Blade gradients (left → right across each blade's box): top, middle, bottom.
    static let grads: [Gradient] = [
        Gradient(stops: [.init(color: Color(hex: 0x1777EC), location: 0), .init(color: Color(hex: 0x9D5DA7), location: 0.5),
                         .init(color: Color(hex: 0xFDBA61), location: 1)]),
        Gradient(stops: [.init(color: Color(hex: 0x1966E6), location: 0), .init(color: Color(hex: 0xAA439A), location: 0.55),
                         .init(color: Color(hex: 0xFDAC65), location: 1)]),
        Gradient(stops: [.init(color: Color(hex: 0x327FF0), location: 0), .init(color: Color(hex: 0xC256B9), location: 1)]),
    ]

    static let stripeFill = Color.white.opacity(0.9)
    /// Clapper stripes on the arm (slot 0) and the striped stick (slot 1): one
    /// slanted quad per 12 units across the box.
    static let stripes: [Path] = {
        let bands: [(y0: Double, y1: Double, slant: Double)] = [(26, 39, 7), (40, 53, -7)]
        return bands.map(stripePath)
    }()

    private static func stripePath(_ band: (y0: Double, y1: Double, slant: Double)) -> Path {
        let (y0, y1, slant) = band
        var path = Path()
        for x in stride(from: -10.0, to: 110, by: 12) {
            path.addLines([CGPoint(x: x, y: y1), CGPoint(x: x + 6, y: y1), CGPoint(x: x + 6 + slant, y: y0),
                           CGPoint(x: x + slant, y: y0)])
            path.closeSubpath()
        }
        return path
    }

    /// The board's three writing lines: x0, x1, y.
    static let boardLines: Path = {
        var path = Path()
        let lines: [(Double, Double, Double)] = [(21, 58, 66), (21, 50, 76), (21, 62, 86)]
        for (a, b, y) in lines {
            path.move(to: CGPoint(x: a, y: y))
            path.addLine(to: CGPoint(x: b, y: y))
        }
        return path
    }()
    static let boardLineStroke = Color.white.opacity(0.28)
    static let boardLineWidth: CGFloat = 1.6

    struct Options {
        /// Per-blade horizontal offset (the split's stagger).
        var lag: [Double]?
        /// Clapper arm angle (deg) about its hinge.
        var arm: Double = 0
        /// Clapper stripes + board lines opacity.
        var deco: Double = 0
        /// Brightness (1 = none).
        var flash: Double = 1
        var alpha: Double = 1
    }

    static func path(_ poly: LivingPoly) -> Path {
        var path = Path()
        path.addLines(poly.map { CGPoint(x: $0.x, y: $0.y) })
        path.closeSubpath()
        return path
    }

    /// Paint three blade outlines (bottom blade first, so the top one is in front).
    static func paint(_ ctx: GraphicsContext, _ sets: [LivingPoly], _ o: Options = Options()) {
        var base = ctx
        base.blendMode = .normal
        base.opacity *= o.alpha
        // CSS brightness() as the mark's own flash (light × 0.45, as `LivingMark`).
        if o.flash > 1 { base.addFilter(.brightness((o.flash - 1) * 0.45)) }
        for i in [2, 1, 0] {
            var blade = base
            if let lag = o.lag?[i], lag != 0 { blade.translateBy(x: lag, y: 0) }
            if i == 0 && o.arm != 0 {
                blade.translateBy(x: 13, y: 38)
                blade.rotate(by: .degrees(o.arm))
                blade.translateBy(x: -13, y: -38)
            }
            let shape = path(sets[i])
            let xs = sets[i].map(\.x)
            let x0 = xs.min() ?? 0, x1 = max(xs.max() ?? 0, x0 + 0.01)
            blade.fill(shape, with: .linearGradient(grads[i], startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x1, y: 0)))
            if o.deco > 0 && i < 2 {
                var deco = blade
                deco.clip(to: shape)
                deco.opacity *= o.deco
                deco.fill(stripes[i], with: .color(stripeFill))
            }
        }
        if o.deco > 0 {
            var lines = base
            lines.opacity *= o.deco
            lines.stroke(boardLines, with: .color(boardLineStroke),
                         style: StrokeStyle(lineWidth: boardLineWidth, lineCap: .round))
        }
    }
}
