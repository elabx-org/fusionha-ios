import Foundation
import FusionhaKit

/// What a finger is doing to the hologram (tabletop plan, slice 6; the
/// hinge-fix mock's `dial` and `spin`): the ring's fractional position while
/// the dial is turned, and the slab's spin while it is held and as it coasts
/// home after. `V2HomeTabletop` keeps it; `V2HologramPage` reads the finger
/// and writes it, the scene draws it (`V2HologramStage`).
struct V2HologramHand: Equatable {
    /// The ring's position while a finger turns the dial (nil: the row's focus).
    var dial: Double?
    var dialHeld: Bool { dial != nil }
    /// The slab's turn while a finger holds it.
    var spinHeld: Double?
    /// After letting go: the coast home and when it started (seconds since
    /// the reference date, the scene's timeline's clock).
    var coast: TabletopSpin.Coast?
    var coastStart = 0.0

    /// The slab's spin `seconds` into the scene's timeline (nil: the scene
    /// stands still, so no coast is drawn).
    func spin(at seconds: Double?) -> Double {
        if let spinHeld { return spinHeld }
        if let seconds, let coast, let angle = coast.angle(after: seconds - coastStart) { return angle }
        return V2TabletopHologram.fixedSpin ?? 0
    }
}
