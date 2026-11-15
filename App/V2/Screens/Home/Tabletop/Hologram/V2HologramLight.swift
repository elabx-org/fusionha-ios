import SwiftUI
import FusionhaKit

/// The projection light (owner, 2026-11-15: "there's no projection light
/// coming from the disc to show it's projecting the hologram"), on one half
/// of the scene, over the focused card (`TabletopBeam` has its numbers). On
/// the table half the disc glows as the source (a bright soft core and a
/// pool filling the ring) and a cone of light lies from it to the card's
/// foot, drawn with the floor projection. Across the fold the light is
/// brightest, in a band 1.3 of the card wide over the card's foot on both
/// halves, so its lower edge and the join dissolve into glare; up the card
/// it thins out and is gone by 45% of its height. The band is drawn from
/// one function of the distance from the fold line, with one centre and
/// one width, so its two pieces meet. Thin soft scan lines travel up
/// through it (still under Reduce Motion and in CI). Every piece is a soft
/// gradient with feathered sides, nothing hard; on a dark room it adds
/// (`V2HologramLook.beamBlend`), on a light one it is laid over. It takes
/// no touches. Content, never glass.
struct V2HologramLight: View {
    let half: V2HologramRig.Half
    let rig: V2HologramRig
    let look: V2HologramLook
    let card: TabletopScene.Card
    /// How strong it is this frame (the lift, the print-in, the focus, the
    /// breath and the palette, `V2HologramHalf`).
    let strength: Double
    /// Seconds into the idle loop (nil: the scan lines rest).
    var time: Double?

    private var scale: CGFloat { CGFloat(rig.scale) }
    private var light: CGSize { CGSize(width: CGFloat(TabletopScene.lightSide), height: CGFloat(TabletopScene.lightSide)) }
    private var top: Bool { half == .top }

    /// The card's height up the upright half, in design points: its highest
    /// head corner (the same on both halves).
    private var cardHeight: Double {
        let head = card.corners()[0...1].map { rig.point($0, on: .top).y }
        return max(0, Double(rig.hingeY - (head.min() ?? rig.hingeY)) / max(rig.scale, 0.01))
    }

    /// The band's centre: the card's foot as seen on the table, for both halves.
    private var centreX: CGFloat { rig.point(TabletopVec(card.centerX, -card.lift, card.centerZ), on: .bottom).x }
    private var bandWidth: CGFloat { CGFloat(TabletopBeam.width(cardWidth: card.width)) * scale }

    var body: some View {
        let height = cardHeight
        ZStack(alignment: .topLeading) {
            if !top {
                disc
                cone
            }
            band(cardHeight: height)
            ForEach(lines(cardHeight: height), id: \.self) { scanLine(at: $0, cardHeight: height) }
        }
        .frame(width: rig.size.width, height: rig.height(of: half), alignment: .topLeading)
        .blendMode(look.beamBlend)
        .allowsHitTesting(false)
    }

    /// Feathered sides: nothing at either edge.
    private var feather: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22),
                               .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }

    private func glow(_ opacity: Double) -> Color { look.beam.opacity(min(1, max(0, opacity))) }

    /// The source: a soft pool filling the ring and a bright core at its centre.
    private var disc: some View {
        let pool = CGFloat(TabletopScene.emitterRadius) * scale, core = 44 * scale
        return ZStack {
            RadialGradient(stops: [.init(color: glow(0.5 * strength), location: 0),
                                   .init(color: glow(0.3 * strength), location: 0.6),
                                   .init(color: glow(0), location: 1)],
                           center: .center, startRadius: 0, endRadius: pool)
                .frame(width: pool * 2, height: pool * 2)
            RadialGradient(stops: [.init(color: look.beamCore.opacity(min(1, 0.95 * strength)), location: 0),
                                   .init(color: look.beamCore.opacity(0.4 * strength), location: 0.45),
                                   .init(color: look.beamCore.opacity(0), location: 1)],
                           center: .center, startRadius: 0, endRadius: core)
                .frame(width: core * 2, height: core * 2)
        }
        .position(x: rig.size.width / 2, y: CGFloat(TabletopScene.ringZ) * scale)
    }

    /// The cone from the disc to the card's foot, lying on the floor and
    /// rising to the foot; it fades out at both ends.
    private var cone: some View {
        LinearGradient(stops: [.init(color: glow(0), location: 0), .init(color: glow(0.5 * strength), location: 0.2),
                               .init(color: glow(0.28 * strength), location: 0.62), .init(color: glow(0), location: 1)],
                       startPoint: .bottom, endPoint: .top)
            .mask { feather }
            .hologramPiece(rig.transform(TabletopBeam.cone(card), on: .bottom, from: light), box: light)
    }

    /// The band across the fold and the light up the card, on this half:
    /// sampled from `TabletopBeam.strength` from the fold line out.
    private func band(cardHeight: Double) -> some View {
        let reach = top ? TabletopBeam.reach(cardHeight: cardHeight) : TabletopBeam.bandReach
        let tall = CGFloat(reach) * scale, count = 18
        let stops = (0...count).map { i -> Gradient.Stop in
            let location = Double(i) / Double(count)
            // Top half: from the light's top down to the fold; table half: from the fold out.
            let rise = top ? reach * (1 - location) : -reach * location
            return .init(color: glow(TabletopBeam.strength(rise: rise, cardHeight: cardHeight) * strength),
                         location: location)
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
            .mask { feather }
            .frame(width: bandWidth, height: tall)
            .position(x: centreX, y: top ? rig.hingeY - tall / 2 : tall / 2)
    }

    /// The scan lines that fall on this half (a line on the fold is drawn on both).
    private func lines(cardHeight: Double) -> [Double] {
        TabletopBeam.scanLines(at: time, cardHeight: cardHeight).filter { top ? $0 > -4 : $0 < 4 }
    }

    /// One thin soft line across the light, as strong as the light there.
    private func scanLine(at rise: Double, cardHeight: Double) -> some View {
        let y = top ? rig.hingeY - CGFloat(rise) * scale : CGFloat(-rise) * scale
        return LinearGradient(stops: [.init(color: glow(0), location: 0), .init(color: glow(1), location: 0.5),
                                      .init(color: glow(0), location: 1)],
                              startPoint: .top, endPoint: .bottom)
            .mask { feather }
            .frame(width: bandWidth * 0.92, height: 6 * scale)
            .position(x: centreX, y: y)
            .opacity(0.55 * TabletopBeam.strength(rise: rise, cardHeight: cardHeight) * strength)
    }
}

/// The focused card's contact shadow on the floor (owner, 2026-11-15: tie
/// the card to the table): a soft dark ellipse over its turned foot's
/// footprint, slices included (`TabletopBeam.contact`), darker than the
/// grid, on both halves (part of the footprint is behind the fold). No hard
/// edge. Content, never glass.
struct V2HologramContact: View {
    let half: V2HologramRig.Half
    let rig: V2HologramRig
    let look: V2HologramLook
    let card: TabletopScene.Card
    let strength: Double

    private var box: CGSize { CGSize(width: CGFloat(TabletopScene.lightSide), height: CGFloat(TabletopScene.lightSide)) }

    var body: some View {
        let dark = look.contact, core = look.contactStrength
        EllipticalGradient(stops: [.init(color: dark.opacity(core), location: 0),
                                   .init(color: dark.opacity(core * 0.55), location: 0.5),
                                   .init(color: dark.opacity(0), location: 1)],
                           center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
            .hologramPiece(rig.transform(TabletopBeam.contact(card), on: half, from: box), box: box)
            .opacity(strength)
            .allowsHitTesting(false)
    }
}
