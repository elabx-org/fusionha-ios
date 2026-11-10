import SwiftUI
import FusionhaKit

/// The poster-led title filling the flat open Duo (mock "Open, list
/// hidden"): today's backdrop hero across the top, and over it two pages.
/// The left page is the album cover: the poster, the title and meta line
/// on the hero's dark foot, then today's summary. The right page is the
/// tabs. One scroll. Behind `TitleLook.posterKey`.
struct V2PosterWidePage: View {
    @Environment(\.pagePalette) private var page
    @Environment(\.v2TitleBarInset) private var barInset
    let detail: ItemDetail
    /// The page's width (the whole display).
    let width: CGFloat

    static let posterWidth: CGFloat = 218
    private var leftWidth: CGFloat { min(400, max(320, (width * 0.38).rounded())) }
    /// The hero runs down to just under the meta line.
    private var heroHeight: CGFloat { barInset + 8 + Self.posterWidth * 1.5 + 96 }

    var body: some View {
        HStack(alignment: .top, spacing: V2TitleWide.columnGap) {
            VStack(spacing: 0) {
                V2PosterCover(detail: detail, width: Self.posterWidth)
                V2PosterCoverHeading(detail: detail)
                    .padding(.top, 16)
                V2TitleSummary(detail: detail, small: true, stacksActions: true)
                    .padding(.top, 22)
                if detail.isSeries {
                    V2TitleCredit(detail: detail).font(.system(size: 13)).padding(.top, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: leftWidth)
            V2TitleTabs(detail: detail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, V2TitleWide.gutter)
        .padding(.top, barInset + 8)
        .padding(.bottom, 32)
        .background(alignment: .top) {
            V2PosterWideHero(detail: detail)
                .frame(height: heroHeight)
                .duoTitleSwipe(id: detail.id)
        }
        .foregroundStyle(page?.ink ?? Theme.txt)
    }
}

/// The open page's poster: today's 14pt card corner and a deep shadow, so
/// it sits on the hero like an album cover.
struct V2PosterCover: View {
    let detail: ItemDetail
    let width: CGFloat

    var body: some View {
        PosterImage(url: TMDBImage.resized(detail.posterUrl ?? detail.backdropUrl, to: "w500"))
            .frame(width: width, height: width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
            .accessibilityHidden(true)
    }
}

/// The title and meta line under the cover, centred, in white on the
/// hero's foot (as on every hero, so they read on every palette).
struct V2PosterCoverHeading: View {
    let detail: ItemDetail

    var body: some View {
        VStack(spacing: 6) {
            Text(detail.title)
                .font(.system(size: 26, weight: .heavy))
                .tracking(-0.7)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.45), radius: 9, y: 2)
                .accessibilityAddTraits(.isHeader)
            V2TitleMetaLine(detail: detail)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }
}

/// Today's backdrop hero, full width behind both pages, with the hero
/// shade and a long fade into the page's ground at its foot.
struct V2PosterWideHero: View {
    let detail: ItemDetail
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown = false

    private var light: Bool { page?.isLight ?? Theme.isLight }

    var body: some View {
        ZStack {
            PosterImage(url: ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .opacity(shown || !motion ? 1 : 0)
            V2HeroShade(light: light, tint: page?.tint)
        }
        .clipped()
        .ignoresSafeArea(.container, edges: .horizontal)
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.7),
                                     .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard motion, !shown else { return }
            withAnimation(.easeOut(duration: 0.5)) { shown = true }
        }
    }
}
