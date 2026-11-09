import SwiftUI
import FusionhaKit

extension View {
    /// Puts a v2 page on its ground: the palette of `art` (a sample URL from
    /// `PageArtSource.url(backdrop:poster:)`, or nil for the tint ground)
    /// lifted for the active palette, behind the page and down the
    /// environment (`\.pagePalette` and the badge ink), so cards, text inks
    /// and badges follow the art. `showsArt` adds the blurred art across the
    /// top (off where the page draws its own hero art). `tokens` overrides
    /// the active palette (the gallery's per-palette previews).
    func v2PageGround(art: URL?, recipe: PageGround.Recipe = .page, showsArt: Bool = true,
                      artHeight: CGFloat = 760, artOpacity: GroundArtOpacity = .w1,
                      tokens: PaletteTokens? = nil) -> some View {
        modifier(PageGroundModifier(art: art, recipe: recipe, showsArt: showsArt, artHeight: artHeight,
                                    artOpacity: artOpacity, tokens: tokens))
    }
}

/// Loads the art's colours once per URL (`ArtPaletteExtractor`); a cached
/// palette paints on the first frame, a new one fades in.
struct PageGroundModifier: ViewModifier {
    let art: URL?
    let recipe: PageGround.Recipe
    let showsArt: Bool
    var artHeight: CGFloat = 760
    var artOpacity: GroundArtOpacity = .w1
    let tokens: PaletteTokens?
    @State private var loaded: (key: String, colors: [HSLColor])?
    /// Book pose: this page's ground is offered to the fold's gutter (`PaneGrounds`).
    @Environment(\.paneGrounds) private var grounds
    @Environment(\.bookPose) private var bookPose
    @State private var groundId = UUID()
    @State private var frame: CGRect = .zero

    func body(content: Content) -> some View {
        let _ = PerfCount.hit("PageGroundModifier.body")
        let t = tokens ?? Theme.palette
        let palette = dominant.map { PagePalette.art($0, tokens: t) } ?? .tokens(t)
        content
            .environment(\.pagePalette, palette)
            .badgeInk(palette.badgeInk(t))
            .background {
                PageGround(palette: palette, recipe: recipe,
                           artURL: showsArt && palette.fromArt ? art : nil, artHeight: artHeight,
                           artOpacity: artOpacity, tokens: t)
            }
            .task(id: art) { await load() }
            .onGeometryChange(for: CGRect.self) { proxy in
                let f = proxy.frame(in: .global)
                return CGRect(x: f.minX.rounded(), y: f.minY.rounded(), width: f.width.rounded(), height: f.height.rounded())
            } action: { frame = $0 }
            .onChange(of: report(palette), initial: true) { _, next in grounds?.set(groundId, next) }
            .onDisappear { grounds?.set(groundId, nil) }
    }

    /// What the gutter needs to paint this ground; nil off book pose.
    private func report(_ palette: PagePalette) -> PaneGrounds.Report? {
        guard bookPose, grounds != nil, frame.width > 0 else { return nil }
        return PaneGrounds.Report(palette: palette, recipe: recipe, art: showsArt ? art : nil,
                                  artHeight: artHeight, artOpacity: artOpacity, frame: frame)
    }

    private var dominant: [HSLColor]? {
        guard let art else { return nil }
        if let hit = ArtPaletteExtractor.shared.cached(art) { return hit }
        return loaded?.key == art.absoluteString ? loaded?.colors : nil
    }

    private func load() async {
        guard let art, ArtPaletteExtractor.shared.cached(art) == nil else { return }
        guard let colors = await ArtPaletteExtractor.shared.colors(for: art), !Task.isCancelled else { return }
        PerfCount.mark("ground.loaded")
        loaded = (art.absoluteString, colors)
    }
}
