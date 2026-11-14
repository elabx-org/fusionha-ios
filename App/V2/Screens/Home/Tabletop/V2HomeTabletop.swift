import SwiftUI
import FusionhaKit

/// Home half folded on a table (the fold side to side), while Coming up has
/// cards and no title is open: Home spans both halves. `V2ComingUpRow` owns
/// the feed, the cards and the focus and hands them in; nothing here reads
/// the calendar. With a title open the shell splits at the fold again and
/// Home is its ordinary page in the top half.
///
/// Two looks, chosen by the stored switch (`V2TabletopHologram`, off by
/// default): the flat carousel over Home's sections (`V2TabletopFlat`) and
/// the hologram (`V2HologramStage` under `V2HologramPage`). Changing the
/// switch plays the lift (tabletop plan, slice 3; the approved mock's
/// `holo`): one progress value, 0 flat and 1 hologram, linear over 1.3 s
/// (`TabletopLift`). On the way the scene draws the carousel's posters from
/// their own places into the scene, the flat page's bottom half fades and
/// the hologram's controls come in last. Reduce Motion: the two looks
/// cross-fade and nothing lifts.
struct V2HomeTabletop: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Binding var kindsRaw: String
    @Binding var days: Int
    let rest: AnyView
    @Environment(\.motionEnabled) private var motion
    @AppStorage(V2TabletopHologram.key) private var stored = false
    /// The lift's progress; it rests at 0 or 1.
    @State private var lift = V2TabletopHologram.restingLift
    /// The tabletop appeared with the hologram on: the scene prints in, once.
    @State private var printsIn = V2TabletopHologram.restingLift >= 1
    @State private var hinge = V2TabletopHologram.fixedHinge ?? TabletopProjection.restingHinge
    /// Where the flat page's content starts (it measures it).
    @State private var top: CGFloat = 0
    /// The last focused card: a flat carousel built for the way down lets go
    /// of the focus for a moment while it opens on it.
    @State private var lastFocus: Int?

    private var on: Bool { V2TabletopHologram.isOn(stored: stored) }

    /// The card the hologram shows.
    private var shown: V2ComingUpCard {
        cards.first { $0.id == (focused ?? lastFocus) } ?? current
    }

    var body: some View {
        V2TabletopLiftReader(progress: lift) { page(at: $0) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .readsTabletopHinge($hinge)
            .onChange(of: focused, initial: true) {
                if let focused { lastFocus = focused }
            }
            .onChange(of: on) { play() }
    }

    /// The switch changed: lift, or let down.
    private func play() {
        guard V2TabletopHologram.frozenLift == nil else { return }
        let target: Double = on ? 1 : 0
        withAnimation(motion ? .linear(duration: TabletopLift.duration) : .easeInOut(duration: 0.3)) {
            lift = target
        }
    }

    /// The page with the lift at `progress`.
    private func page(at progress: Double) -> some View {
        // Reduce Motion: the hologram is whole and fades in over the flat page.
        let staged = motion
        let stages = TabletopLift.Stages(staged ? progress : 1)
        let drawn: Double = staged ? progress : (progress > 0 ? 1 : 0)
        let fade: Double = staged ? 1 : progress
        return ZStack(alignment: .topLeading) {
            if progress < 1 {
                V2TabletopFlat(space: space, cards: cards, current: current, focused: $focused, opening: $opening,
                               kindsRaw: $kindsRaw, days: $days, rest: rest, top: $top,
                               stageShown: !staged || progress <= 0,
                               floorOpacity: staged ? 1 - stages.floor : 1)
                    .allowsHitTesting(progress <= 0)
                    // Nothing fades of its own accord: the lift places everything.
                    .transition(.identity)
            }
            V2HologramStage(space: space, cards: cards, current: shown, hinge: hinge, lift: drawn,
                            flat: space.flatCarousel(top: top), printsIn: printsIn)
                .opacity(fade)
            if progress > 0 {
                V2HologramPage(space: space, cards: cards, current: shown, focused: $focused, opening: $opening,
                               kindsRaw: $kindsRaw, days: $days, hinge: hinge, live: progress >= 1,
                               chrome: stages.depth)
                    .opacity(fade)
                    .transition(.identity)
            }
        }
    }
}
