import SwiftUI
import FusionhaKit

/// The poster-led title filling the flat open Duo (mock "Open, list
/// hidden"), on the spread rule: the backdrop is ONE band across both
/// pages, the album cover with the title and meta line on its left, the
/// right half left as art. Below the band both pages start on one line:
/// today's summary on the left, the tabs on the right (never on the art).
/// One scroll. Behind `TitleLook.posterKey`.
struct V2PosterWidePage: View {
    @Environment(\.pagePalette) private var page
    @Environment(\.v2TitleBarInset) private var barInset
    let detail: ItemDetail
    /// The page's width (the whole display).
    let width: CGFloat

    static let posterWidth: CGFloat = 218
    static func leftWidth(_ width: CGFloat) -> CGFloat { min(400, max(320, (width * 0.38).rounded())) }
    private var leftWidth: CGFloat { Self.leftWidth(width) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 16) {
                V2PosterCover(poster: detail.posterUrl, backdrop: detail.backdropUrl, width: Self.posterWidth)
                V2PosterCoverHeading(detail: detail)
            }
            .frame(width: leftWidth)
            .padding(.leading, V2TitleWide.gutter)
            .padding(.top, barInset + 8)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { V2PosterWideHero(backdrop: detail.backdropUrl, poster: detail.posterUrl) }
            .duoTitleSwipe(id: detail.id)
            HStack(alignment: .top, spacing: V2TitleWide.columnGap) {
                VStack(alignment: .leading, spacing: 0) {
                    V2TitleSummary(detail: detail, small: true, stacksActions: true)
                    if detail.isSeries {
                        V2TitleCredit(detail: detail).font(.system(size: 13)).padding(.top, 28)
                    }
                }
                .frame(width: leftWidth)
                V2TitleTabs(detail: detail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, V2TitleWide.gutter)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .foregroundStyle(page?.ink ?? Theme.txt)
    }
}

/// The open page's poster: today's 14pt card corner and the cards' pre-rendered shadow, so
/// it sits on the hero like an album cover.
struct V2PosterCover: View {
    @Environment(\.pagePalette) private var page
    let poster: String?
    let backdrop: String?
    let width: CGFloat

    var body: some View {
        PosterImage(url: TMDBImage.resized(poster ?? backdrop, to: "w500"))
            .frame(width: width, height: width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            // Pre-blurred nine-slice: a live `.shadow` re-blurs every frame
            // of the scroll (open-Duo perf rule).
            .background { ModuleShadow(radius: 14, light: page?.isLight ?? Theme.isLight) }
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
                .accessibilityAddTraits(.isHeader)
            V2TitleMetaLine(detail: detail)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
    }
}

/// The band's art: today's backdrop full width behind both pages, under
/// the hero shade, ending like `V2TitleBand`.
struct V2PosterWideHero: View {
    let backdrop: String?
    let poster: String?
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown: Bool

    init(backdrop: String?, poster: String?) {
        self.backdrop = backdrop
        self.poster = poster
        // Eases in once per art: the loading shell already showed it.
        _shown = State(initialValue: ItemDetailArt.hero(backdrop: backdrop, poster: poster)
            .map { HeroArtReveal.shown.contains($0) } ?? false)
    }

    private var light: Bool { page?.isLight ?? Theme.isLight }
    private var ground: Color { page?.tint ?? Theme.bg }

    var body: some View {
        ZStack {
            PosterImage(url: ItemDetailArt.hero(backdrop: backdrop, poster: poster))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .opacity(shown || !motion ? 1 : 0)
            V2HeroShade(light: light, tint: page?.tint)
            // Ends like today's band: a short fade into the page tint on dark
            // palettes, the shade's warm dark edge on light ones (white title).
            if !light {
                LinearGradient(colors: [ground.opacity(0), ground.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 22)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .clipped()
        .ignoresSafeArea(.container, edges: .horizontal)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if let url = ItemDetailArt.hero(backdrop: backdrop, poster: poster) { HeroArtReveal.shown.insert(url) }
            guard motion, !shown else { return }
            withAnimation(.easeOut(duration: 0.5)) { shown = true }
        }
    }
}
