import FusionhaKit
import SwiftUI

/// The fusion moves' own painters (web `living/fusion-paint.ts`): a figure's
/// floor shadow, and the contact and merge particles. The floor paints in box
/// units; the particles in canvas points.
@MainActor
enum LivingFusionPaint {
    /// A soft floor shadow centred at (x, y), 60 × 8 box units.
    static func floor(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, alpha: Double) {
        guard alpha > 0 else { return }
        var layer = ctx
        layer.blendMode = .normal
        layer.opacity *= alpha
        layer.translateBy(x: x, y: y)
        layer.scaleBy(x: 30, y: 4)
        layer.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
                   with: .radialGradient(Gradient(colors: [.black.opacity(0.6), .black.opacity(0)]),
                                         center: .zero, startRadius: 0, endRadius: 1))
    }

    /// Deterministic noise, so the burst looks the same every frame.
    private struct Noise {
        var s: UInt32
        mutating func next() -> Double {
            s = s &* 1664525 &+ 1013904223
            return Double(s) / 4294967296
        }
    }

    /// Contact: a Living spark and a burst of brand particles at `at`.
    /// `since` = seconds since contact; `k` = points per box unit.
    static func contact(_ ctx: GraphicsContext, at p: CGPoint, since: Double, k: CGFloat) {
        let sp = FusionDance.clamp((since + 0.02) / 0.44)
        guard sp > 0, sp < 1 else { return }
        var ctx = ctx
        ctx.blendMode = .plusLighter
        LivingMedia.star(&ctx, p, CGFloat(6 + 20 * FusionDance.outC(sp * 2)) * CGFloat(1 - sp) * k * 0.85, sp * 2.2,
                         1 - sp * sp)
        var rng = Noise(s: 7)
        let cols = LivingEngine.sparkColors
        for n in 0..<18 {
            let a = rng.next() * 6.283
            let v = CGFloat(40 + rng.next() * 70) * k
            let life = 0.28 + rng.next() * 0.22
            let r = CGFloat(1.6 + rng.next() * 1.6)
            let u = FusionDance.clamp(since / life)
            guard u > 0, u < 1 else { continue }
            let d = v * CGFloat(FusionDance.outC(u)) * 0.5
            let c = CGPoint(x: p.x + CGFloat(cos(a)) * d, y: p.y + CGFloat(sin(a)) * d)
            let rr = r * CGFloat(1 - u * 0.5)
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                     with: .color(cols[n % cols.count].opacity(1 - u)))
        }
    }

    /// The merge: two trails of brand particles (blue, orange) spiralling into
    /// `centre`; `wp` 0 → 1 over the slide home, `size` = the mark size.
    static func whirl(_ ctx: GraphicsContext, centre: CGPoint, size: CGFloat, wp: Double) {
        guard wp > 0, wp < 1 else { return }
        var ctx = ctx
        ctx.blendMode = .plusLighter
        let trails: [(Color, Double)] = [(Color(hex: 0x3B8CF2), Double.pi), (Color(hex: 0xFDAC65), 0)]
        for (col, ph) in trails {
            for n in 0..<12 {
                let q = FusionDance.clamp(wp - Double(n) * 0.018)
                let ang = ph + q * 7.5
                let rad = CGFloat(1 - LivingVector.easeInOutCubic(q)) * 0.95 * size + 6
                let c = CGPoint(x: centre.x + CGFloat(cos(ang)) * rad, y: centre.y + CGFloat(sin(ang)) * rad * 0.62)
                let r = 2.6 - CGFloat(n) * 0.14
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(col.opacity((1 - Double(n) / 12) * sin(Double.pi * wp) * 0.95)))
            }
        }
    }
}
