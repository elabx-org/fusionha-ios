import SwiftUI
import FusionhaKit

/// The request sheet's art pane (web `RequestModalArt.tsx`): kind pill,
/// poster, title, facts, genres and overview.
struct RequestModalArt: View {
    let pick: MediaSearchResult
    let preview: MediaPreviewDetail?

    private var isSeries: Bool { pick.kind == .series }

    /// Year, then runtime or the season count (Specials counted, as on the web).
    private var facts: String? {
        RequestOffer.artFacts(year: preview?.year ?? pick.displayYear, isSeries: isSeries,
                              runtime: preview?.runtime, seasonCount: preview?.seasons?.count)
    }

    /// The pick's own overview first, then the preview's (the web's order).
    private var overview: String? {
        guard let text = pick.overview ?? preview?.overview, !text.isEmpty else { return nil }
        return text
    }

    var body: some View {
        let kindColor = pick.kind == .movie ? Theme.kindMovie : Theme.kindSeries
        VStack(spacing: 12) {
            Text(pick.kind == .movie ? "MOVIE · REQUEST" : "SERIES · REQUEST")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(kindColor)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(kindColor.opacity(0.15), in: Capsule())
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .frame(maxWidth: 190)
                .overlay { DiscoverArt(url: TMDBImage.resized(preview?.posterUrl ?? pick.posterUrl, to: "w780")) }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
                .shadow(color: Theme.shelfShadow.opacity(0.55), radius: 16, y: 12)
            Text(preview?.title ?? pick.title)
                .font(.system(size: 20, weight: .heavy)).tracking(-0.2)
                .foregroundStyle(Theme.txt)
                .multilineTextAlignment(.center)
            if let facts {
                Text(verbatim: facts).font(.system(size: 12.5)).foregroundStyle(Theme.mut)
            }
            if let genres = preview?.genres, !genres.isEmpty {
                HStack(spacing: 6) {
                    ForEach(genres.prefix(4), id: \.self) { genre in
                        Text(genre).font(.system(size: 11)).foregroundStyle(Theme.dim)
                            .padding(.horizontal, 9).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
            }
            if let overview {
                Text(overview).font(.system(size: 12)).foregroundStyle(Theme.dim)
                    .lineSpacing(3).lineLimit(6)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.top, 46).padding(.bottom, 20)
        .background(LinearGradient(colors: [kindColor.opacity(pick.kind == .movie ? 0.10 : 0.12), .clear],
                                   startPoint: .top, endPoint: .bottom))
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}
