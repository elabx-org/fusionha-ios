import SwiftUI
import FusionhaKit

/// The tabletop's glass previous / next circle: moves Coming up's focus one
/// title along (the row owns the focus), dimmed at either end.
struct V2TabletopStep: View {
    /// −1 previous, 1 next.
    let by: Int
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    @Binding var focused: Int?
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page

    private var target: Int { (cards.firstIndex { $0.id == current.id } ?? 0) + by }
    private var enabled: Bool { cards.indices.contains(target) }

    var body: some View {
        Button {
            guard enabled else { return }
            withAnimation(motion ? .smooth(duration: 0.4) : nil) { focused = cards[target].id }
        } label: {
            Image(systemName: by < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(by < 0 ? "Previous" : "Next")
    }
}
