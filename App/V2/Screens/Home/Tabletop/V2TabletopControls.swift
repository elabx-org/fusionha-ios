import SwiftUI
import FusionhaKit

/// The tabletop's bottom half, above Home's sections: the focused title's
/// block (`V2ComingUpWideInfo`: date line, title, reason with the HD/4K
/// badge), glass previous / next around the primary Open, the page dots and
/// the Mix menu, with the Hologram switch (`V2HologramSwitch`) at the left
/// of the buttons' row, opposite Mix. Everything you tap for Coming up is
/// here, within reach of the thumbs; the stage above only shows.
struct V2TabletopControls: View {
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Binding var kindsRaw: String
    @Binding var days: Int
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            V2ComingUpWideInfo(card: current, style: .posters, width: 0)
                .padding(.horizontal, 20)
            ZStack {
                HStack(spacing: 18) {
                    V2TabletopStep(by: -1, cards: cards, current: current, focused: $focused)
                    Button("Open") { model.open(current.item.id) }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.indigo)
                        .controlSize(.large)
                    V2TabletopStep(by: 1, cards: cards, current: current, focused: $focused)
                }
                HStack {
                    V2HologramSwitch()
                    Spacer(minLength: 0)
                    V2ComingUpMenu(kindsRaw: $kindsRaw, days: $days, wideStyle: nil, onTable: true)
                }
                .padding(.horizontal, 20)
            }
            V2CarouselDots(ids: cards.map(\.id), current: current.id)
        }
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.2), value: current.id)
    }
}
