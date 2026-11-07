import SwiftUI
import FusionhaKit

/// Coming up as the open Duo's hero (owner-approved mock, 2026-11-07): the
/// carousel spans the page, the focused card in the centre and its
/// neighbours shrinking and fading toward the edges (`V2ComingUpWideMetrics`),
/// running past the page's gutters. Under it one block for the focused title
/// (`V2ComingUpWideInfo`), then the page dots. A tap on a side card centres
/// it; a tap on the centre one opens the title, as folded.
struct V2ComingUpWideCarousel: View {
    let cards: [V2ComingUpCard]
    let style: V2ComingUpWideStyle
    @Binding var focused: Int?
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @State private var width: CGFloat = 0

    private var current: V2ComingUpCard? { cards.first { $0.id == focused } ?? cards.first }

    var body: some View {
        let m = V2ComingUpWideMetrics(style: style, width: width, motion: motion)
        VStack(spacing: 10) {
            row(m)
            if let current {
                V2ComingUpWideInfo(card: current, style: style, width: m.size.width)
            }
            V2CarouselDots(ids: cards.map(\.id), current: current?.id)
                .padding(.top, 4)
        }
    }

    private func row(_ m: V2ComingUpWideMetrics) -> some View {
        let at = cards.firstIndex { $0.id == current?.id } ?? 0
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .center, spacing: m.spacing) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                    V2ComingUpWideCard(card: card, size: m.size, backdrop: style == .backdrops) { tapped(card) }
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
        .contentMargins(.horizontal, max(0, (width - m.size.width) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focused, anchor: .center)
        .scrollClipDisabled()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sensoryFeedback(.selection, trigger: focused)
        .accessibilityLabel("Coming up")
    }

    private func tapped(_ card: V2ComingUpCard) {
        if card.id == current?.id {
            model.open(card.item.id)
        } else {
            withAnimation(motion ? .smooth(duration: 0.4) : nil) { focused = card.id }
        }
    }
}
