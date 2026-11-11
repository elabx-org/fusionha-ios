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
            .overlay(alignment: .bottomLeading) {
                V2TitleHeading(detail: detail, size: 30)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
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

    var body: some View {
        ZStack {
            PosterImage(url: Self.url(poster, backdrop))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .scaleEffect(shown || !motion ? 1 : 1.04)
                .opacity(shown || !motion ? 1 : 0)
            V2HeroShade(light: light, tint: page?.tint)
            V2PosterFoot(light: light, tint: page?.tint)
        }
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

/// A poster carries its own title and credits low down; this deeper foot
/// keeps them from showing through the white title (the mock's fade:
/// most of the tint by two thirds down). Light palettes keep the hero
/// shade's dark edge, which the white title needs.
struct V2PosterFoot: View {
    let light: Bool
    let tint: Color?

    var body: some View {
        let foot = light ? Color(red: 30 / 255, green: 18 / 255, blue: 12 / 255) : (tint ?? Theme.bg)
        LinearGradient(stops: [
            .init(color: foot.opacity(0), location: 0.42),
            .init(color: foot.opacity(light ? 0.35 : 0.6), location: 0.6),
            .init(color: foot.opacity(light ? 0.55 : 0.88), location: 0.8),
            .init(color: foot.opacity(light ? 0.6 : 0.96), location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }
}
