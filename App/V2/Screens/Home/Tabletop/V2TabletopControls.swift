import SwiftUI
import FusionhaKit

/// The tabletop's bottom half, above Home's sections: the focused title's
/// block (`V2ComingUpWideInfo`: date line, title, reason with the HD/4K
/// badge), glass previous / next around the primary Open, the page dots and
/// the Mix menu. Everything you tap for Coming up is here, within reach of
/// the thumbs; the stage above only shows.
struct V2TabletopControls: View {
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Binding var kindsRaw: String
    @Binding var days: Int
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page

    private var index: Int { cards.firstIndex { $0.id == current.id } ?? 0 }

    var body: some View {
        VStack(spacing: 16) {
            V2ComingUpWideInfo(card: current, style: .posters, width: 0)
                .padding(.horizontal, 20)
            ZStack {
                HStack(spacing: 18) {
                    step(-1, symbol: "chevron.left", label: "Previous")
                    Button("Open") { model.open(current.item.id) }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.indigo)
                        .controlSize(.large)
                    step(1, symbol: "chevron.right", label: "Next")
                }
                HStack {
                    Spacer(minLength: 0)
                    V2ComingUpMenu(kindsRaw: $kindsRaw, days: $days, wideStyle: nil)
                }
                .padding(.trailing, 20)
            }
            V2CarouselDots(ids: cards.map(\.id), current: current.id)
        }
        .padding(.top, 8)
        .animation(.easeOut(duration: 0.2), value: current.id)
    }

    private func step(_ by: Int, symbol: String, label: String) -> some View {
        let target = index + by
        let enabled = cards.indices.contains(target)
        return Button {
            guard enabled else { return }
            withAnimation(motion ? .smooth(duration: 0.4) : nil) { focused = cards[target].id }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(label)
    }
}
