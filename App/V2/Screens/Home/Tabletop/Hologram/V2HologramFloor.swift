import SwiftUI
import FusionhaKit

/// The hologram's floor, drawn flat in the scene's own points (669 wide):
/// the grid, the pool of the focused title's light, the slab's contact
/// shadow (in front) and the emitter ring. One plate
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
    /// (front) or its bottom edge (behind). Both are centred on the display.
    let size: CGSize
    /// How far the ring has come on (the print-in) and the dashed ring's turn.
    var ring: Double = 1
    var spin: Double = 0
    /// The floating slab's shadow on the table (front only), under the ring's glow.
    var contact: TabletopScene.Contact?
    var contactOpacity: Double = 0
    /// The dial on the ring's rim (front only): its turn, whether it is held,
    /// and the nearest title, whose change flashes the ring.
    var dialTurn: Double = 0
    var dialHeld = false
    var tick: Int?

    /// The hinge's y in the plate.
    private var hingeY: CGFloat { part == .front ? 0 : size.height }
    private var ringY: CGFloat { hingeY + CGFloat(TabletopScene.ringZ) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground.mask { fade }
            if part == .front, let contact, contactOpacity > 0 { shadow(contact) }
            V2HologramRing(look: look, glows: part == .front, spin: spin, dialTurn: dialTurn, dialHeld: dialHeld, tick: tick)
                .position(x: size.width / 2, y: ringY)
                .opacity(ring)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }

    /// The mock's `.cshadow`: an ellipse, darkest at its centre.
    private func shadow(_ contact: TabletopScene.Contact) -> some View {
        EllipticalGradient(stops: [.init(color: look.contact.opacity(look.contactCore), location: 0),
                                   .init(color: look.contact.opacity(look.contactMid), location: 0.55),
                                   .init(color: look.contact.opacity(0), location: 1)],
                           center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            .frame(width: CGFloat(contact.width), height: CGFloat(contact.depth))
            .position(x: size.width / 2 + CGFloat(contact.centerX), y: hingeY + CGFloat(contact.centerZ))
            .opacity(contactOpacity)
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
        // As wide as the display on both plates (the plate behind runs past it).
        let across = CGFloat(TabletopProjection.designWidth) * 0.5
        let radius = part == .front ? CGSize(width: across, height: 200) : CGSize(width: across, height: size.height * 0.6)
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
/// the 669-pt display, so the two plates' lines meet at the hinge (the plate
/// behind is whole columns wider either side, `TabletopScene.floorOverhang`).
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
