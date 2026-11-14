import SwiftUI
import FusionhaKit

/// The hologram scene for VoiceOver: one element where the slab stands,
/// "Coming up, <title>, <when>, <what>, <n> of <m>". It is adjustable (a
/// swipe up is the next title, a swipe down the previous one) and a
/// double tap opens the title. The titles waiting on the ring are not
/// elements of their own; the scene's picture is hidden (`V2HologramScene`).
/// It draws nothing and takes no touches.
struct V2HologramVoice: View {
    let space: V2TabletopSpace
    let hinge: Double
    let cards: [V2ComingUpCard]
    let current: V2ComingUpCard
    /// Turns the ring to the card at an index (`V2HologramPage`).
    let turn: (Int) -> Void
    let open: () -> Void

    private var index: Int { cards.firstIndex { $0.id == current.id } ?? 0 }

    /// Where the focused slab is drawn: its top on the wall down to its foot
    /// on the table.
    private var slab: CGRect {
        let rig = V2HologramRig(space: space, hingeDegrees: hinge)
        guard let card = TabletopScene.card(offset: 0) else { return CGRect(origin: .zero, size: space.size) }
        let corners = card.corners()
        let top = corners[0...1].map { rig.point($0, on: .top) }
        let foot = corners[2...3].map { rig.point($0, on: .bottom) }
        let xs = (top + foot).map(\.x), head = top.map(\.y).min() ?? 0, base = foot.map(\.y).max() ?? 0
        let left = xs.min() ?? 0, right = xs.max() ?? space.size.width
        return CGRect(x: left, y: head, width: right - left, height: rig.hingeY + base - head)
    }

    var body: some View {
        let box = slab
        Color.clear
            .frame(width: max(44, box.width), height: max(44, box.height))
            .accessibilityElement()
            .accessibilityLabel(Text("Coming up"))
            .accessibilityValue(Text(verbatim: "\(current.item.title), \(current.when), \(current.what), \(index + 1) of \(cards.count)"))
            .accessibilityHint(Text("Opens the title. Swipe up or down for another."))
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: turn(index + 1)
                case .decrement: turn(index - 1)
                @unknown default: break
                }
            }
            .accessibilityAction { open() }
            .position(x: box.midX, y: box.midY)
            .allowsHitTesting(false)
    }
}
