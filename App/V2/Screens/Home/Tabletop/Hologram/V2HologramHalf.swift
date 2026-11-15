import SwiftUI
import FusionhaKit

/// One half of the hologram scene, as its own layer clipped to the half
/// (the approved mock's B2, `drawHolo`, with the seat mock's and the stage
/// bench's changes). The focused title stands on the table just in front
/// of the hinge: it is drawn on both halves from the viewer's eye
/// (`V2HologramRig.eye`), on the top half as it is seen against the upright
/// screen and on the bottom half as it is seen against the table, so its
/// two pieces meet at the fold (only its lowest tenth or so is on the
/// table). The waiting titles stand behind the hinge and are drawn on the
/// top half only. The top half also has the floor behind the hinge, the
/// room's lines (`V2HologramRoomLines`) and the halo; the bottom half is the
/// floor itself, with the ring (`V2HologramFloor`). Both halves have the
/// slab's contact shadow and its faint reflection on the floor
/// (`V2HologramContact`, `reflections`), and over everything the projection
/// light, whose glare across the fold hides the join (`V2HologramLight`).
/// `moment` is where the lift and the print-in have got to: during the lift
/// the top half's posters are on their way from the flat carousel's places
/// and the rest comes on in stages.
struct V2HologramHalf: View {
    let half: V2HologramRig.Half
    let rig: V2HologramRig
    let placed: [V2HologramPlaced]
    let look: V2HologramLook
    var moment = V2HologramMoment()

    private var box: CGSize { V2HologramArt.box }
    private var light: CGSize { CGSize(width: CGFloat(TabletopScene.lightSide), height: CGFloat(TabletopScene.lightSide)) }
    /// The title nearest the focus: the one the light and the halo belong to.
    private var lead: V2HologramPlaced? { placed.max { $0.card.focus < $1.card.focus } }
    private var stages: TabletopLift.Stages { moment.stages }
    /// The pieces seen against the table come on last.
    private var twin: Bool { half == .bottom }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The room itself is behind the scene (`V2HologramStage`).
            switch half {
            case .top:
                room
                ForEach(placed) { piece($0) }
            case .bottom:
                table
                // Only a title on its way to or at the focus reaches the table.
                ForEach(placed.filter(\.card.hasSlices)) { piece($0) }
            }
            if let lead {
                V2HologramLight(half: half, rig: rig, look: look, card: lead.card, strength: lightStrength(lead),
                                time: moment.beamTime)
                    .zIndex(950)
                if stages.progress >= 1, lead.reveal > 0.02, lead.reveal < 0.98 { scan(lead) }
            }
        }
        .frame(width: rig.size.width, height: rig.height(of: half), alignment: .topLeading)
        .clipped()
    }

    // MARK: The top half

    /// The floor behind the hinge, the room's lines, the contact shadow, the
    /// reflections and the halo.
    @ViewBuilder
    private var room: some View {
        // As wide as the room and as deep as its back wall: its sides are
        // the side walls' feet.
        let pad = CGSize(width: CGFloat(TabletopScene.floorBehindWidth), height: CGFloat(TabletopScene.floorDepth))
        V2HologramFloor(part: .behind, look: look, size: pad, ring: moment.print.ring, spin: moment.spin)
            .hologramPiece(rig.transform(TabletopScene.floorBehind, on: .top, from: pad), box: pad)
            .opacity(stages.floor)
        V2HologramRoomLines(rig: rig, look: look)
            .opacity(stages.floor)
        contact
        reflections
        if let lead {
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
        let scale = CGFloat(rig.scale)
        let plate = CGSize(width: CGFloat(TabletopProjection.designWidth), height: rig.bottomHeight / max(scale, 0.01))
        V2HologramFloor(part: .front, look: look, size: plate, ring: moment.print.ring, spin: moment.spin,
                        dialTurn: moment.dialTurn, dialHeld: moment.dialHeld, tick: lead?.id)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: rig.size.width, height: rig.bottomHeight, alignment: .topLeading)
            .opacity(stages.floor)
        contact
        reflections
    }

    /// The slab's contact shadow, under its foot, as it stands.
    @ViewBuilder
    private var contact: some View {
        if let lead, lead.card.hasSlices {
            V2HologramContact(half: half, rig: rig, look: look, card: lead.card,
                              strength: lead.opacity * lead.card.focus * moment.print.slab * stages.depth)
        }
    }

    /// The projection light's strength this frame: in over the lift's last
    /// third and with the print-in, dipping while the ring turns, breathing.
    private func lightStrength(_ lead: V2HologramPlaced) -> Double {
        TabletopBeam.focus(lead.card.focus) * moment.print.beam * TabletopBeam.lift(stages.progress)
            * moment.breath * look.beamStrength
    }

    /// The titles' reflections on the floor: the waiting ones' behind the
    /// hinge on the top half, the slab's in front of it on the bottom one
    /// (faint, and gone within 120 pt of its foot, `reachFade`), faded out
    /// either side of the hinge.
    private var reflections: some View {
        ZStack(alignment: .topLeading) {
            ForEach(placed) { reflection($0) }
        }
        .frame(width: rig.size.width, height: rig.height(of: half), alignment: .topLeading)
        .mask { hingeFade }
        .mask { reachFade }
        .blendMode(look.lightBlend)
    }

    /// On the table, the slab's reflection is whole to its foot and gone
    /// `slabReflectionReach` further out; the top half is untouched.
    private var reachFade: some View {
        let height = max(rig.height(of: half), 1)
        let foot = lead.map { rig.point(TabletopVec($0.card.centerX, 0, $0.card.centerZ), on: .bottom).y } ?? 0
        let start = min(max(foot / height, 0), 1)
        let end = min(start + Self.slabReflectionReach * CGFloat(rig.scale) / height, 1)
        let stops: [Gradient.Stop] = twin
            ? [.init(color: .black, location: 0), .init(color: .black, location: start), .init(color: .clear, location: end)]
            : [.init(color: .black, location: 0), .init(color: .black, location: 1)]
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    /// How far out past its foot the slab's reflection reaches on the table.
    static let slabReflectionReach: CGFloat = 120
    /// The slab's reflection against a waiting title's: faint.
    static let slabReflection = 0.55

    /// The title's mirror image where it lands on the table: the soft copy,
    /// strongest at its feet.
    @ViewBuilder
    private func reflection(_ item: V2HologramPlaced) -> some View {
        if let soft = item.art?.soft {
            // `TabletopScene.Card.reflectionOpacity`, as it lifts and prints
            // in; the slab's is fainter (`slabReflection`).
            let faint: Double = 1 - (1 - Self.slabReflection) * item.card.focus
            let shown: Double = item.opacity * item.reveal * (0.22 + 0.6 * item.card.focus) * faint
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
                .opacity(shown * stages.reflection * look.reflection)
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

    /// Where a piece of a title is drawn on this half: where the eye sees
    /// `corners`, and on the top half during the lift, that far from the
    /// title's poster in the flat carousel.
    private func place(_ corners: [TabletopVec], of item: V2HologramPlaced) -> ProjectionTransform {
        let scene = rig.quad(corners, on: half)
        guard !twin, let flat = item.flatQuad else { return rig.transform(scene, from: box) }
        return rig.transform(TabletopLift.mix(flat, scene, stages.corners), from: box)
    }

    /// A title's piece on this half: the slab's glass slices, then its poster.
    @ViewBuilder
    private func piece(_ item: V2HologramPlaced) -> some View {
        let card = item.card
        let seen: Double = item.opacity * (twin ? stages.twins : 1)
        let glass: Double = seen * card.focus * (twin ? 1 : stages.depth)
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
        // its art. On the top half it takes the light as it leaves the carousel.
        let arrived: Double = twin ? 1 : stages.corners
        let ghost: Double = card.ghost * arrived
        // The carousel card's look (its corner radius and shadow, at the
        // plate's size), while the poster is still partly in the carousel.
        let carousel: CGFloat? = twin ? nil : item.flatWidth.map { box.width / CGFloat(max($0, 1)) }
        let grown: CGFloat = carousel ?? 1
        let radius: CGFloat = V2HologramArt.cornerRadius * (1 + (grown - 1) * CGFloat(1 - arrived))
        let front: Double = !twin && stages.keepsCarouselOrder ? 700 - abs(card.offset) * 10 : item.order
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

    /// The print-in's scan bar, across the slab at the height it is printed
    /// to, on whichever half that height is seen.
    private func scan(_ item: V2HologramPlaced) -> some View {
        V2HologramScan(look: look)
            .hologramPiece(rig.transform(item.card.scanBar(reveal: item.reveal, half: V2HologramScan.reach),
                                         on: half, from: V2HologramScan.box), box: V2HologramScan.box)
            .opacity(item.card.focus)
            .zIndex(900)
            .transition(.identity)
    }
}
