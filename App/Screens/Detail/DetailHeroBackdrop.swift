import SwiftUI
import FusionhaKit

/// The title page's hero backdrop (owner-approved with the web, 2026-11-02):
/// the textless art runs behind the whole header, not a band with a hard
/// bottom edge. Its top shade and the dark edge under the white title stay
/// (the same scrim in every theme); below the title a wash of the ground
/// colour sits behind the text column, and the art fades out over its lower
/// third into the art-tinted ground (`AmbientBackdrop`). On the open Duo the
/// text column is the left page: the far page keeps the art clear in the band
/// and lets it go just under it, where its tabs begin.
///
/// Geometry is in points from the top of the header; `underBar` lifts it
/// under the bar (the open Duo's band), and the art always runs under the
/// system column.
struct DetailHeroBackdrop: View {
    @Environment(\.detailReduceMotion) private var reduce
    let url: URL?
    let layout: HeroBackdropLayout
    /// The header starts below the bar: the art runs up under it.
    var underBar = false
    @State private var artShown = false

    var body: some View {
        GeometryReader { proxy in
            let top = underBar ? proxy.safeAreaInsets.top : 0
            let lead = proxy.safeAreaInsets.leading
            let size = CGSize(width: proxy.size.width, height: top + layout.height(fill: proxy.size.height - top))
            let profile = HeroBackdropProfile(layout: layout, top: top, size: size,
                                              ground: Theme.isLight ? 0.9 : 0.85,
                                              column: layout.column.map { lead + $0 })
            ZStack(alignment: .top) {
                art
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .mask { profile.split(near: profile.artMask(Color.black), far: profile.farArtMask(Color.black)) }
                profile.split(near: profile.titleShade(Theme.scrim), far: profile.farShade(Theme.scrim))
                profile.split(near: profile.groundWash(Theme.bg), far: Color.clear)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .ignoresSafeArea(.container, edges: underBar ? [.top, .horizontal] : .horizontal)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var art: some View {
        if url != nil {
            PosterImage(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                // Ken-Burns settle: the art eases in from a slight zoom.
                .scaleEffect(artShown || reduce ? 1 : 1.06)
                .opacity(artShown || reduce ? 1 : 0)
                .onAppear(perform: showArt)
                .onGeometryChange(for: Bool.self) { $0.size.width > 0 } action: { laidOut in
                    if laidOut { showArt() }
                }
        } else {
            RadialGradient(colors: [Theme.panel2, Theme.bg], center: .top, startRadius: 0, endRadius: 520)
        }
    }

    private func showArt() {
        guard !reduce, !artShown else { return }
        withAnimation(DetailMotion.reveal(0.9)) { artShown = true }
    }
}

/// Where the hero's art and washes sit, in points from the top of the header.
struct HeroBackdropLayout: Equatable {
    enum Style: Equatable {
        /// The single column's hero: the full art above the title.
        case hero
        /// The open Duo's band: a lighter shade over a shorter strip.
        case band
    }

    var style: Style = .hero
    /// The art's darkened edge: the white title block ends 14 to 18 pt above it.
    var edge: CGFloat
    /// Where the art has faded out under the text column (nil: the frame's foot).
    var end: CGFloat?
    /// The open Duo: the text column's width (the left page).
    var column: CGFloat?

    /// The text column's art and wash end here.
    func height(fill: CGFloat) -> CGFloat {
        max(end ?? fill, edge + 32)
    }
}
