import SwiftUI
import FusionhaKit

/// The landscape still: backdrop → poster → gradient, 108pt tall, clean (the air
/// window sits under it, never on the art).
struct WeekStill: View {
    let entry: CalendarEntry

    var body: some View {
        let src = entry.backdropUrl ?? entry.posterUrl
        PosterImage(url: TMDBImage.resized(src, to: entry.backdropUrl != nil ? "w1280" : "w342"))
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .clipped()
    }
}

/// The portrait / compact / accent poster (poster → backdrop → gradient), lit.
struct WeekPoster: View {
    let entry: CalendarEntry
    let style: WeekCardStyle

    private var size: CGSize {
        switch style {
        case .portrait: return CGSize(width: 48, height: 72)
        case .compact: return CGSize(width: 18, height: 27)
        default: return CGSize(width: 24, height: 36)
        }
    }

    var body: some View {
        PosterImage(url: TMDBImage.resized(entry.posterUrl ?? entry.backdropUrl, to: "w154"))
            .frame(width: size.width, height: size.height)
            .shelfPoster(radius: style == .portrait ? 5 : 3, shadow: false)
    }
}

/// Code · `#N · Anime` · episode name.
struct WeekCardSub: View {
    let entry: CalendarEntry
    let leadingGlyph: Bool

    var body: some View {
        HStack(spacing: 6) {
            if leadingGlyph {
                LineGlyph(kind: LineGlyph.kind(for: entry), size: 13).foregroundStyle(Theme.mut)
            }
            Text(entry.code).fontWeight(.semibold).foregroundStyle(Theme.txt).monospacedDigit()
            if entry.isAnime, let abs = entry.absoluteNumber {
                Text("#\(abs) · Anime").fontWeight(.semibold).foregroundStyle(Theme.anime)
            }
            if !entry.isMovie, let name = entry.episodeTitle, !name.isEmpty {
                Text(name).foregroundStyle(Theme.mut)
            }
        }
        .font(.system(size: 13))
        .lineLimit(1)
    }
}
