import SwiftUI
import FusionhaKit

/// The hologram's controls, at the bottom half's front edge (the approved
/// mock's `.pop` layout): the page dots, then the focused title's block on
/// the left (date line, title, reason with the HD/4K badge) and glass
/// previous / next with the primary Open on the right. The floor between
/// them and the fold is the scene's; the Mix menu sits in its top corner
/// (`V2HologramPage`). Type is a size up from the flat layout: this half is
/// read at a slant.
struct V2HologramControls: View {
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page

    var body: some View {
        VStack(spacing: 12) {
            V2CarouselDots(ids: cards.map(\.id), current: current.id)
            HStack(alignment: .center, spacing: 10) {
                info
                Spacer(minLength: 12)
                V2TabletopStep(by: -1, cards: cards, current: current, focused: $focused)
                V2TabletopStep(by: 1, cards: cards, current: current, focused: $focused)
                Button("Open") { model.open(current.item.id) }
                    .buttonStyle(.glassProminent)
                    .tint(Theme.indigo)
                    .controlSize(.large)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(current.when.uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
            Text(current.item.title)
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(page?.ink ?? Theme.txt)
                .minimumScaleFactor(0.7)
            HStack(spacing: 10) {
                V2ItemMarkLine(item: current.item, spacing: 7) {
                    Text(current.what)
                        .font(.system(size: 16))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                }
                V2ItemTickets(item: current.item)
            }
            .padding(.top, 3)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .id(current.id)
        .transition(.opacity)
        .animation(motion ? .easeOut(duration: 0.2) : nil, value: current.id)
    }
}
