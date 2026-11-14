import SwiftUI
import FusionhaKit

/// The hologram's floor, drawn flat in the scene's own points (669 wide):
/// the grid, the pool of the focused title's light and the ring. One plate
/// is the bottom half itself (the table in front of the hinge); another is
/// the floor behind the hinge, which the scene tips onto the top half so the
/// grid and the ring carry on across the fold. Content, never glass.
struct V2HologramFloor: View {
    enum Part {
        /// In front of the hinge: the bottom half. Fades out toward the viewer.
        case front
        /// Behind the hinge, seen on the top half. Fades out toward the back.
        case behind
    }

    let part: Part
    let look: V2HologramLook
    /// The plate's size in the scene's points; the hinge is its top edge
    /// (front) or its bottom edge (behind).
    let size: CGSize
    /// How far the ring has come on (the print-in) and the dashed ring's turn.
    var ring: Double = 1
    var spin: Double = 0

    /// The hinge's y in the plate.
    private var hingeY: CGFloat { part == .front ? 0 : size.height }
    private var ringY: CGFloat { hingeY + CGFloat(TabletopScene.ringZ) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground.mask { fade }
            V2HologramRing(look: look, glows: part == .front, spin: spin)
                .position(x: size.width / 2, y: ringY)
                .opacity(ring)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    private var ground: some View {
        ZStack {
            look.floor
            pool
            V2HologramGrid().stroke(look.grid, lineWidth: 1.5)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The title's light on the floor: under the ring in front, spilling
    /// back from the hinge behind.
    private var pool: some View {
        let radius = part == .front ? CGSize(width: size.width * 0.5, height: 200) : CGSize(width: size.width * 0.5, height: size.height * 0.6)
        let opacity = part == .front ? look.floorGlow : look.padGlow
        return EllipticalGradient(colors: [look.tint.opacity(opacity), look.tint.opacity(0)])
            .frame(width: radius.width * 2, height: radius.height * 2)
            .position(x: size.width / 2, y: part == .front ? ringY : hingeY)
    }

    private var fade: some View {
        switch part {
        case .front:
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.52),
                                   .init(color: .clear, location: 0.8)], startPoint: .top, endPoint: .bottom)
        case .behind:
            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.58),
                                   .init(color: .clear, location: 0.98)], startPoint: .bottom, endPoint: .top)
        }
    }
}

/// The floor's grid: a line every 44 pt going back and twelve columns across
/// the 669-pt display, so the two plates' lines meet at the hinge.
private struct V2HologramGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y = rect.minY
        while y <= rect.maxY + 0.5 {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += 44
        }
        let step = CGFloat(TabletopProjection.designWidth / 12)
        var x = rect.minX
        while x <= rect.maxX + 0.5 {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        return path
    }
}

/// The emitter the focused title stands over and the track the others wait
/// on, centred on the ring's centre, lit in the title's colour. The glow is
/// a gradient, not a blur. The dashed inner ring turns while the scene idles.
struct V2HologramRing: View {
    let look: V2HologramLook
    /// The track's glow (only on the half the ring lies on).
    let glows: Bool
    /// The dashed inner ring's turn (radians): it goes slowly round.
    var spin: Double = 0

    private let emitter = CGFloat(TabletopScene.emitterRadius)
    private let track = CGFloat(TabletopScene.trackRadius)

    var body: some View {
        ZStack {
            if glows { glow(radius: track, spread: 26, opacity: 0.32) }
            Circle().strokeBorder(look.ring.opacity(0.55), lineWidth: 1.5)
                .frame(width: track * 2, height: track * 2)
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
        .frame(width: (track + 30) * 2, height: (track + 30) * 2)
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
