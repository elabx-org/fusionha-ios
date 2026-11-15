import SwiftUI
import FusionhaKit

/// The emitter the focused title stands over and the track the others wait
/// on, centred on the ring's centre, lit in the title's colour. The glow is
/// a gradient, not a blur. The dashed inner ring turns while the scene idles.
/// On the table the rim is also a dial (tabletop plan, slice 6; the hinge-fix
/// mock's `.dial`): notches every 20° that turn with the focus (40° a title,
/// however it is turned), one fixed marker at the far side, and a short
/// flash each time the nearest title changes (not under Reduce Motion).
struct V2HologramRing: View {
    let look: V2HologramLook
    /// The track's glow and the dial (only on the half the ring lies on).
    let glows: Bool
    /// The dashed inner ring's turn (radians): it goes slowly round.
    var spin: Double = 0
    /// The dial's notches' turn (radians) and whether a finger holds it.
    var dialTurn: Double = 0
    var dialHeld = false
    /// The nearest title: the ring flashes when it changes.
    var tick: Int?
    @Environment(\.motionEnabled) private var motion

    /// The round track the waiting titles stood on. Since the hinge fix
    /// they stand behind the hinge, so it is not drawn.
    static let showsTrack = false

    private let emitter = CGFloat(TabletopScene.emitterRadius)
    private let track = CGFloat(TabletopScene.trackRadius)
    /// The dial's outer edge (the mock's dial, 24 pt past the rim).
    private var dial: CGFloat { emitter + CGFloat(TabletopDial.band) }

    var body: some View {
        ZStack {
            if Self.showsTrack {
                if glows { glow(radius: track, spread: 26, opacity: 0.32) }
                Circle().strokeBorder(look.ring.opacity(0.55), lineWidth: 1.5)
                    .frame(width: track * 2, height: track * 2)
            }
            emitterRing
                .keyframeAnimator(initialValue: 0.0, trigger: motion ? tick : nil) { content, flash in
                    content.brightness(flash)
                } keyframes: { _ in
                    KeyframeTrack {
                        MoveKeyframe(look.isLight ? 0.18 : 0.32)
                        CubicKeyframe(0, duration: 0.24)
                    }
                }
            if glows { notches }
        }
        .frame(width: (track + 30) * 2, height: (track + 30) * 2)
    }

    private var emitterRing: some View {
        ZStack {
            glow(radius: emitter, spread: 30, opacity: look.isLight ? 0.5 : 0.75)
            Circle().strokeBorder(look.ring, lineWidth: 3.5)
                .frame(width: emitter * 2, height: emitter * 2)
            Circle().strokeBorder(look.ring.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, dash: [9, 7]))
                .frame(width: (emitter - 24) * 2, height: (emitter - 24) * 2)
                .rotationEffect(.radians(spin))
            RadialGradient(stops: [.init(color: look.core, location: 0),
                                   .init(color: look.tint.opacity(look.isLight ? 0.4 : 0.7), location: 0.55),
                                   .init(color: look.tint.opacity(0), location: 0.72)],
                           center: .center, startRadius: 0, endRadius: emitter - 66)
                .frame(width: (emitter - 66) * 2, height: (emitter - 66) * 2)
        }
    }

    /// The notches (the mock's band 88.5%–98% of the dial's radius) and the
    /// marker at the far side, 20 tall from 7 past the dial's edge.
    private var notches: some View {
        ZStack {
            V2HologramNotches(inner: dial * 0.885, outer: dial * 0.98)
                .stroke(look.ring, lineWidth: 5)
                .opacity(dialHeld ? 1 : 0.75)
                .rotationEffect(.radians(dialTurn))
                .frame(width: dial * 2, height: dial * 2)
            Capsule()
                .fill(look.marker)
                .frame(width: 4, height: 20)
                .shadow(color: look.tint.opacity(0.8), radius: 4)
                .offset(y: -(dial + 7 - 10))
        }
    }

    /// A soft band of the title's light either side of a circle.
    private func glow(radius: CGFloat, spread: CGFloat, opacity: Double) -> some View {
        let outer = radius + spread
        return RadialGradient(stops: [.init(color: look.tint.opacity(0), location: (radius - spread) / outer),
                                      .init(color: look.tint.opacity(opacity), location: radius / outer),
                                      .init(color: look.tint.opacity(0), location: 1)],
                              center: .center, startRadius: 0, endRadius: outer)
            .frame(width: outer * 2, height: outer * 2)
    }
}

/// The dial's notches: a short radial line every 20°, the first at the top
/// (the far side), between `inner` and `outer` from the centre.
private struct V2HologramNotches: Shape {
    let inner: CGFloat
    let outer: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let count = Int((2 * Double.pi / TabletopDial.notchStep).rounded())
        for index in 0..<count {
            let angle = Double(index) * TabletopDial.notchStep - Double.pi / 2
            let along = CGPoint(x: cos(angle), y: sin(angle))
            path.move(to: CGPoint(x: centre.x + along.x * inner, y: centre.y + along.y * inner))
            path.addLine(to: CGPoint(x: centre.x + along.x * outer, y: centre.y + along.y * outer))
        }
        return path
    }
}
