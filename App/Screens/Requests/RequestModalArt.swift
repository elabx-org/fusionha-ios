import SwiftUI
import FusionhaKit

/// The request sheet's art pane (web `RequestModalArt.tsx`): kind pill,
/// poster, title, facts, genres and overview.
struct RequestModalArt: View {
    let pick: MediaSearchResult
    let preview: MediaPreviewDetail?
    /// Wide (two panes): the art is the leading column; the modal rules its edge.
    var sidePane = false

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
        if ProductLook.isV2 {
            if sidePane { columnV2 } else { headerV2 }
        } else {
            bodyV1
        }
    }

    private var bodyV1: some View {
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
        .overlay(alignment: .bottom) {
            if !sidePane { Rectangle().fill(Theme.line).frame(height: 1) }
        }
    }

    // MARK: v2 (look pass family 5)

    /// "SERIES · REQUEST" in the muted ink, never the kind's hue.
    private var eyebrow: some View {
        Text(pick.kind == .movie ? "Movie · Request" : "Series · Request")
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Theme.mut)
    }

    private func poster(width: CGFloat, radius: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: width * 1.5)
            .overlay { DiscoverArt(url: TMDBImage.resized(preview?.posterUrl ?? pick.posterUrl, to: "w342")) }
            .shelfPoster(radius: radius)
            .accessibilityHidden(true)
    }

    /// One column: the clean poster beside the eyebrow, title, facts and
    /// three lines of overview.
    private var headerV2: some View {
        HStack(alignment: .top, spacing: 14) {
            poster(width: 76, radius: 10)
            VStack(alignment: .leading, spacing: 4) {
                eyebrow
                Text(preview?.title ?? pick.title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                if let facts {
                    Text(verbatim: facts).font(.system(size: 13)).foregroundStyle(Theme.mut)
                }
                if let genres = preview?.genres, !genres.isEmpty {
                    Text(genres.prefix(3).joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                if let overview {
                    Text(overview).font(.system(size: 13)).foregroundStyle(Theme.txt.opacity(0.85))
                        .lineLimit(3).padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 6)
    }

    /// The wide art pane (two panes, the open Duo): the same facts stacked
    /// under a larger clean poster.
    private var columnV2: some View {
        VStack(spacing: 12) {
            eyebrow
            poster(width: 170, radius: 14)
            Text(preview?.title ?? pick.title)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.txt)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let facts {
                Text(verbatim: facts).font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            if let genres = preview?.genres, !genres.isEmpty {
                Text(genres.prefix(4).joined(separator: " · ")).font(.system(size: 13)).foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
            }
            if let overview {
                Text(overview).font(.system(size: 13)).foregroundStyle(Theme.txt.opacity(0.85))
                    .lineSpacing(3).lineLimit(8)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20).padding(.top, 46).padding(.bottom, 20)
    }
}
