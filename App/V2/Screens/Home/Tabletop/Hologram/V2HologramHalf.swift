import SwiftUI
import FusionhaKit

/// One half of the hologram scene, as its own layer clipped to the half
/// (the approved mock's B2, `drawHolo`, with the hinge fix's `FL`
/// branches). Nothing solid crosses the hinge (owner, 2026-11-15): drawn on
/// both halves from one fixed eye, a standing thing creased at the hinge
/// from anywhere else. So every poster and glass slice is drawn on the top
/// half only (the slab floats clear of the hinge, the waiting titles stand
/// behind it), with the wall, the floor behind the hinge and the halo; the
/// bottom half is the floor itself: the ring and the contact shadow under
/// the slab (`V2HologramFloor`). Soft light may reach the table: the beam
/// (its piece there at `TabletopScene.tableBeam`) and the waiting titles'
/// reflections, which fade out either side of the hinge (`hingeFade`). `moment` is where the lift and
/// the print-in have got to: during the lift the top half's posters are on
/// their way from the flat carousel's places and the rest comes on in stages.
struct V2HologramHalf: View {
    let half: V2HologramRig.Half
    let rig: V2HologramRig
    let placed: [V2HologramPlaced]
    let look: V2HologramLook
    var moment = V2HologramMoment()

    private var box: CGSize { V2HologramArt.box }
    private var light: CGSize { CGSize(width: CGFloat(TabletopScene.lightSide), height: CGFloat(TabletopScene.lightSide)) }
    /// The title nearest the focus: the one the beam and the halo belong to.
    private var lead: V2HologramPlaced? { placed.max { $0.card.focus < $1.card.focus } }
    private var stages: TabletopLift.Stages { moment.stages }
    /// The beam's piece seen against the table comes on last.
    private var twin: Bool { half == .bottom }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The room itself is behind the scene (`V2HologramRoom`).
            switch half {
            case .top:
                backdrop
                ForEach(placed) { piece($0) }
            case .bottom:
                table
            }
            if let lead {
                beam(lead)
                if half == .top, stages.progress >= 1, lead.reveal > 0.02, lead.reveal < 0.98 { scan(lead) }
            }
        }
        .frame(width: rig.size.width, height: rig.height(of: half), alignment: .topLeading)
        .clipped()
    }

    // MARK: The top half

    @ViewBuilder
    private var backdrop: some View {
        // The title's light on the wall, rising from the hinge.
        EllipticalGradient(stops: [.init(color: look.tint.opacity(look.wallGlow), location: 0),
                                   .init(color: look.tint.opacity(0), location: 0.74)])
            .frame(width: rig.size.width * 1.24, height: rig.hingeY * 1.48)
            .position(x: rig.size.width / 2, y: rig.hingeY)
            .opacity(stages.floor)
        // Wider than the display, so its sides are off it and only its
        // soft back edge is on the wall.
        let pad = CGSize(width: CGFloat(TabletopScene.floorBehindWidth), height: CGFloat(TabletopScene.floorDepth))
        V2HologramFloor(part: .behind, look: look, size: pad, ring: moment.print.ring, spin: moment.spin)
            .hologramPiece(rig.transform(TabletopScene.floorBehind, on: .top, from: pad), box: pad)
            .opacity(stages.floor)
        reflections
        if let lead {
            // The pool behind the slab, under everything that stands: the
            // slab keeps its edge against a room in its own colours.
            RadialGradient(stops: [.init(color: look.shade.opacity(look.shadeCore), location: 0.3),
                                   .init(color: look.shade.opacity(look.shadeMid), location: 0.62),
                                   .init(color: look.shade.opacity(0), location: 1)],
                           center: .center, startRadius: 0, endRadius: light.width / 2)
                .hologramPiece(rig.transform(lead.card.shade, on: .top, from: light), box: light)
                .frame(width: rig.size.width, height: rig.hingeY, alignment: .topLeading)
                // The pool is taller than the half. Cut off at the bar and at
                // the hinge it left an edge at both, so it fades out before them.
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22),
                                           .init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .opacity(lead.card.shadeOpacity * moment.print.slab * stages.depth)
            RadialGradient(colors: [look.tint.opacity(look.haloGlow), look.tint.opacity(0)],
                           center: .center, startRadius: 0, endRadius: light.width / 2)
                .hologramPiece(rig.transform(lead.card.halo, on: .top, from: light), box: light)
                .opacity(lead.card.haloOpacity * moment.print.slab * stages.depth)
                .blendMode(look.lightBlend)
                .zIndex(lead.order - 8)
        }
    }

    // MARK: The bottom half

    @ViewBuilder
    private var table: some View {
        // The light spilling over the hinge onto the table.
        EllipticalGradient(stops: [.init(color: look.tint.opacity(look.spillGlow), location: 0),
                                   .init(color: look.tint.opacity(0), location: 0.78)])
            .frame(width: rig.size.width * 1.24, height: rig.bottomHeight * 1.56)
            .position(x: rig.size.width / 2, y: 0)
            .opacity(stages.floor)
        let scale = CGFloat(rig.scale)
        let plate = CGSize(width: CGFloat(TabletopProjection.designWidth), height: rig.bottomHeight / max(scale, 0.01))
        // The contact shadow lies under the ring's glow (the floor draws it).
        V2HologramFloor(part: .front, look: look, size: plate, ring: moment.print.ring, spin: moment.spin,
                        contact: lead?.card.contact,
                        contactOpacity: (lead?.card.contactOpacity ?? 0) * moment.print.slab * stages.depth,
                        dialTurn: moment.dialTurn, dialHeld: moment.dialHeld, tick: lead?.id)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: rig.size.width, height: rig.bottomHeight, alignment: .topLeading)
            .opacity(stages.floor)
        reflections
    }

    /// The waiting titles' reflections on the floor, behind the hinge on the
    /// top half and in front of it on the bottom one, faded out either side
    /// of the hinge.
    private var reflections: some View {
        ZStack(alignment: .topLeading) {
            ForEach(placed) { reflection($0) }
        }
        .frame(width: rig.size.width, height: rig.height(of: half), alignment: .topLeading)
        .mask { hingeFade }
        .blendMode(look.lightBlend)
    }

    /// The title's mirror image where it lands on the table: the soft copy,
    /// strongest at its feet.
    @ViewBuilder
    private func reflection(_ item: V2HologramPlaced) -> some View {
        if let soft = item.art?.soft, item.card.focus < 0.98 {
            Image(uiImage: soft)
                .resizable()
                .interpolation(.high)
                .frame(width: box.width, height: box.height)
                .mask {
                    // Soft at the feet and the sides (the mock blurs it once),
                    // and gone before the page dots and the controls.
                    let reach = TabletopScene.reflectionReach
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                                           .init(color: .black.opacity(0.8), location: reach * 0.16),
                                           .init(color: .black.opacity(0.34), location: reach * 0.5),
                                           .init(color: .black.opacity(0.1), location: reach * 0.78),
                                           .init(color: .clear, location: reach)],
                                   startPoint: .bottom, endPoint: .top)
                }
                .mask { softSides }
                .hologramPiece(rig.transform(rig.floorQuad(item.card.corners(mirrored: true), on: half), from: box), box: box)
                // None for the slab (`TabletopScene.Card.reflectionOpacity`).
                .opacity(item.opacity * item.reveal * (0.22 + 0.6 * item.card.focus) * (1 - item.card.focus)
                         * stages.reflection * look.reflection)
        }
    }

    // MARK: Both halves

    /// The reflections fade out over the last 24 pt either side of the
    /// hinge, so they draw no line there.
    private var hingeFade: some View {
        let height = max(rig.height(of: half), 1), fade = min(24 / height, 0.5)
        let stops: [Gradient.Stop] = half == .top
            ? [.init(color: .black, location: 0), .init(color: .black, location: 1 - fade), .init(color: .clear, location: 1)]
            : [.init(color: .clear, location: 0), .init(color: .black, location: fade), .init(color: .black, location: 1)]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    /// Where a piece of a title is drawn on the top half (the only half
    /// titles are drawn on): where the eye sees `corners`, and during the
    /// lift, that far from the title's poster in the flat carousel.
    private func place(_ corners: [TabletopVec], of item: V2HologramPlaced) -> ProjectionTransform {
        let scene = rig.quad(corners, on: .top)
        guard let flat = item.flatQuad else { return rig.transform(scene, from: box) }
        return rig.transform(TabletopLift.mix(flat, scene, stages.corners), from: box)
    }

    /// A title on the top half: the slab's glass slices, then its poster.
    @ViewBuilder
    private func piece(_ item: V2HologramPlaced) -> some View {
        let card = item.card
        let seen: Double = item.opacity
        let glass: Double = seen * card.focus * stages.depth
        if card.hasSlices {
            ForEach(0..<TabletopScene.sliceCount, id: \.self) { index in
                V2HologramPlate(image: item.art?.poster, wash: look.slice, washOpacity: look.sliceOpacity,
                                reveal: item.reveal)
                    .hologramPiece(place(card.slice(index, thickness: stages.depth), of: item), box: box)
                    .opacity(glass)
                    .zIndex(item.order - 1 - Double(index))
            }
        }
        // A waiting title is drawn as light: the focused title's colour over
        // its art. It takes the light as it leaves the carousel.
        let arrived: Double = stages.corners
        let ghost: Double = card.ghost * arrived
        // The carousel card's look (its corner radius and shadow, at the
        // plate's size), while the poster is still partly in the carousel.
        let carousel: CGFloat? = item.flatWidth.map { box.width / CGFloat(max($0, 1)) }
        let grown: CGFloat = carousel ?? 1
        let radius: CGFloat = V2HologramArt.cornerRadius * (1 + (grown - 1) * CGFloat(1 - arrived))
        let front: Double = stages.keepsCarouselOrder ? 700 - abs(card.offset) * 10 : item.order
        V2HologramPlate(image: item.art?.poster, wash: look.tint, washOpacity: ghost, washBlend: .color,
                        edge: look.ring.opacity(0.8 * arrived), reveal: item.reveal, radius: radius,
                        shadow: carousel == nil ? 0 : 1 - arrived, shadowScale: grown)
            .brightness(look.isLight ? 0 : ghost * 0.1)
            .hologramPiece(place(card.corners(), of: item), box: box)
            .opacity(seen)
            .zIndex(front)
    }

    /// A mask that fades a piece out toward its left and right edges.
    private var softSides: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.16),
                               .init(color: .black, location: 0.84), .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }

    /// The beam from the emitter up to the floating slab: a gradient with
    /// soft edges. Its piece on the table is quieter (`tableBeam`).
    private func beam(_ item: V2HologramPlaced) -> some View {
        let hot = look.isLight ? look.tint.opacity(0.7) : look.tint.mix(with: .white, by: 0.4)
        let mid = look.tint.opacity(look.isLight ? 0.3 : 0.55)
        return LinearGradient(stops: [.init(color: hot, location: 0), .init(color: mid, location: 0.34),
                                      .init(color: look.tint.opacity(0), location: 1)],
                              startPoint: .bottom, endPoint: .top)
            .mask { softSides }
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.14),
                                       .init(color: .black, location: 1)], startPoint: .bottom, endPoint: .top)
            }
            .hologramPiece(rig.transform(item.card.beam, on: half, from: light), box: light)
            .opacity(item.card.beamOpacity * moment.print.beam
                     * (twin ? stages.twins * TabletopScene.tableBeam : stages.depth))
            .blendMode(look.lightBlend)
            .zIndex(item.order + 1)
    }

    /// The print-in's scan bar, across the slab at the height it is printed to.
    private func scan(_ item: V2HologramPlaced) -> some View {
        V2HologramScan(look: look)
            .hologramPiece(rig.transform(item.card.scanBar(reveal: item.reveal, half: V2HologramScan.reach),
                                         on: half, from: V2HologramScan.box), box: V2HologramScan.box)
            .opacity(item.card.focus)
            .zIndex(900)
            .transition(.identity)
    }
}
