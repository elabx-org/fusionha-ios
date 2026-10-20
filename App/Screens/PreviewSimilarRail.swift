import SwiftUI
import FusionhaKit

/// "More like this": a rail of poster cards that each push another preview.
extension PreviewPage {
    func similarRail(_ cards: [SimilarCard]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    NavigationLink(value: PreviewRoute(kind: card.kind == .movie ? .movie : .series, tmdbId: card.tmdbId)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Color.clear
                                .aspectRatio(2 / 3, contentMode: .fit)
                                .overlay { DiscoverArt(url: TMDBImage.resized(card.posterUrl, to: "w500")) }
                                .background(Theme.panel2)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
                                .shadow(color: .black.opacity(0.55), radius: 12, y: 12)
                                .overlay(alignment: .topTrailing) {
                                    if card.inLibrary { PosterStatusBadge(kind: .inLibrary).padding(8) }
                                }
                                .padding(.bottom, 6)
                            Text(card.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                            if let year = card.year {
                                Text(verbatim: "\(year)").font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                            }
                        }
                    }
                    .buttonStyle(DiscoverPressStyle())
                    .containerRelativeFrame(.horizontal) { width, _ in (width - 32) / 3 }
                    .discoverReveal(index: index)
                }
            }
        }
        .scrollClipDisabled()
    }
}
