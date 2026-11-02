import SwiftUI
import FusionhaKit

/// The title page's hero backdrop (owner-approved with the web, 2026-11-02):
/// the textless art runs behind the whole header, from under the bar to the
/// top of Versions, and fades out with no edge (`HeroBackdropProfile`).
///
/// - The sharp art keeps the approved hero's framing: its box is the hero's
///   height, or a 16:9 backdrop's own height on a wide display, so it is
///   never zoomed to fill a taller header. Below it the same art carries on
///   blurred (mirrored, so its colours meet), the tint it fades into.
/// - The white title sits on the art's darkened edge in every theme; below
///   it a wash of the ground colour sits behind the text column.
/// - On a wide single column the far side stays clear; on the open Duo both
///   pages hold text, so both keep the wash, and each page's art fades out
///   at its own foot (the left page's follows Versions as it scrolls).
///
/// The art always runs under the system column; `underBar` lifts the frame
/// up under the bar (the open Duo's band, whose top is `layout.originY`).
struct DetailHeroBackdrop: View {
    @Environment(\.detailReduceMotion) private var reduce
    let url: URL?
    let layout: HeroBackdropLayout
    var underBar = false
    @State private var artShown: Bool

    init(url: URL?, layout: HeroBackdropLayout, underBar: Bool = false) {
        self.url = url
        self.layout = layout
        self.underBar = underBar
        // The loading shell already eased this art in: no second zoom.
        _artShown = State(initialValue: url.map { HeroArtReveal.shown.contains($0) } ?? false)
    }

    var body: some View {
        GeometryReader { proxy in
            // How far the frame runs up under the bar: from the header's
            // measured top (global), not the safe-area insets, which the
            // Duo's shell and harness report differently.
            let top = layout.originY.map { max(0, $0 - proxy.frame(in: .global).minY) } ?? 0
            let lead = proxy.safeAreaInsets.leading
            let width = proxy.size.width
            let height = top + layout.lowest + HeroBackdropLayout.tail
            let artBottom = max(layout.edge, min(width * 9 / 16 - top, layout.lowest))
            layers(top: top, width: width, height: height, artBottom: artBottom, lead: lead)
        }
        .ignoresSafeArea(.container, edges: underBar ? [.top, .horizontal] : .horizontal)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func layers(top: CGFloat, width: CGFloat, height: CGFloat, artBottom: CGFloat, lead: CGFloat) -> some View {
        let ground = Theme.isLight ? 0.9 : 0.85
        let near = HeroBackdropProfile(layout: layout, top: top, height: height, artBottom: artBottom,
                                       foot: layout.foot, ground: ground)
        let far = HeroBackdropProfile(layout: layout, top: top, height: height, artBottom: artBottom,
                                      foot: layout.farFoot ?? layout.foot, ground: ground)
        let column = layout.column.map { lead + $0 }
        let shadeColumn = (layout.shadeColumn ?? layout.column).map { lead + $0 }
        return ZStack(alignment: .top) {
            if url != nil {
                // Starts under the sharp art's fade, wherever its foot puts it.
                continuation(from: max(0, top + min(artBottom, min(near.foot, far.foot)) - 96),
                             width: width, height: height)
                    .mask { HeroSplit(column: column, width: width) { near.continuationMask() } far: { far.continuationMask() } }
            }
            art
                .frame(width: width, height: top + artBottom)
                .clipped()
                .frame(width: width, height: height, alignment: .top)
                .mask { HeroSplit(column: column, width: width) { near.sharpMask() } far: { far.sharpMask() } }
            HeroSplit(column: shadeColumn, width: width) {
                near.titleShade(Theme.scrim)
            } far: {
                if layout.style == .band { far.farShade(Theme.scrim) } else { far.titleShade(Theme.scrim) }
            }
            HeroSplit(column: column, width: width) {
                near.groundWash(Theme.bg)
            } far: {
                if layout.farWash { far.groundWash(Theme.bg) } else { Color.clear }
            }
        }
        .frame(width: width, height: height, alignment: .top)
    }

    /// The art's blurred continuation under the sharp box (the cached
    /// ambient bitmap, no live blur), mirrored so its top meets the art's foot.
    private func continuation(from y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                AmbientArt(url: TMDBImage.resized(url?.absoluteString, to: "w780"), kind: .detailAmbient)
                    .scaleEffect(x: 1, y: -1)
                    .frame(width: width, height: max(height - y, 1))
                    .offset(y: y)
            }
            .clipped()
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
        if let url { HeroArtReveal.shown.insert(url) }
        guard !reduce, !artShown else { return }
        withAnimation(DetailMotion.reveal(0.9)) { artShown = true }
    }
}
