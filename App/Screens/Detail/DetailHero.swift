import SwiftUI
import FusionhaKit

/// The full-bleed art hero (MobileDetailFlyout, redesign `.hero` + `.d-head`):
/// the poster bleeds to the top edge and fades into the ground (Close is the
/// system toolbar's, DC10); then the status chip, the display-face title + year,
/// tagline, meta line and genre pills, rising over the faded art. Nothing is
/// drawn on the art itself: the heading only starts where it has faded.
struct DetailHero: View {
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail

    /// How far the heading rises over the bottom of the art.
    private static let overlap: CGFloat = 132

    private var artURL: URL? {
        // Full-bleed on a @3x phone the poster is ~1200px wide, past w780;
        // the pipeline decodes `original` down to the hero's own pixel size.
        TMDBImage.resized(detail.posterUrl ?? detail.backdropUrl, to: "original")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailHeroArt(url: artURL)
            heading
                .padding(.horizontal, Theme.pageGutter)
                .padding(.top, -Self.overlap)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let status = detail.status, !status.isEmpty {
                HeroStatusChip(status: status)
                    .padding(.bottom, 12)
                    .detailReveal(delay: 0.05)
            }
            title.detailReveal(delay: 0.1)
            if let tagline = detail.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 10)
                    .detailReveal(delay: 0.13)
            }
            HeroMetaLine(detail: detail)
                .padding(.top, 10)
                .detailReveal(delay: 0.16)
            if let genres = detail.genres, !genres.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.mut)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .overlay(Capsule().strokeBorder(Theme.line))
                    }
                }
                .padding(.top, 12)
                .detailReveal(delay: 0.2)
            }
            RequestedByPill()
                .padding(.top, 12)
                .detailReveal(delay: 0.22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `Andor 2022`: the display face, the year a quieter semibold.
    private var title: some View {
        (Text(detail.title).foregroundColor(Theme.txt)
            + Text(verbatim: detail.year.map { " " + String($0) } ?? "")
                .font(Theme.display(56, semibold: true))
                .foregroundColor(Theme.dim))
            .font(Theme.display(56))
            .tracking(Theme.displayTracking(56))
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The status chip (MobileHero `.chip`): a clock glyph and the status in
/// 11pt mono uppercase, on a wash toned by the status (hero-tone.ts: ok /
/// amber / neutral).
private struct HeroStatusChip: View {
    let status: String

    private var tone: (Color, MonoToken)? {
        let s = status.lowercased()
        if s.range(of: "released|available|ended", options: .regularExpression) != nil { return (Theme.done, .done) }
        if s.range(of: "continuing|returning|airing|on air|production|planned|upcoming", options: .regularExpression) != nil {
            return (Theme.onair, .onair)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock").font(.system(size: 11, weight: .bold))
            Text(status.uppercased()).tracking(0.5)
        }
        .font(.system(size: 11, weight: .heavy, design: .monospaced))
        .foregroundStyle(tone.map { $0.0.mix(0.6, Theme.txt) } ?? Theme.mut)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .actWash(tone?.0, mono: tone?.1, radius: 999, base: Theme.bg.opacity(0.85))
        .accessibilityLabel("Status: \(status)")
    }
}

/// `Series · 2 versions · 47 min · ★ 8.4 · TV-14` (`.d-meta`). The
/// "Metadata via" credit sits at the foot of the page (`.credit`).
private struct HeroMetaLine: View {
    let detail: ItemDetail

    private var kindLabel: String {
        if detail.isAnime == true { return detail.kind == .movie ? "Anime Movie" : "Anime" }
        return detail.kind == .movie ? "Movie" : "Series"
    }

    var body: some View {
        let count = detail.editions.count
        FlowRow(spacing: 6, lineSpacing: 4) {
            Text(kindLabel)
            if count > 0 {
                dotSep
                Text("\(count) version\(count == 1 ? "" : "s")")
            }
            if let runtime = detail.runtime, runtime > 0 {
                dotSep
                Text("\(runtime) min")
            }
            if let vote = detail.voteAverage, vote > 0 {
                dotSep
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 12))
                    Text(String(format: "%.1f", vote))
                }
                .fontWeight(.semibold)
                .foregroundStyle(Theme.txt)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rated \(String(format: "%.1f", vote))")
            }
            if let cert = detail.certification, !cert.isEmpty {
                dotSep
                Text(cert)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
                    .accessibilityLabel("Rated \(cert)")
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(Theme.mut)
    }

    private var dotSep: some View {
        Text("·").foregroundStyle(Theme.dim)
    }
}

/// "Metadata via [wordmark]" (the web's `MetadataCredit`): the resolved
/// provider's real mark, or the Hybrid ring mark with the sources it blends.
/// Shown as the page's foot credit.
struct MetadataCredit: View {
    let provider: String

    var body: some View {
        HStack(spacing: 5) {
            Text("Metadata via")
            switch provider {
            case "tvdb": TvdbLogo(size: 13, label: "TheTVDB")
            case "tvmaze": TvmazeLogo(size: 13, label: "TVmaze")
            case "hybrid":
                HybridMark(size: 16, label: "Hybrid metadata (TMDB + TheTVDB)")
                Text("TMDB + TheTVDB").accessibilityHidden(true)
            default: TmdbLogo(size: 13, label: "The Movie Database")
            }
        }
        .accessibilityElement(children: .combine)
    }
}
