import SwiftUI
import FusionhaKit

/// The hologram's floor, drawn flat in the scene's own points (669 wide):
/// the grid, the pool of the focused title's light and the emitter ring
/// with its dial (in front). One plate
/// is the bottom half itself (the table in front of the hinge); another is
/// the floor behind the hinge, the room's floor, which the scene tips onto
/// the top half. The grid fades out either side of the fold so its lines
/// never visibly meet there (the stage bench: a line across the fold kinks
/// for one eye or the other). "At the fold" (`glass`) the front plate has
/// no pool and its grid is near white at full strength right up to the
/// fold: nothing stands across it there, and the black upright glass
/// mirrors it. Content, never glass.
struct V2HologramFloor: View {
    enum Part {
        /// In front of the hinge: the bottom half. Fades in from the fold and
        /// out toward the viewer.
        case front
        /// Behind the hinge, seen on the top half: the room's floor, out to
        /// its back wall. Fades out toward the fold.
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
    /// The dial on the ring's rim (front only): its turn, whether it is held,
    /// and the nearest title, whose change flashes the ring.
    var dialTurn: Double = 0
    var dialHeld = false
    var tick: Int?
    /// How far toward "At the fold" (`V2HologramStyle`).
    var glass: Double = 0

    /// The hinge's y in the plate.
    private var hingeY: CGFloat { part == .front ? 0 : size.height }
    private var ringY: CGFloat { hingeY + CGFloat(TabletopScene.ringZ) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground.mask { fade }
            V2HologramRing(look: look, glows: part == .front, spin: spin, dialTurn: dialTurn, dialHeld: dialHeld, tick: tick)
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
            V2HologramGrid(backEdge: part == .behind).stroke(grid, lineWidth: 1.5)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The grid's colour: "At the fold" near white at 0.9.
    private var grid: Color {
        glass <= 0 ? look.grid : look.grid.mix(with: look.tint.mix(with: .white, by: 0.85).opacity(0.9), by: glass)
    }

    /// The title's light on the floor: under the ring in front, spilling
    /// back from the hinge behind.
    private var pool: some View {
        // As wide as the display on both plates.
        let across = CGFloat(TabletopProjection.designWidth) * 0.5
        let radius = part == .front ? CGSize(width: across, height: 200) : CGSize(width: across, height: size.height * 0.6)
        let opacity = (part == .front ? look.floorGlow : look.padGlow) * (1 - glass)
        return EllipticalGradient(colors: [look.tint.opacity(opacity), look.tint.opacity(0)])
            .frame(width: radius.width * 2, height: radius.height * 2)
            .position(x: size.width / 2, y: part == .front ? ringY : hingeY)
    }

    /// The stage bench's masks. In front: nothing at the fold, in from 1.5%
    /// of the half's depth to 14% ("At the fold" whole from the fold), whole
    /// to 55%, gone by 96%. Behind: whole
    /// from the back wall to 64 pt before the fold, gone 9 pt before it.
    private var fade: LinearGradient {
        switch part {
        case .front:
            let near = 1 - glass
            return LinearGradient(stops: [.init(color: .black.opacity(glass), location: 0.015 * near),
                                          .init(color: .black, location: 0.14 * near),
                                          .init(color: .black, location: 0.55), .init(color: .clear, location: 0.96)],
                                  startPoint: .top, endPoint: .bottom)
        case .behind:
            let depth = max(size.height, 1)
            return LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 1 - 64 / depth),
                                          .init(color: .clear, location: 1 - 9 / depth)],
                                  startPoint: .top, endPoint: .bottom)
        }
    }
}

/// The floor's grid: a line every 44 pt going back and twelve columns across
/// the 669-pt display, counted from the hinge on both plates. Behind, the
/// plate's far edge is the back wall's foot (`backEdge`), so the line there
/// is drawn too.
private struct V2HologramGrid: Shape {
    var backEdge = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // From the hinge: the front plate's top edge, the plate behind's bottom.
        var y = backEdge ? rect.maxY : rect.minY
        let rows = Int((rect.height / 44).rounded(.down))
        for _ in 0...rows {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += backEdge ? -44 : 44
        }
        if backEdge {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
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
