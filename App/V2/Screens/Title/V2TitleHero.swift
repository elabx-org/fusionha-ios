import SwiftUI
import FusionhaKit

/// The v2 title hero (mock kit `heroBlock`, browse.js `heroLogo`): the
/// textless art full width, a shade that darkens only its foot, and on that
/// foot the title in white (text until the server sends a logo), the meta
/// line and, for a movie, the tagline. Dark palettes end in a short fade
/// into the page tint, so the page never drops to black under the art;
/// light palettes end on the art's own darkened edge (the mock).
/// Content, not glass.
struct V2TitleHero: View {
    let detail: ItemDetail
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    private var light: Bool { page?.isLight ?? Theme.isLight }
    private var art: URL? { ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl) }

    var body: some View {
        Color.clear
            .containerRelativeFrame(.vertical) { length, _ in Self.height(for: length, series: detail.isSeries) }
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    PosterImage(url: art)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .scaleEffect(shown || !motion ? 1 : 1.05)
                        .opacity(shown || !motion ? 1 : 0)
                    V2HeroShade(light: light, tint: page?.tint)
                    if !light {
                        LinearGradient(colors: [(page?.tint ?? Theme.bg).opacity(0), (page?.tint ?? Theme.bg).opacity(0.7)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 26)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipped()
                .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                V2TitleHeading(detail: detail)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
            .duoTitleSwipe(id: detail.id)
            .onAppear {
                guard motion, !shown else { return }
                withAnimation(.easeOut(duration: 0.7)) { shown = true }
            }
    }

    /// A share of the container: the mock's 372 for a series and 420 for a
    /// movie on an 874pt phone, never under 300 (or half a short display).
    static func height(for length: CGFloat, series: Bool) -> CGFloat {
        let floor = min(300, length * 0.5)
        return series ? min(max(length * 0.426, floor), 400) : min(max(length * 0.48, floor), 440)
    }
}

/// The hero's shade (kit.css `.hero .shade`, palette-lift.js): a light veil
/// under the bar, clear through the middle, then a foot for the white title.
/// Dark palettes darken the foot into the page tint (62% to 80%), never
/// black; light palettes keep the kit's warm dark edge.
struct V2HeroShade: View {
    let light: Bool
    let tint: Color?

    var body: some View {
        if light {
            let foot = Color(red: 30 / 255, green: 18 / 255, blue: 12 / 255)
            let end = Color(red: 60 / 255, green: 40 / 255, blue: 30 / 255)
            LinearGradient(stops: [
                .init(color: .black.opacity(0.30), location: 0),
                .init(color: .black.opacity(0), location: 0.26),
                .init(color: foot.opacity(0), location: 0.42),
                .init(color: foot.opacity(0.66), location: 0.80),
                .init(color: end.opacity(0.35), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        } else {
            let foot = tint ?? Color(red: 18 / 255, green: 10 / 255, blue: 8 / 255)
            LinearGradient(stops: [
                .init(color: .black.opacity(0.30), location: 0),
                .init(color: .black.opacity(0), location: 0.26),
                .init(color: foot.opacity(0), location: 0.46),
                .init(color: foot.opacity(tint == nil ? 0.78 : 0.62), location: 0.84),
                .init(color: foot.opacity(tint == nil ? 0.90 : 0.80), location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
    }
}

/// The block on the art's foot: white in every palette.
struct V2TitleHeading: View {
    let detail: ItemDetail
    var size: CGFloat = 34

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.title)
                .font(.system(size: size, weight: .heavy))
                .tracking(-size * 0.03)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.45), radius: 9, y: 2)
                .accessibilityAddTraits(.isHeader)
            V2TitleMetaLine(detail: detail)
            if !detail.isSeries, let tagline = detail.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.system(size: 14, weight: .medium).italic())
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(2)
                    .padding(.top, -2)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The network mark (series: the network, movie: the studio), then series:
/// year · genre · certificate · ★ rating; movie: year · certificate ·
/// runtime · ★ rating · two genres.
struct V2TitleMetaLine: View {
    let detail: ItemDetail

    var body: some View {
        V2NetworkMarkLine(studio: detail.networkMark) {
            HStack(spacing: 7) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if index > 0 { Text(verbatim: "·").opacity(0.6).accessibilityHidden(true) }
                    part
                }
            }
        }
        .font(.system(size: 13.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .combine)
    }

    private var parts: [AnyView] {
        var out: [AnyView] = []
        if let year = detail.year { out.append(AnyView(Text(verbatim: String(year)).monospacedDigit())) }
        let genres = detail.genres ?? []
        if detail.isSeries, let genre = genres.first { out.append(AnyView(Text(genre))) }
        if let cert = detail.certification, !cert.isEmpty {
            out.append(AnyView(Text(cert)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.55)))
                .accessibilityLabel("Rated \(cert)")))
        }
        if !detail.isSeries, let runtime = detail.runtime, runtime > 0 { out.append(AnyView(Text(Self.runtime(runtime)))) }
        if let vote = detail.voteAverage, vote > 0 {
            out.append(AnyView(HStack(spacing: 3) {
                Image(systemName: "star.fill").font(.system(size: 11))
                Text(String(format: "%.1f", vote))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rated \(String(format: "%.1f", vote))")))
        }
        if !detail.isSeries, !genres.isEmpty { out.append(AnyView(Text(genres.prefix(2).joined(separator: ", ")))) }
        return out
    }

    /// 137 → "2h 17m".
    static func runtime(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }
}
