import SwiftUI
import FusionhaKit

/// The hero's full-bleed art (owner-approved title page, 2026-10-23): the
/// textless backdrop at full strength in every theme, eased in from a slight
/// zoom (not under Reduce Motion). Only its bottom edge darkens, so a white
/// title reads on it; the page below starts on its own ground, tinted by the
/// art (`AmbientBackdrop`), never a milky fade. On the open Duo the art runs
/// on under the system column. Shared by the loaded hero and the loading shell.
struct DetailHeroArt<Overlay: View>: View {
    @Environment(\.detailReduceMotion) private var reduce
    let url: URL?
    /// What sits on the darkened bottom edge (the title block).
    @ViewBuilder var overlay: Overlay
    @State private var artShown = false

    var body: some View {
        Color.clear
            .containerRelativeFrame(.vertical) { length, _ in Self.height(for: length) }
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    art
                    edge
                }
                .ignoresSafeArea(.container, edges: .horizontal)
            }
            .clipped()
            .overlay(alignment: .bottomLeading) { overlay }
    }

    /// Half the container, at least 360 and at most 520, but the 360 floor
    /// gives way to 60% of a short container (the Duo's outer display held
    /// sideways, 466pt tall) so the heading and actions stay in view (D3).
    static func height(for length: CGFloat) -> CGFloat {
        min(max(length * 0.5, min(360, length * 0.6)), 520)
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
                // Also on the first layout (see `RevealModifier`).
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

    /// Only the edges darken: a light shade under the bar at the top, and the
    /// bottom edge the title sits on (the same scrim in every theme).
    private var edge: some View {
        LinearGradient(stops: [
            .init(color: Theme.scrim.opacity(0.28), location: 0),
            .init(color: .clear, location: 0.18),
            .init(color: .clear, location: 0.42),
            .init(color: Theme.scrim.opacity(0.55), location: 0.7),
            .init(color: Theme.scrim.opacity(0.82), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }

}

extension DetailHeroArt where Overlay == EmptyView {
    init(url: URL?) {
        self.init(url: url) { EmptyView() }
    }
}

extension ItemDetailArt {
    /// The hero prefers the textless backdrop: a portrait poster carries its
    /// printed title, which ghosted behind ours (the "king" behind "Breaking Bad").
    static func hero(backdrop: String?, poster: String?) -> URL? {
        TMDBImage.resized(backdrop ?? poster, to: "original")
    }
}

/// Art choices shared by the title page's hero, loading shell and ambient.
enum ItemDetailArt {}
