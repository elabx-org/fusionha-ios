import SwiftUI
import FusionhaKit

/// What lies over the hologram scene (tabletop plan, slices 2 and 3; the
/// approved mock's B2): "Coming up" at the top left under the bar, and on
/// the bottom half, which is the scene's floor, the Hologram switch (left)
/// and the Mix menu (right) 30 pt below the fold and the focused title's
/// controls at the front edge (`V2HologramControls`). Everything you tap is
/// on the bottom half and clear of the fold. A swipe anywhere turns the
/// ring, a tap on a waiting title centres it and a tap on the slab opens
/// it. The focus is the row's (`V2ComingUpRow`). `V2HomeTabletop` draws the
/// scene behind this page and lifts it; until the lift is done (`live`) the
/// page takes no touches and its controls are on their way in (`chrome`).
/// Both, and the heading's fade, are applied inside the page's scroll views,
/// whose own place in the page never changes.
struct V2HologramPage: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Binding var kindsRaw: String
    @Binding var days: Int
    /// The hinge angle the scene is drawn for (a tap finds its title with it).
    let hinge: Double
    /// The hologram stands: the page takes touches and the row's opening card.
    var live = true
    /// How far the controls have come in (the lift), and the heading
    /// (Reduce Motion's cross-fade; the lift shows it throughout).
    var chrome: Double = 1
    var headingOpacity: Double = 1
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page

    private var index: Int { cards.firstIndex { $0.id == current.id } ?? 0 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            heading
            controls
            corners
                .opacity(chrome)
                .allowsHitTesting(live)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { tapped($0) }
        .simultaneousGesture(swipe)
        // The row hands its opening card to a carousel; with the hologram
        // standing there is none (during the lift the flat carousel takes it).
        .onChange(of: opening, initial: true) { takeOpening() }
        .onChange(of: live) { takeOpening() }
        .sensoryFeedback(.selection, trigger: current.id)
    }

    private func takeOpening() {
        guard live, let id = opening else { return }
        focused = id
        opening = nil
    }

    /// The Hologram switch and the Mix menu, 30 pt below the fold (the
    /// switch's 44 pt target starts 25 pt below it).
    private var corners: some View {
        HStack {
            V2HologramSwitch()
            Spacer(minLength: 0)
            V2ComingUpMenu(kindsRaw: $kindsRaw, days: $days, wideStyle: nil, onTable: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, space.fold.upperBound + 25)
    }

    /// A scroll view that doesn't scroll, so the system sets the heading
    /// below the bar as it does on Home's other pages.
    private var heading: some View {
        ScrollView {
            Text("Coming up")
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(headingOpacity)
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }

    /// The same, held at its bottom: the controls sit at the front edge,
    /// above whatever the system keeps clear there (the downloads bar).
    private var controls: some View {
        ScrollView {
            V2HologramControls(cards: cards, current: current, focused: $focused)
                .containerRelativeFrame(.vertical, alignment: .bottom)
                .opacity(chrome)
                .allowsHitTesting(live)
        }
        .scrollDisabled(true)
        .defaultScrollAnchor(.bottom)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let across = value.translation.width
                guard live, abs(across) > abs(value.translation.height), abs(across) >= 40 else { return }
                turn(to: index + (across < 0 ? 1 : -1))
            }
    }

    private func turn(to target: Int) {
        guard cards.indices.contains(target) else { return }
        withAnimation(motion ? .smooth(duration: 0.4) : nil) { focused = cards[target].id }
    }

    /// A tap on the scene: the title drawn there, if any.
    private func tapped(_ point: CGPoint) {
        guard live else { return }
        let rig = V2HologramRig(space: space, hingeDegrees: hinge)
        let placed = V2HologramPlaced.all(cards, position: Double(index), art: [:])
        guard let id = V2HologramPlaced.hit(point, in: placed, rig: rig) else { return }
        if id == current.id {
            model.open(id)
        } else if let target = cards.firstIndex(where: { $0.id == id }) {
            turn(to: target)
        }
    }
}
