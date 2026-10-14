import SwiftUI
import UIKit

// MARK: - View (living/LivingMark.tsx)

/// The Living logo art panel: the dot field behind, the F's three blades inside
/// a tilt wrapper (with the unlock glint), a soft floor shadow, the optional
/// wordmark/tagline caption, and the fx canvas in front. Reduce Motion paints
/// the plain logo on a still dot field.
struct LivingMark<Caption: View>: View {
    let engine: LivingEngine
    let reduce: Bool
    @ViewBuilder var caption: Caption

    /// Where the three blades are cut from the logo (fraction of its height).
    private static var seams: [CGFloat] { [0.356, 0.658] }
    private static var feather: CGFloat { 0.03 }
    private static var space: String { "living-art" }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduce)) { context in
            let _ = engine.advance(to: context.date)
            ZStack {
                Canvas { ctx, size in drawDots(ctx, size) }
                VStack(spacing: 0) {
                    markView
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { engine.markRect = $0 }
                    Ellipse()
                        .fill(RadialGradient(colors: [.black.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 50))
                        .frame(width: 100, height: 18)
                        .padding(.top, 10)
                    caption
                }
                .modifier(PoseEffect(pose: engine.art.pose(at: engine.now)))
                if !reduce {
                    Canvas { ctx, _ in drawFx(ctx) }
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x08090D))
        .clipped()
        .coordinateSpace(.named(Self.space))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { engine.panel = $0 }
        .onAppear { engine.start(reduce: reduce) }
        .onDisappear { engine.stop() }
    }

    // MARK: Mark

    @ViewBuilder
    private var markView: some View {
        let mark = engine.mark.pose(at: engine.now)
        let hidden = engine.qualityStart != nil
        Group {
            if reduce {
                Image("BrandLogo").resizable().scaledToFit()
            } else {
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        blade(i)
                    }
                    sheen
                }
            }
        }
        .frame(width: 118, height: 118)
        .brightness(mark.light * 0.45)
        .rotation3DEffect(.degrees(mark.rotY), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .scaleEffect(mark.scale)
        .offset(y: mark.dy)
        .opacity(hidden ? 0 : 1)
        // The tilt wrapper: a gentle bob, turned toward the form while listening.
        .rotation3DEffect(.degrees(Double(-engine.tilt.y) * 9), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(Double(engine.tilt.x) * 14), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .offset(y: engine.bob)
        .accessibilityElement()
        .accessibilityLabel("fusionha")
        .accessibilityAddTraits(.isImage)
    }

    private func blade(_ i: Int) -> some View {
        let pose = engine.blades[i].pose(at: engine.now)
        let anchor = UnitPoint(x: 0.2, y: 0.5)
        return Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .mask(bladeMask(i))
            .colorMultiply(pose.jam > 0 ? Color(red: 1, green: 1 - 0.32 * pose.jam, blue: 1 - 0.7 * pose.jam) : .white)
            .brightness(pose.light * 0.45)
            .scaleEffect(pose.scale, anchor: anchor)
            .rotationEffect(.degrees(pose.rot), anchor: anchor)
            .offset(x: pose.dx + engine.pinX[i], y: pose.dy)
    }

    /// `bladeMask`: blade 0 is the top band; each lower band feathers in over the one above.
    private func bladeMask(_ i: Int) -> LinearGradient {
        let seams = Self.seams, f = Self.feather
        let stops: [Gradient.Stop]
        switch i {
        case 0:
            stops = [.init(color: .black, location: 0), .init(color: .black, location: seams[0]),
                     .init(color: .clear, location: seams[0]), .init(color: .clear, location: 1)]
        case 1:
            stops = [.init(color: .clear, location: 0), .init(color: .clear, location: seams[0] - f),
                     .init(color: .black, location: seams[0]), .init(color: .black, location: seams[1]),
                     .init(color: .clear, location: seams[1]), .init(color: .clear, location: 1)]
        default:
            stops = [.init(color: .clear, location: 0), .init(color: .clear, location: seams[1] - f),
                     .init(color: .black, location: seams[1]), .init(color: .black, location: 1)]
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    /// The "unlocked" glint: a bright band sweeping across, masked to the logo.
    @ViewBuilder
    private var sheen: some View {
        if let start = engine.sheenStart, engine.now >= start, engine.now <= start + 0.42 {
            let p = LivingEase.glint.value(at: (engine.now - start) / 0.42)
            GeometryReader { geo in
                let w = geo.size.width
                LinearGradient(stops: [.init(color: .clear, location: 0.4), .init(color: .white.opacity(0.6), location: 0.5),
                                       .init(color: .clear, location: 0.6)],
                               startPoint: UnitPoint(x: 0, y: 0.4), endPoint: UnitPoint(x: 1, y: 0.6))
                    .frame(width: w * 2.5)
                    // background-position 130% → -30% over a 250%-wide band.
                    .offset(x: -CGFloat(1.3 - 1.6 * p) * w * 1.5)
            }
            .mask(Image("BrandLogo").resizable().scaledToFit())
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }

    // MARK: Canvases

    /// The dot field (dot-field.ts): faint dots, brighter near the mark, with a
    /// ripple running out through them whenever a move lands.
    private func drawDots(_ ctx: GraphicsContext, _ size: CGSize) {
        let spacing: CGFloat = 16
        let c = engine.centre
        let t = engine.now
        let ripples = reduce ? [] : engine.ripples
        var y = spacing / 2
        while y < size.height {
            var x = spacing / 2
            while x < size.width {
                let d2 = Double((x - c.x) * (x - c.x) + (y - c.y) * (y - c.y))
                var alpha = 0.05 + 0.2 * exp(-d2 / (2 * 160 * 160))
                if !ripples.isEmpty {
                    let d = d2.squareRoot()
                    for r in ripples {
                        let age = (t - r) * 1000
                        let radius = age * 0.32
                        alpha += 0.55 * exp(-((d - radius) * (d - radius)) / (2 * 12 * 12)) * max(0, 1 - age / 1500)
                    }
                }
                ctx.fill(Path(CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)),
                         with: .color(Color(red: 170 / 255, green: 180 / 255, blue: 1).opacity(min(0.9, alpha))))
                x += spacing
            }
            y += spacing
        }
    }

    /// The fx canvas: spark trails, landing rings and the quality move's two copies.
    private func drawFx(_ ctx: GraphicsContext) {
        var ctx = ctx
        ctx.blendMode = .plusLighter
        drawQuality(&ctx)
        for spark in engine.sparks {
            let n = spark.trail.count
            for j in 1..<max(n, 1) where n > 1 {
                var p = Path()
                p.move(to: spark.trail[j - 1])
                p.addLine(to: spark.trail[j])
                let k = Double(j) / Double(n)
                ctx.stroke(p, with: .color(spark.color.opacity(k * 200 / 255)), lineWidth: CGFloat(2.2 * k))
            }
            if let head = spark.trail.last {
                let glow = Path(ellipseIn: CGRect(x: head.x - 7, y: head.y - 7, width: 14, height: 14))
                ctx.fill(glow, with: .radialGradient(Gradient(colors: [spark.color.opacity(0.7), .clear]),
                                                    center: head, startRadius: 0, endRadius: 7))
                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 2.2, y: head.y - 2.2, width: 4.4, height: 4.4)), with: .color(.white))
            }
        }
        for ring in engine.rings {
            let u = (engine.now - ring.start) / 0.56
            guard u < 1 else { continue }
            let r = 4 + ring.radius * CGFloat(1 - pow(1 - u, 3))
            ctx.stroke(Path(ellipseIn: CGRect(x: ring.center.x - r, y: ring.center.y - r, width: r * 2, height: r * 2)),
                       with: .color(ring.color.opacity((1 - u) * 200 / 255)), lineWidth: 1.6)
        }
    }

    private func drawQuality(_ ctx: inout GraphicsContext) {
        guard let start = engine.qualityStart,
              let q = LivingQuality.frame(ms: (engine.now - start) * 1000, size: engine.size, centre: engine.centre)
        else { return }
        let s = engine.size, c = engine.centre
        var plain = ctx
        plain.blendMode = .normal
        func copy(_ cx: CGFloat, _ size: CGFloat, _ res: Int, _ glow: Double) {
            let rect = CGRect(x: cx - size / 2, y: c.y - size / 2, width: size, height: size)
            let image: Image
            if res > 0, let px = LivingQuality.pixelated(res) {
                image = Image(uiImage: px).interpolation(.none)
            } else {
                image = Image("BrandLogo")
            }
            plain.drawLayer { layer in
                layer.opacity = q.fade
                if glow > 0 { layer.addFilter(.shadow(color: Color(hex: 0xA5F3FC).opacity(0.55 * glow), radius: CGFloat(11 * glow))) }
                layer.draw(image.resizable(), in: rect)
            }
        }
        copy(c.x - q.offset, s * q.scaleL, q.resL, 0)
        copy(c.x + q.offset, s * q.scaleR, q.resR, q.glowR)
        guard q.split > 0.6 else { return }
        let alpha = min(1, (q.split - 0.6) / 0.4)
        func bar(_ cx: CGFloat, _ y: CGFloat, _ w: CGFloat, _ fill: Double, _ flash: Double) {
            plain.drawLayer { layer in
                layer.opacity = alpha
                let track = Path(roundedRect: CGRect(x: cx - w / 2, y: y, width: w, height: 4), cornerRadius: 2)
                layer.fill(track, with: .color(.white.opacity(0.08)))
                if fill > 0 {
                    let bar = Path(roundedRect: CGRect(x: cx - w / 2, y: y, width: max(4, w * CGFloat(fill)), height: 4), cornerRadius: 2)
                    layer.fill(bar, with: .linearGradient(Gradient(stops: [.init(color: Color(hex: 0x3B8CF2), location: 0),
                                                                          .init(color: Color(hex: 0xC256B9), location: 0.55),
                                                                          .init(color: Color(hex: 0xFDBA61), location: 1)]),
                                                          startPoint: CGPoint(x: cx - w / 2, y: 0), endPoint: CGPoint(x: cx + w / 2, y: 0)))
                }
                if flash > 0 {
                    layer.addFilter(.shadow(color: .white, radius: 6))
                    layer.fill(track, with: .color(.white.opacity(flash)))
                }
            }
        }
        bar(c.x - q.offset, c.y + s * q.scaleL / 2 + 16, s * 0.62 * q.scaleL, q.fillL, q.flashL)
        bar(c.x + q.offset, c.y + s * q.scaleR / 2 + 16, s * 0.62 * q.scaleR, q.fillR, q.flashR)
    }
}

/// Applies a pose to the art wrapper (entrance + the unlock dive).
private struct PoseEffect: ViewModifier {
    let pose: LivingPose
    func body(content: Content) -> some View {
        content
            .scaleEffect(pose.scale)
            .offset(x: pose.dx, y: pose.dy)
            .opacity(pose.opacity)
    }
}
