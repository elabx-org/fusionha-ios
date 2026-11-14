import SwiftUI
import FusionhaKit

/// Home half folded on a table with the hologram on (tabletop plan, slice
/// 2; the approved mock's B2): the scene fills both halves behind the page
/// (`V2HologramStage`) and the bottom half is its floor, so Home's sections
/// leave. "Coming up" stays at the top left under the bar; the Mix menu
/// sits 30 pt below the fold and the focused title's controls at the front
/// edge (`V2HologramControls`), everything you tap on the bottom half and
/// clear of the fold. A swipe anywhere turns the ring, a tap on a waiting
/// title centres it and a tap on the slab opens it. The focus is the row's
/// (`V2ComingUpRow`). The hinge angle only bends the picture.
struct V2HologramPage: View {
    let space: V2TabletopSpace
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Binding var kindsRaw: String
    @Binding var days: Int
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page
    @State private var hinge = V2TabletopHologram.fixedHinge ?? TabletopProjection.restingHinge

    private var index: Int { cards.firstIndex { $0.id == current.id } ?? 0 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            heading
            controls
            V2ComingUpMenu(kindsRaw: $kindsRaw, days: $days, wideStyle: nil)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, space.fold.upperBound + 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .topLeading) {
            V2HologramStage(space: space, cards: cards, current: current, hinge: hinge)
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { tapped($0) }
        .simultaneousGesture(swipe)
        .readsTabletopHinge($hinge)
        // The row hands its opening card to a carousel; here there is none.
        .onChange(of: opening, initial: true) {
            guard let id = opening else { return }
            focused = id
            opening = nil
        }
        .sensoryFeedback(.selection, trigger: current.id)
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
        }
        .scrollDisabled(true)
        .defaultScrollAnchor(.bottom)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let across = value.translation.width
                guard abs(across) > abs(value.translation.height), abs(across) >= 40 else { return }
                turn(to: index + (across < 0 ? 1 : -1))
            }
    }

    private func turn(to target: Int) {
        guard cards.indices.contains(target) else { return }
        withAnimation(motion ? .smooth(duration: 0.4) : nil) { focused = cards[target].id }
    }

    /// A tap on the scene: the title drawn there, if any.
    private func tapped(_ point: CGPoint) {
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
