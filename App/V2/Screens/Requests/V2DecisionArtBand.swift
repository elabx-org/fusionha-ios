import SwiftUI
import FusionhaKit

/// The decision card's art band (mock requests.js `.rq-art`): the title's
/// textless backdrop across the top of the card, darkened toward its foot,
/// with the clean poster, the title and "2018 · 2h 28m · Mystery, Drama"
/// over the dark end. The backdrop, genres and rating come from the
/// title's preview (`PreviewCache`, a GET the request rows already use);
/// until it loads, or when the title has no backdrop, the poster stands in,
/// blurred. The text is always white on the dark end, so it reads on every
/// palette, Daylight included.
struct V2DecisionArtBand: View {
    let request: MediaRequest
    let triage: RequestTriage?
    let preview: MediaPreviewDetail?
    var height: CGFloat = 190
    var posterWidth: CGFloat = 56
    /// The wide pane adds the rating to the line.
    var showsRating = false

    private var title: String { request.title ?? preview?.title ?? "TMDB #\(request.tmdbId)" }

    var body: some View {
        art
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .allowsHitTesting(false)
            .overlay {
                LinearGradient(stops: [.init(color: .black.opacity(0.05), location: 0),
                                       .init(color: .clear, location: 0.3),
                                       .init(color: Color(red: 8 / 255, green: 6 / 255, blue: 6 / 255).opacity(0.8), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { caption }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text([title, metaLine].filter { !$0.isEmpty }.joined(separator: ", ")))
    }

    @ViewBuilder
    private var art: some View {
        if let backdrop = preview?.backdropUrl {
            PosterImage(url: TMDBImage.resized(backdrop, to: "w780"))
        } else {
            PosterImage(url: TMDBImage.resized(request.poster, to: "w342"))
                .blur(radius: 18)
                .scaleEffect(1.15)
        }
    }

    private var caption: some View {
        HStack(alignment: .bottom, spacing: 12) {
            PosterImage(url: TMDBImage.resized(request.poster ?? preview?.posterUrl, to: "w185"))
                .frame(width: posterWidth, height: posterWidth * 1.5)
                .shelfPoster(radius: 9)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.12)))
                .shadow(color: .black.opacity(0.5), radius: 9, y: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: height > 200 ? 28 : 24, weight: .bold))
                    .tracking(-0.4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                if !metaLine.isEmpty {
                    Text(metaLine)
                        .font(.footnote.weight(.medium))
                        .opacity(0.9)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    /// Year · kind (series only) · runtime · two genres · ★ rating (wide).
    private var metaLine: String {
        var parts: [String] = []
        if let year = request.year ?? preview?.year { parts.append(String(year)) }
        let kind = TriageFacts.kindText(request, isAnime: triage?.isAnime)
        if kind != "Movie" { parts.append(kind) }
        if let minutes = triage?.runtimeMinutes ?? preview?.runtime, minutes > 0 {
            parts.append(minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m")
        }
        if let genres = preview?.genres, !genres.isEmpty { parts.append(genres.prefix(2).joined(separator: ", ")) }
        if showsRating, let vote = preview?.voteAverage, vote > 0 {
            parts.append("★ " + String(format: "%.1f", vote))
        }
        return parts.joined(separator: " · ")
    }
}
