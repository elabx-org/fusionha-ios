import SwiftUI
import FusionhaKit

/// Where the scene's motion has got to, for one frame: the lift's stages,
/// the print-in, the idle loop's turn of the slab and of the dashed ring,
/// and the flat carousel the posters lift from. The default is the hologram
/// standing still.
struct V2HologramMoment: Equatable {
    var stages = TabletopLift.Stages.done
    var print = TabletopLift.Print.done
    /// The slab's turn (radians) and how far it floats up (points).
    var sway = TabletopScene.restingSway
    var bob = 0.0
    /// The dashed inner ring's turn (radians).
    var spin = 0.0
    /// The flat carousel's posters, in the container's coordinates.
    var flat: TabletopLift.Flat?
}

/// One title placed in the scene: its card, where it stands
/// (`TabletopScene.Card`), its art once loaded, and where the lift and the
/// print-in have it this frame.
struct V2HologramPlaced: Identifiable {
    let id: Int
    let card: TabletopScene.Card
    let art: V2HologramArt?
    /// How much of it is printed, from its foot up (1 once it stands).
    let reveal: Double
    /// Its poster in the flat carousel (the top half's layer is the
    /// container's own coordinates); nil once the corners have arrived.
    let flatQuad: [TabletopPoint]?
    /// The flat carousel's focused poster's width (nil with `flatQuad`).
    let flatWidth: Double?
    /// Its opacity on the top half: the carousel's on the way to the scene's.
    let opacity: Double

    /// Nearer the viewer draws over further away (the mock's z-index).
    var order: Double { (500 + card.centerZ).rounded() }

    /// The titles within reach of `position` (an index into `cards`,
    /// fractional while the ring turns).
    static func all(_ cards: [V2ComingUpCard], position: Double, art: [Int: V2HologramArt],
                    moment: V2HologramMoment = V2HologramMoment()) -> [V2HologramPlaced] {
        let stages = moment.stages
        let flat = stages.corners < 1 ? moment.flat : nil
        return cards.enumerated().compactMap { index, card in
            let offset = Double(index) - position
            guard let placed = TabletopScene.card(offset: offset, sway: moment.sway * stages.depth,
                                                  bob: moment.bob * stages.depth) else { return nil }
            let reveal = moment.print.reveal(away: abs(offset), focus: placed.focus)
            let from = flat?.opacity(offset) ?? placed.opacity
            return V2HologramPlaced(id: card.id, card: placed, art: art[card.id], reveal: reveal,
                                    flatQuad: flat?.quad(offset), flatWidth: flat?.width,
                                    opacity: reveal > 0.01 ? TabletopLift.mix(from, placed.opacity, stages.corners) : 0)
        }
    }

    /// The title drawn at `point` of the container, the nearest first.
    static func hit(_ point: CGPoint, in placed: [V2HologramPlaced], rig: V2HologramRig) -> Int? {
        let at = rig.locate(point)
        return placed.sorted { $0.order > $1.order }.first {
            TabletopProjection.contains(rig.quad($0.card.corners(), on: at.half), at.point)
        }?.id
    }
}
