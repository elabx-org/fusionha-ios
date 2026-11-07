import SwiftUI
import FusionhaKit

/// One Coming up card: the clean 2:3 poster (nothing on the art) and, under
/// it, the title, the reason ("Digital · Sun") led by the network mark and
/// the HD/4K tickets, which fade in only as the card reaches the centre.
/// Content, not glass.
struct V2ComingUpFocusCard: View {
    let card: V2ComingUpCard
    let width: CGFloat
    let showsMeta: Bool
    let tap: () -> Void
    @Environment(\.pagePalette) private var page

    private var art: URL? { TMDBImage.resized(card.item.posterUrl ?? card.item.backdropUrl, to: "w500") }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 12) {
                PosterImage(url: art, size: CGSize(width: width, height: width * 1.5))
                    .frame(width: width, height: width * 1.5)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(.white.opacity(0.08)))
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 12)
                if showsMeta {
                    meta.visualEffect { content, proxy in
                        content.opacity(max(0, 1 - 2.2 * V2ComingUpCarousel.distance(proxy, cardWidth: width)))
                    }
                }
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.item.title), \(card.reason)")
        .accessibilityAddTraits(.isButton)
    }

    private var meta: some View {
        VStack(spacing: 3) {
            Text(card.item.title)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(page?.ink ?? Theme.txt)
            V2ItemMarkLine(item: card.item, spacing: 6) {
                Text(card.reason)
                    .font(.system(size: 14))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            V2ItemTickets(item: card.item)
                .padding(.top, 4)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        // Wider than the card, as the mock's centred caption.
        .frame(width: width + 60)
    }
}
