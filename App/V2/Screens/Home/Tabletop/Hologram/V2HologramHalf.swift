import SwiftUI
import FusionhaKit

/// One half of the hologram scene, as its own layer clipped to the half
/// (the approved mock's B2, `drawHolo`). Every standing thing is drawn on
/// both halves from the same eye: on the top half as it is seen against the
/// upright screen, on the bottom half as it is seen against the table, so
/// its two pieces meet at the hinge. The top half also has the wall, the
/// floor behind the hinge and the halo; the bottom half is the floor
/// itself, with the ring and the reflections.
struct V2HologramHalf: View {
    let half: V2HologramRig.Half
    let rig: V2HologramRig
    let placed: [V2HologramPlaced]
    let look: V2HologramLook

    private var box: CGSize { V2HologramArt.box }
    private var light: CGSize { CGSize(width: CGFloat(TabletopScene.lightSide), height: CGFloat(TabletopScene.lightSide)) }
    /// The title nearest the focus: the one the beam and the halo belong to.
    private var lead: V2HologramPlaced? { placed.max { $0.card.focus < $1.card.focus } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            look.room
            switch half {
            case .top: backdrop
            case .bottom: table
            }
            ForEach(placed) { piece($0) }
            if let lead { beam(lead) }
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
        let pad = CGSize(width: CGFloat(TabletopProjection.designWidth), height: CGFloat(TabletopScene.floorDepth))
        V2HologramFloor(part: .behind, look: look, size: pad)
            .hologramPiece(rig.transform(TabletopScene.floorBehind, on: .top, from: pad), box: pad)
        if let lead {
            RadialGradient(colors: [look.tint.opacity(look.haloGlow), look.tint.opacity(0)],
                           center: .center, startRadius: 0, endRadius: light.width / 2)
                .hologramPiece(rig.transform(lead.card.halo, on: .top, from: light), box: light)
                .opacity(lead.card.haloOpacity)
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
        let scale = CGFloat(rig.scale)
        let plate = CGSize(width: CGFloat(TabletopProjection.designWidth), height: rig.bottomHeight / max(scale, 0.01))
        V2HologramFloor(part: .front, look: look, size: plate)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: rig.size.width, height: rig.bottomHeight, alignment: .topLeading)
        ForEach(placed) { reflection($0) }
    }

    /// The title's mirror image where it lands on the table: the soft copy,
    /// strongest at its feet.
    @ViewBuilder
    private func reflection(_ item: V2HologramPlaced) -> some View {
        if let soft = item.art?.soft {
            Image(uiImage: soft)
                .resizable()
                .interpolation(.high)
                .frame(width: box.width, height: box.height)
                .mask {
                    // Soft at the feet and the sides (the mock blurs it once).
                    LinearGradient(stops: [.init(color: .clear, location: 0),
                                           .init(color: .black.opacity(0.8), location: 0.06),
                                           .init(color: .black.opacity(0.42), location: 0.36),
                                           .init(color: .black.opacity(0.12), location: 0.64),
                                           .init(color: .clear, location: 0.88)],
                                   startPoint: .bottom, endPoint: .top)
                }
                .mask { softSides }
                .hologramPiece(rig.transform(item.card.corners(mirrored: true), on: .bottom, from: box), box: box)
                .opacity(item.card.reflectionOpacity * look.reflection)
                .blendMode(look.lightBlend)
        }
    }

    // MARK: Both halves

    /// A title's piece on this half: the slab's glass slices, then its poster.
    @ViewBuilder
    private func piece(_ item: V2HologramPlaced) -> some View {
        let card = item.card
        if card.hasSlices {
            ForEach(0..<TabletopScene.sliceCount, id: \.self) { index in
                V2HologramPlate(image: item.art?.poster, wash: look.slice, washOpacity: look.sliceOpacity)
                    .hologramPiece(rig.transform(card.slice(index), on: half, from: box), box: box)
                    .opacity(card.sliceOpacity)
                    .zIndex(item.order - 1 - Double(index))
            }
        }
        // A waiting title is drawn as light: the focused title's colour over its art.
        V2HologramPlate(image: item.art?.poster, wash: look.tint, washOpacity: card.ghost, washBlend: .color,
                        edge: look.ring.opacity(0.8))
            .brightness(look.isLight ? 0 : card.ghost * 0.1)
            .hologramPiece(rig.transform(card.corners(), on: half, from: box), box: box)
            .opacity(card.opacity)
            .zIndex(item.order)
    }

    /// A mask that fades a piece out toward its left and right edges.
    private var softSides: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.16),
                               .init(color: .black, location: 0.84), .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }

    /// The beam from the emitter up to the slab: a gradient with soft edges.
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
            .opacity(item.card.beamOpacity)
            .blendMode(look.lightBlend)
            .zIndex(item.order + 1)
    }
}
