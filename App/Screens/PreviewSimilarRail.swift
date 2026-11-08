import SwiftUI
import FusionhaKit

/// "More like this": a rail of poster cards that each push another preview.
/// v1 badges a title you have on its art; v2 keeps the art clean and puts
/// the owned title's HD/4K tickets under it (`BrowseLookOverride.tickets`).
struct PreviewSimilarRail: View {
    @Environment(\.browseLook) private var look
    @Environment(\.pagePalette) private var page
    @Environment(AppModel.self) private var model
    let cards: [SimilarCard]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    NavigationLink(value: PreviewRoute(kind: card.kind == .movie ? .movie : .series, tmdbId: card.tmdbId)) {
                        tile(card)
                    }
                    .buttonStyle(DiscoverPressStyle())
                    .containerRelativeFrame(.horizontal) { width, _ in (width - 32) / 3 }
                    .discoverReveal(index: index)
                }
            }
        }
        .scrollClipDisabled()
    }

    private func tile(_ card: SimilarCard) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            art(card).padding(.bottom, 6)
            Text(card.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(page?.ink ?? Theme.txt)
                .lineLimit(1)
            if let year = card.year {
                Text(verbatim: "\(year)").font(.system(size: 11.5)).foregroundStyle(page?.inkMuted ?? Theme.mut)
            }
            if let look, card.inLibrary, let item = owned(card) {
                look.tickets(item).padding(.top, 3)
            }
        }
    }

    @ViewBuilder
    private func art(_ card: SimilarCard) -> some View {
        let poster = Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { DiscoverArt(url: TMDBImage.resized(card.posterUrl, to: "w500")) }
        if look != nil {
            poster.shelfPoster(radius: 12)
        } else {
            poster
                .background(Theme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
                .shadow(color: .black.opacity(0.55), radius: 12, y: 12)
                .overlay(alignment: .topTrailing) {
                    if card.inLibrary { PosterStatusBadge(kind: .inLibrary).padding(8) }
                }
        }
    }

    private func owned(_ card: SimilarCard) -> MediaItem? {
        model.library.first { $0.tmdbId == card.tmdbId && $0.kind == card.kind }
    }
}
