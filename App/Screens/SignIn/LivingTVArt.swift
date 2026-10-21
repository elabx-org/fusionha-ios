import SwiftUI

/// The `tv` move's drawing (web `living/tv-art.ts`): the brand-gradient screen
/// frame, the antennae with their knobs, the feet, the scan line and the CRT
/// dot, plus the pose it gives the F inside at a move-time `t` (ms). Shared by
/// the `tv` move and the Movies × Series fusion move, so both draw the same TV.
enum LivingTVArt {
    /// Move length; the frame fades in over 0–600 and out over 3050–3500.
    static let ms = 3500.0

    struct Pose {
        /// Frame opacity.
        var a: Double
        /// Mark offset down, as a fraction of the mark size.
        var ty: Double
        /// Mark scale (x, y) about its centre: the shrink into the screen × the CRT squash.
        var kx: Double, ky: Double
        /// Mark brightness (the CRT off/on flare), 1 = none.
        var br: Double
    }

    static let brand = Gradient(stops: [.init(color: Color(hex: 0x3B8CF2), location: 0),
                                        .init(color: Color(hex: 0xC256B9), location: 0.55),
                                        .init(color: Color(hex: 0xFDBA61), location: 1)])

    /// Where the F sits inside the TV at move-time `t`.
    static func pose(_ t: Double) -> Pose {
        let sstep = LivingQuality.sstep, easeOut = LivingMedia.easeOut
        let a = sstep(0, 600, t) * (1 - sstep(3050, 3500, t))
        let sc = 1 - 0.36 * a
        var sx = 1.0, sy = 1.0, br = 1.0
        if t > 1700 && t <= 2000 {
            sy = 1 - 0.98 * easeOut((t - 1700) / 300); br = 1.8
        } else if t > 2000 && t <= 2200 {
            sy = 0.02; sx = 1 - easeOut((t - 2000) / 200); br = 2
        } else if t > 2200 && t <= 2500 {
            sx = 0; sy = 0.02
        } else if t > 2500 && t <= 2950 {
            let k = (t - 2500) / 450
            sx = easeOut(k * 1.6)
            sy = k < 0.4 ? 0.02 : 0.02 + 0.98 * easeOut((k - 0.4) / 0.6) * (1 + 0.08 * sin((k - 0.4) * 9) * (1 - k))
            br = 1.4
        }
        return Pose(a: a, ty: 0.05 * a, kx: sc * sx, ky: sc * sy, br: br)
    }

    /// Paint the TV at move-time `t` for a mark of `s` px whose box starts at `origin`.
    static func paint(_ ctx: inout GraphicsContext, _ t: Double, s: CGFloat, origin: CGPoint) {
        let a = pose(t).a
        guard a > 0.001 else { return }
        let sstep = LivingQuality.sstep
        let cx = origin.x + 0.5 * s, cy = origin.y + 0.55 * s
        let w = 0.98 * s, h = 0.76 * s
        let screen = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        let frame = Path(roundedRect: screen, cornerRadius: 0.1 * s)
        var layer = ctx
        layer.opacity *= a
        layer.blendMode = .normal
        let shade = GraphicsContext.Shading.linearGradient(brand, startPoint: screen.origin,
                                                           endPoint: CGPoint(x: screen.maxX, y: screen.maxY))
        layer.fill(frame, with: .color(.white.opacity(0.025)))
        layer.stroke(frame, with: shade, lineWidth: 3.2)
        let grow = CGFloat(sstep(200, 700, t))
        var legs = Path()
        for d: CGFloat in [-1, 1] {
            let tip = CGPoint(x: cx + d * (0.04 + 0.2 * grow) * s, y: screen.minY - 0.26 * s * grow)
            legs.move(to: CGPoint(x: cx + d * 0.04 * s, y: screen.minY))
            legs.addLine(to: tip)
            layer.fill(Path(ellipseIn: CGRect(x: tip.x - 4 * grow, y: tip.y - 4 * grow, width: 8 * grow, height: 8 * grow)),
                       with: .linearGradient(brand, startPoint: screen.origin, endPoint: CGPoint(x: screen.maxX, y: screen.minY)))
            legs.move(to: CGPoint(x: cx + d * 0.3 * s, y: screen.maxY))
            legs.addLine(to: CGPoint(x: cx + d * 0.36 * s, y: screen.maxY + 0.07 * s))
        }
        layer.stroke(legs, with: shade, lineWidth: 2.4)
        if t > 700 && t < 1550 {
            let y = screen.minY + CGFloat((t - 700) / 850) * h
            var clipped = layer
            clipped.clip(to: frame)
            let band = CGRect(x: screen.minX, y: y - 0.05 * s, width: w, height: 0.1 * s)
            clipped.fill(Path(band), with: .linearGradient(
                Gradient(colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0)]),
                startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
        }
        if t > 2150 && t < 2560 {
            let k = (t - 2150) / 410
            let r = 3.5 * CGFloat(1 - k * 0.5)
            var dot = layer
            dot.addFilter(.shadow(color: Color(hex: 0xC4B5FD), radius: 8))
            dot.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(1 - k * 0.6)))
        }
    }
}
