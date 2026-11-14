import SwiftUI
import FusionhaKit

/// The hologram scene across Home's whole container (tabletop plan, slices
/// 2 and 3; the approved mock's B2): the top half's layer above the hinge
/// and the bottom half's below it, each clipped to its half
/// (`V2HologramHalf`). `position` is the focused card's index, `hinge` the
/// hinge angle and `rise` the print-in; all three animate, so a turn of the
/// ring, a change of angle and the print-in re-draw the picture frame by
/// frame. `lift` is the lift's progress (the page animates it,
/// `V2TabletopLiftReader`). While it idles a timeline turns and bobs the
/// slab and turns the dashed ring; nothing above the scene changes per
/// frame. The scene only shows: it takes no touches (`V2HologramPage` reads
/// them).
struct V2HologramScene: View, Animatable {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let art: [Int: V2HologramArt]
    let look: V2HologramLook
    var position: Double
    var hinge: Double
    /// The print-in: 0 nothing yet, 1 printed.
    var rise: Double = 1
    /// The lift: 0 the flat carousel's posters, 1 the hologram.
    var lift: Double = 1
    /// The flat carousel the posters lift from.
    var flat: TabletopLift.Flat?
    /// The idle loop: the slab sways and bobs and the dashed ring turns.
    /// Off, the slab rests at its still turn (Reduce Motion, CI).
    var idles = false
    /// The idle loop holds where it is (the scene is off screen).
    var paused = false

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(position, hinge), rise) }
        set {
            position = newValue.first.first
            hinge = newValue.first.second
            rise = newValue.second
        }
    }

    var body: some View {
        Group {
            if idles {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: paused)) { timeline in
                    picture(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                picture(at: nil)
            }
        }
        .frame(width: space.size.width, height: space.size.height, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The picture `seconds` into the idle loop (nil: standing still).
    private func picture(at seconds: Double?) -> some View {
        var moment = V2HologramMoment(stages: TabletopLift.Stages(lift), print: TabletopLift.Print(rise), flat: flat)
        if let seconds {
            moment.sway = TabletopLift.sway(at: seconds)
            moment.bob = TabletopLift.bob(at: seconds)
            moment.spin = TabletopLift.spin(at: seconds)
        }
        let rig = V2HologramRig(space: space, hingeDegrees: hinge)
        let placed = V2HologramPlaced.all(cards, position: position, art: art, moment: moment)
        return VStack(spacing: 0) {
            V2HologramHalf(half: .top, rig: rig, placed: placed, look: look, moment: moment)
            V2HologramHalf(half: .bottom, rig: rig, placed: placed, look: look, moment: moment)
        }
    }
}
