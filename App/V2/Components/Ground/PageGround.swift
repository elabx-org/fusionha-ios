import SwiftUI
import UIKit
import FusionhaKit

/// v2's page ground (owner 2026-11-05, mocks palette-lift.js and cards-w.js):
/// the art's three lifted colours as a soft mesh down the whole page, so a
/// title with near-black art never leaves the page near black. On it, across
/// the top, the art itself blurred and saturated (W1). With no art the
/// ground is the palette's own tint.
///
/// Content, not glass: it sits behind everything and takes no touches.
struct PageGround: View {
    enum Recipe: Sendable {
        /// A whole page.
        case page
        /// The open Duo's list pane beside a title: a deeper wash, no art.
        case listPane
    }

    let palette: PagePalette
    var recipe: Recipe = .page
    /// Drawn blurred across the top of a `.page` ground; nil for none.
    var artURL: URL?
    var artAspect: Double = 16 / 9
    /// How far down the art runs, and how strong it is (dark, light). W1
    /// pages keep the defaults; the Library's lighter layer is the mock's
    /// `.ambient` (browse.js, browse-lib.js).
    var artHeight: CGFloat = 760
    var artOpacity: GroundArtOpacity = .w1
    var tokens: PaletteTokens = Theme.palette

    @Environment(\.motionEnabled) private var motion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                GroundMesh(recipe: layers, size: proxy.size)
                if recipe == .page, let artURL {
                    PageGroundArt(url: artURL, aspect: artAspect, tokens: tokens)
                        .frame(width: proxy.size.width, height: min(proxy.size.height, artHeight))
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                                     .init(color: .black, location: 0.4),
                                                     .init(color: .clear, location: 1)],
                                             startPoint: .top, endPoint: .bottom))
                        .opacity(palette.isLight ? artOpacity.light : artOpacity.dark)
                        .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipped()
        }
        .animation(motion ? .easeInOut(duration: 0.45) : nil, value: palette)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var layers: GroundRecipe {
        switch recipe {
        case .page: return palette.recipe ?? .tint(tokens)
        case .listPane: return palette.paneRecipe ?? palette.recipe ?? .tint(tokens)
        }
    }
}

/// The ground art's opacity on dark and light palettes.
struct GroundArtOpacity: Equatable, Sendable {
    var dark: Double
    var light: Double

    /// cards-w.js `.ambient.w1g`.
    static let w1 = GroundArtOpacity(dark: 0.9, light: 0.55)
    /// The kit's `.ambient` (`--ambient-op` .62 dark, .42 light): the Library home.
    static let ambient = GroundArtOpacity(dark: 0.62, light: 0.42)
    /// browse-lib.js: the Library's grid and list, `--ambient-op` × .7.
    static let libraryList = GroundArtOpacity(dark: 0.434, light: 0.294)
}

/// A recipe's base and ellipses. Each ellipse gets its own frame, since a
/// CSS `radial-gradient(75% 38% at …)` is not the page's aspect. CSS paints
/// its first layer on top, so the first ellipse is drawn last.
private struct GroundMesh: View {
    let recipe: GroundRecipe
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hsl: recipe.top), Color(hsl: recipe.bottom)],
                           startPoint: .top, endPoint: .bottom)
            ForEach(Array(Array(recipe.ellipses.enumerated()).reversed()), id: \.offset) { _, e in
                EllipticalGradient(stops: [.init(color: Color(hsl: e.color, opacity: e.alpha), location: 0),
                                           .init(color: Color(hsl: e.color, opacity: 0), location: e.fade)],
                                   center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                    .frame(width: 2 * e.rx * size.width, height: 2 * e.ry * size.height)
                    .position(x: e.x * size.width, y: e.y * size.height)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

extension GroundRecipe {
    /// The ground with no art (cards-w.js `.w1-tint`), from the palette's
    /// tokens: the accent top left, the grab hue on the right, the edition
    /// hue at the foot, over the page colour. Hue-less palettes use their
    /// accent grey for all three.
    static func tint(_ t: PaletteTokens) -> GroundRecipe {
        let mono = PagePalette.dropsHue(t)
        let bg = hsl(t.bg)
        let k = t.isLight ? 0.5 : 1.0
        let i1 = hsl(t.i1), cyan = mono ? i1 : hsl(t.grab), violet = mono ? i1 : hsl(t.edition)
        return GroundRecipe(top: bg, bottom: bg, ellipses: [
            GroundEllipse(color: i1, alpha: 0.34 * k, x: 0.10, y: 0, rx: 1.2, ry: 0.55, fade: 0.70),
            GroundEllipse(color: cyan, alpha: (t.isLight ? 0.10 : 0.16), x: 1, y: 0.38, rx: 0.9, ry: 0.45, fade: 0.72),
            GroundEllipse(color: violet, alpha: (t.isLight ? 0.12 : 0.20), x: 0, y: 0.92, rx: 1.1, ry: 0.5, fade: 0.70),
        ])
    }

    private static func hsl(_ hex: UInt32) -> HSLColor {
        PaletteMath.hsl(r: Double((hex >> 16) & 0xFF), g: Double((hex >> 8) & 0xFF), b: Double(hex & 0xFF))
    }
}

/// The ground's blurred art: a cached `ArtBlurSpec.pageGround` bitmap (no
/// live blur), aspect-filled.
private struct PageGroundArt: View {
    let url: URL
    let aspect: Double
    let tokens: PaletteTokens
    @State private var loaded: (key: String, image: UIImage)?

    var body: some View {
        let spec = ArtBlurSpec.pageGround(tone: ArtTone(isLight: tokens.isLight, isMono: PagePalette.dropsHue(tokens)),
                                          aspect: aspect)
        let key = spec.key(for: url.absoluteString)
        let image = ArtBlurCache.shared.cached(key) ?? (loaded?.key == key ? loaded?.image : nil)
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        .scaleEffect(spec.overscanX)
                }
            }
            .clipped()
            .task(id: key) {
                guard ArtBlurCache.shared.cached(key) == nil else { return }
                guard let made = await ArtBlurCache.shared.image(for: url, spec: spec), !Task.isCancelled else { return }
                loaded = (key, made)
            }
    }
}
