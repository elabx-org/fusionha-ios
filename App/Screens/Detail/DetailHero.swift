import SwiftUI
import FusionhaKit

/// The full-bleed art hero (MobileDetailFlyout): poster-first art fading out at
/// 74%, a floating glass close button, the status chip, title + year, tagline,
/// meta line and genre pills, bottom-aligned over the art.
struct DetailHero: View {
    @Environment(\.detailReduceMotion) private var reduce
    let detail: ItemDetail
    let close: () -> Void
    @State private var artShown = false

    private var artURL: URL? {
        TMDBImage.resized(detail.posterUrl ?? detail.backdropUrl, to: "w780")
    }

    var body: some View {
        // The art sizes the hero; the text is an overlay so it is proposed
        // exactly the hero's width (a ZStack sibling could be sized wider than
        // it is drawn, which made the meta/genre rows wrap after sizing).
        Color.clear
            .containerRelativeFrame(.vertical) { length, _ in min(max(length * 0.62, 430), 600) }
            .frame(maxWidth: .infinity)
            .background {
                art
                wash
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                if let status = detail.status, !status.isEmpty {
                    HeroStatusChip(status: status)
                        .padding(.bottom, 10)
                        .detailReveal(delay: 0.05)
                }
                title.detailReveal(delay: 0.1)
                if let tagline = detail.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.system(size: 13).italic())
                        .foregroundStyle(Theme.txt.opacity(0.86))
                        .padding(.top, 8)
                        .detailReveal(delay: 0.13)
                }
                HeroMetaLine(detail: detail)
                    .padding(.top, 12)
                    .detailReveal(delay: 0.16)
                if let genres = detail.genres, !genres.isEmpty {
                    FlowRow(spacing: 7) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Theme.txt.opacity(0.88))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.panel.opacity(0.55), in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.line))
                        }
                    }
                    .padding(.top, 12)
                    .detailReveal(delay: 0.2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay(alignment: .topLeading) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Color(red: 12 / 255, green: 13 / 255, blue: 17 / 255).opacity(0.5)).interactive(), in: .circle)
            .padding(.top, 14)
            .padding(.leading, 12)
            .accessibilityLabel("Close detail")
        }
    }

    @ViewBuilder
    private var art: some View {
        if artURL != nil {
            PosterImage(url: artURL)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .mask(LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.4),
                    .init(color: .clear, location: 0.74),
                ], startPoint: .top, endPoint: .bottom))
                // Ken-Burns settle: the art eases in from a slight zoom.
                .scaleEffect(artShown || reduce ? 1 : 1.06)
                .opacity(artShown || reduce ? 1 : 0)
                .onAppear {
                    guard !reduce else { return }
                    withAnimation(DetailMotion.reveal(0.9)) { artShown = true }
                }
        } else {
            RadialGradient(colors: [Color(hex: 0x1B1F2E), Theme.bg], center: .top, startRadius: 0, endRadius: 520)
        }
    }

    private var wash: some View {
        LinearGradient(stops: [
            .init(color: Theme.bg.opacity(0.14), location: 0),
            .init(color: .clear, location: 0.26),
            .init(color: Theme.bg.opacity(0.42), location: 0.62),
            .init(color: Theme.bg.opacity(0.3), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }

    private var title: some View {
        (Text(detail.title).foregroundColor(Theme.txt)
            + Text(verbatim: detail.year.map { " " + String($0) } ?? "")
                .foregroundColor(Theme.txt.mix(0.78, Theme.bg))
                .fontWeight(.semibold))
            .font(.system(size: 33, weight: .black))
            .tracking(-0.66)
            .shadow(color: .black.opacity(0.6), radius: 10, y: 3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Clock + uppercased status, toned by the status text (ok / amber / neutral).
private struct HeroStatusChip: View {
    let status: String

    private var tone: Color? {
        let s = status.lowercased()
        if s.range(of: "released|available|ended", options: .regularExpression) != nil { return Theme.done }
        if s.range(of: "continuing|returning|airing|on air|production|planned|upcoming", options: .regularExpression) != nil {
            return Theme.onair
        }
        return nil
    }

    var body: some View {
        let base = tone ?? Theme.mut
        HStack(spacing: 6) {
            Image(systemName: "clock").font(.system(size: 12, weight: .semibold))
            Text(status.uppercased())
        }
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .tracking(0.4)
        .foregroundStyle(tone.map { $0.mix(0.6, Theme.txt) } ?? Theme.mut)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(base.mix(tone == nil ? 0.12 : 0.24, Color(hex: 0x0A0C12)), in: Capsule())
        .overlay(Capsule().strokeBorder(base.opacity(0.3)))
    }
}

/// `Movie · 1 edition · 136 min · ★ 8.3 · [R] · Metadata via TMDB`.
private struct HeroMetaLine: View {
    let detail: ItemDetail

    private var kindLabel: String {
        if detail.isAnime == true { return detail.kind == .movie ? "Anime Movie" : "Anime" }
        return detail.kind == .movie ? "Movie" : "Series"
    }

    var body: some View {
        let count = detail.editions.count
        FlowRow(spacing: 7, lineSpacing: 6) {
            Text(kindLabel)
            dotSep
            Text("\(count) edition\(count == 1 ? "" : "s")")
            if let runtime = detail.runtime, runtime > 0 {
                dotSep
                Text("\(runtime) min")
            }
            if let vote = detail.voteAverage, vote > 0 {
                dotSep
                HStack(spacing: 4) {
                    Image(systemName: "star").font(.system(size: 13)).foregroundStyle(DetailTokens.star)
                    Text(String(format: "%.1f", vote))
                }
            }
            if let cert = detail.certification, !cert.isEmpty {
                dotSep
                Text(cert)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.line))
            }
            dotSep
            Text("Metadata via \(DetailText.provider(detail.resolvedMetadataProvider))")
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Theme.txt.opacity(0.8))
    }

    private var dotSep: some View {
        Text("·").opacity(0.5)
    }
}
