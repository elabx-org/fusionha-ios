import SwiftUI
import FusionhaKit

/// The poster-led page's hero on a phone (mock "Closed", option A): the
/// poster full width at its own 2:3, never taller than 680pt, its foot
/// shaded into the page tint, and on that foot the title and meta line in
/// white. Content, not glass.
struct V2PosterHero: View {
    let detail: ItemDetail
    /// The page's width; the hero's height follows the poster's shape.
    let width: CGFloat

    @Environment(\.detailInColumn) private var inColumn
    @Environment(\.pagePalette) private var page
    private var light: Bool { page?.isLight ?? Theme.isLight }

    /// The poster's own 2:3, never taller than 680pt. Beside the list on the
    /// open Duo it also stops at 68% of the page, so the summary shows under
    /// it (at its full height it filled the whole right page) and still
    /// starts below the column's buttons when the page runs edge to edge.
    static func height(width: CGFloat, container: CGFloat, inColumn: Bool) -> CGFloat {
        let full = min(max(width, 300) * 1.5, 680)
        return inColumn ? min(full, max(300, container * 0.68)) : full
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical) { length, _ in
                Self.height(width: width, container: length, inColumn: inColumn)
            }
            .background { V2PosterHeroArt(poster: detail.posterUrl, backdrop: detail.backdropUrl) }
            // On the hero's bottom edge: the title, the meta line and "Metadata
            // via", for a movie and a series alike. The art frosts and
            // dissolves into the page under them (`V2PosterHeroArt`): on
            // light palettes they take the page's ink, on dark ones a soft
            // shadow sits behind the text only (owner, 2026-11-18, mock
            // "Hero Fade Options": frost).
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    V2TitleHeading(detail: detail, size: 30, ink: light ? (page?.ink ?? Theme.txt) : nil)
                    V2TitleCredit(detail: detail).font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(alignment: .bottomLeading) {
                    if !light {
                        RadialGradient(colors: [.black.opacity(0.42), .clear], center: .bottomLeading,
                                       startRadius: 10, endRadius: 320)
                            .frame(width: 520, height: 240)
                            .offset(x: -40, y: 40)
                            .allowsHitTesting(false)
                    }
                }
            }
            .duoTitleSwipe(id: detail.id)
    }

}

/// The hero's art, shared with the loading shell (`V2PosterLoadingShell`)
/// so the page fills in where the shell stood: the poster, the hero shade
/// and the deeper foot. Eases in once per poster (`HeroArtReveal`), so the
/// loaded page never fades the shell's art out and in again.
struct V2PosterHeroArt: View {
    let poster: String?
    let backdrop: String?
    @Environment(\.pagePalette) private var page
    @Environment(\.motionEnabled) private var motion
    @State private var shown: Bool

    init(poster: String?, backdrop: String?) {
        self.poster = poster
        self.backdrop = backdrop
        _shown = State(initialValue: Self.url(poster, backdrop).map { HeroArtReveal.shown.contains($0) } ?? false)
    }

    static func url(_ poster: String?, _ backdrop: String?) -> URL? {
        TMDBImage.resized(poster ?? backdrop, to: "w780")
    }

    private var light: Bool { page?.isLight ?? Theme.isLight }

    /// The poster at its own 2:3 across the width, its top at the hero's
    /// top: beside the list the hero is shorter than the poster, and a
    /// centred crop cut the heads off (owner, 2026-11-18: top crop).
    private var art: some View {
        GeometryReader { proxy in
            let full = max(proxy.size.height, proxy.size.width * 1.5)
            PosterImage(url: Self.url(poster, backdrop))
                .frame(width: proxy.size.width, height: full)
                // Mock (2026-11-18): start the crop a quarter of the way down
                // the poster's overflow instead of at its top.
                .offset(y: MockFlag.value("HERO_CROP") == "quarter" ? -(full - proxy.size.height) * 0.25 : 0)
        }
        .clipped()
    }

    var body: some View {
        // Frost (owner, 2026-11-18, mock "Hero Fade Options"): no tint over the
        // art; its lower part blurs as the whole art dissolves into the page's
        // own wash, so it ends in a blend and the poster's lettering frosts away.
        ZStack {
            art
                .scaleEffect(shown || !motion ? 1 : 1.04)
                .opacity(shown || !motion ? 1 : 0)
            art
                .blur(radius: 26, opaque: true)
                .mask(V2HeroFrost.blurMask)
                .opacity(shown || !motion ? 1 : 0)
            V2HeroShade(light: light, tint: page?.tint)
        }
        .mask(V2HeroFrost.dissolveMask)
        // Clipped inside its extended frame, so the art runs under the
        // Duo's system column and the glass bar floats over it (v1
        // c3c9e0d8: clipping the hero's own frame left a dark strip).
        .clipped()
        .ignoresSafeArea(.container, edges: .horizontal)
        // And to the band's own top and bottom: inside the extended frame
        // the art still drew past them (owner, build 1143: it ran 40pt
        // under the tabs and ended in a hard line).
        .clipShape(HeroBleedClip())
        .accessibilityHidden(true)
        .onAppear {
            if let url = Self.url(poster, backdrop) { HeroArtReveal.shown.insert(url) }
            guard motion, !shown else { return }
            withAnimation(.easeOut(duration: 0.7)) { shown = true }
        }
    }
}

/// The poster heroes' frost: where the art blurs, and where it dissolves
/// into the page (split, folded and the open Duo's band alike).
enum V2HeroFrost {
    static let blurMask = LinearGradient(stops: [.init(color: .clear, location: 0.42), .init(color: .black, location: 0.82)],
                                         startPoint: .top, endPoint: .bottom)
    static let dissolveMask = LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.5),
                                                     .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
}
