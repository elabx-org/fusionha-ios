import SwiftUI
import FusionhaKit

/// Coming up's centre-focus carousel (Home mock, 2026-11-06): one poster
/// snaps to the centre; the others scale toward 0.82 and fade toward 0.55
/// with their distance from it, peeking on both sides. The title, reason and
/// tickets show under the focused card only. Page dots under the row. A tap
/// on a side card centres it; a tap on the centre one opens the title.
/// Reduce Motion: no scaling, the row simply pages.
struct V2ComingUpCarousel: View {
    let cards: [V2ComingUpCard]
    let cardWidth: CGFloat
    /// Title, reason and tickets under the focused card (the phone and the
    /// folded Duo; wide pages show them beside the row instead).
    let showsMeta: Bool
    /// Clip the row to its column (wide); else neighbours run to the screen edge.
    let clips: Bool
    @Binding var focused: Int?
    @Binding var opening: Int?
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @State private var width: CGFloat = 0

    /// Neighbours overlap the focused card's shrink a little (the mock's −6 a side).
    private static let spacing: CGFloat = -12

    private var current: Int? { focused ?? cards.first?.id }

    var body: some View {
        VStack(spacing: 10) {
            row
            V2CarouselDots(ids: cards.map(\.id), current: current)
        }
    }

    private var row: some View {
        let w = cardWidth
        let scales = motion
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Self.spacing) {
                ForEach(cards) { card in
                    V2ComingUpFocusCard(card: card, width: w, showsMeta: showsMeta) { tapped(card) }
                        .visualEffect { content, proxy in
                            let t = Self.distance(proxy, cardWidth: w)
                            return content
                                .scaleEffect(scales ? 1 - 0.18 * t : 1)
                                .opacity(1 - 0.45 * t)
                        }
                        .zIndex(card.id == current ? 1 : 0)
                        .id(card.id)
                }
            }
            .padding(.vertical, 14)
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, max(0, (width - w) / 2), for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $focused, anchor: .center)
        .v2CarouselOpening($opening, focused: $focused)
        .scrollClipDisabled(!clips)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sensoryFeedback(.selection, trigger: focused)
        .accessibilityLabel("Coming up")
    }

    private func tapped(_ card: V2ComingUpCard) {
        if card.id == current {
            model.open(card.item.id)
        } else {
            withAnimation(motion ? .smooth(duration: 0.4) : nil) { focused = card.id }
        }
    }

    /// 0 at the centre of the row, 1 a card's width (×0.9) or more away.
    nonisolated static func distance(_ proxy: GeometryProxy, cardWidth: CGFloat) -> CGFloat {
        guard let bounds = proxy.bounds(of: .scrollView) else { return 0 }
        let frame = proxy.frame(in: .scrollView)
        let d = abs(frame.midX - bounds.width / 2)
        return min(d / max(cardWidth * 0.9, 1), 1)
    }
}

/// The carousel's page dots: the focused one a short bar.
struct V2CarouselDots: View {
    let ids: [Int]
    let current: Int?
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion

    var body: some View {
        let ink = page?.ink ?? Theme.txt
        HStack(spacing: 6) {
            ForEach(ids, id: \.self) { id in
                Capsule()
                    .fill(id == current ? ink : ink.opacity(0.3))
                    .frame(width: id == current ? 16 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(motion ? .snappy(duration: 0.25) : nil, value: current)
        .accessibilityHidden(true)
    }
}
