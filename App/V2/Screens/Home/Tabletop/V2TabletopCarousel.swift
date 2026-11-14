import SwiftUI
import FusionhaKit

/// The tabletop stage's flat carousel: clean posters (`V2ComingUpWideCard`),
/// the focused one in the middle, one smaller neighbour each side
/// (`V2ComingUpWideMetrics(tabletopHeight:)`). A swipe turns it; a tap on a
/// side poster centres it, a tap on the centre one opens the title. The
/// focus is the row's (`V2ComingUpRow` owns it).
struct V2TabletopCarousel: View {
    let cards: [V2ComingUpCard]
    let posterHeight: CGFloat
    /// The page's width, known from the first pass. Measured inside the scroll
    /// view it started at 0 and changed the content margins after the opening
    /// card was scrolled to, leaving the row one card off its focus.
    let containerWidth: CGFloat
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion

    private var currentId: Int? { cards.contains { $0.id == focused } ? focused : cards.first?.id }

    var body: some View {
        let m = V2ComingUpWideMetrics(tabletopHeight: posterHeight, motion: motion)
        let at = cards.firstIndex { $0.id == currentId } ?? 0
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: m.spacing) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                    V2ComingUpWideCard(card: card, size: m.size, backdrop: false) { tapped(card) }
                        .visualEffect { content, proxy in
                            let slot = m.slot(proxy)
                            return content
                                .scaleEffect(m.scale(slot))
                                .offset(x: m.offset(slot))
                                .opacity(m.opacity(slot))
                        }
                        .zIndex(Double(-abs(i - at)))
                        .id(card.id)
                }
            }
            .padding(.vertical, 14)
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max(0, (containerWidth - m.size.width) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focused, anchor: .center)
        .v2CarouselOpening($opening, focused: $focused)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: focused)
        .accessibilityLabel("Coming up")
    }

    private func tapped(_ card: V2ComingUpCard) {
        if card.id == currentId {
            model.open(card.item.id)
        } else {
            withAnimation(motion ? .smooth(duration: 0.4) : nil) { focused = card.id }
        }
    }
}
