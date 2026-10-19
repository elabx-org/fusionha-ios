import SwiftUI

// The fx-canvas half of the media morphs (media-moves.ts `tv`, `anime`):
// the TV's screen, antennae and scanline; Anime's speed lines, impact,
// sparkles at the blade tips and falling petals.

extension LivingMedia {
    static func draw(_ show: LivingMediaShow, in ctx: inout GraphicsContext, ms t: Double, mark: CGRect,
                     tips: [CGPoint]) {
        switch show.kind {
        case .tv: drawTV(&ctx, t, mark)
        case .anime: drawAnime(&ctx, t, mark, tips, show.petals)
        }
    }

    private static func drawTV(_ ctx: inout GraphicsContext, _ t: Double, _ mark: CGRect) {
        let s = mark.width
        let a = sstep(0, 600, t) * (1 - sstep(3050, 3500, t))
        guard a > 0.001 else { return }
        let cx = mark.minX + 0.5 * s, cy = mark.minY + 0.55 * s
        let w = 0.98 * s, h = 0.76 * s
        let screen = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        let frame = Path(roundedRect: screen, cornerRadius: 0.1 * s)
        var layer = ctx
        layer.opacity = a
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

    private static func drawAnime(_ ctx: inout GraphicsContext, _ t: Double, _ mark: CGRect, _ tips: [CGPoint],
                                  _ petals: [LivingMediaShow.Petal]) {
        let s = mark.width
        let cx = mark.midX, cy = mark.midY
        if t < 520 {
            let a = 1 - t / 520
            let k = min(1, t / 360)
            let dash = CGFloat(1 - easeOut(k)) * -0.45 * s
            for i in 0..<16 {
                let y = cy + CGFloat((i * 37) % 17 - 8) * 0.06 * s
                let len = (0.5 + CGFloat((i * 53) % 7) / 7) * s
                let x = cx + dash - 0.35 * s - CGFloat((t * 0.9 + Double(i) * 40).truncatingRemainder(dividingBy: Double(0.5 * s)))
                var line = Path()
                line.move(to: CGPoint(x: x, y: y))
                line.addLine(to: CGPoint(x: x - len, y: y))
                ctx.stroke(line, with: .color(Color(red: 220 / 255, green: 230 / 255, blue: 1).opacity(0.55 * a)),
                           lineWidth: i % 3 == 0 ? 2 : 1)
            }
        }
        if t > 360 && t < 800 {
            let a = 1 - (t - 360) / 440
            for i in 0..<36 {
                let an = Double(i) / 36 * 2 * .pi + Double(i % 2) * 0.05
                let r0 = 0.62 * s + CGFloat((i * 29) % 5) * 0.04 * s
                let r1 = 1.4 * s
                var ray = Path()
                ray.move(to: CGPoint(x: cx + CGFloat(cos(an)) * r0, y: cy + CGFloat(sin(an)) * r0))
                ray.addLine(to: CGPoint(x: cx + CGFloat(cos(an)) * r1, y: cy + CGFloat(sin(an)) * r1))
                ctx.stroke(ray, with: .color(.white.opacity(0.42 * a)), lineWidth: CGFloat(1 + i % 3))
            }
        }
        if t > 650 {
            let out = 1 - sstep(2600, 3000, t)
            for (i, tip) in tips.enumerated() {
                let ph = (t - 650 - Double(i) * 180) / 520
                guard ph > 0 else { continue }
                let a = max(0, sin(min(.pi, ph * .pi))) * out
                star(&ctx, CGPoint(x: tip.x + 8, y: tip.y - 6), CGFloat(13 + Double(i % 2) * 6) * CGFloat(a) + 0.01,
                     ph * 1.4, a)
            }
        }
        for petal in petals where t < petal.life {
            let alpha = min(1, (petal.life - t) / petal.fade)
            let p = CGPoint(x: petal.origin.x + petal.velocity.dx * CGFloat(t), y: petal.origin.y + petal.velocity.dy * CGFloat(t))
            var leaf = ctx
            leaf.translateBy(x: p.x, y: p.y)
            leaf.rotate(by: .radians(petal.angle + petal.spin * t))
            leaf.fill(Path(ellipseIn: CGRect(x: -petal.radius, y: -petal.radius * 0.55, width: petal.radius * 2,
                                             height: petal.radius * 1.1)),
                      with: .color(Color(red: 1, green: 170 / 255, blue: 205 / 255).opacity(0.85 * alpha)))
        }
    }

    /// An eight-point sparkle (draw.ts `star`).
    private static func star(_ ctx: inout GraphicsContext, _ at: CGPoint, _ r: CGFloat, _ rot: Double, _ a: Double) {
        guard a > 0.001 else { return }
        var path = Path()
        for i in 0..<8 {
            let rr = i % 2 == 1 ? r * 0.22 : r
            let an = Double(i) / 8 * 2 * .pi
            let point = CGPoint(x: CGFloat(cos(an)) * rr, y: CGFloat(sin(an)) * rr)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        var layer = ctx
        layer.translateBy(x: at.x, y: at.y)
        layer.rotate(by: .radians(rot))
        layer.addFilter(.shadow(color: Color(red: 200 / 255, green: 220 / 255, blue: 1).opacity(0.9), radius: 6))
        layer.fill(path, with: .color(.white.opacity(a)))
    }
}
