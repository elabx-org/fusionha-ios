import SwiftUI
import UIKit

/// Pre-rendered bitmaps for the parts of a Library card that SwiftUI
/// otherwise rasterizes with Core Graphics on the main thread whenever a card
/// appears: a gradient (or stroked) shape is drawn into its layer's backing
/// store, and on the open Duo's 6-column grid that drawing was a third of the
/// main thread while scrolling (`argb32_shade_axial` in the perf job). Each
/// plate is rendered once per size and palette from the same SwiftUI shapes
/// (`ImageRenderer`), so it looks the same, and then shown as a plain image.
@MainActor
enum ShelfPlates {
    private static var cache: [String: UIImage] = [:]

    /// The palette the plates were drawn in (reading it registers the caller
    /// with `PaletteStore`, so it redraws on a switch).
    private static var palette: String { "\(PaletteStore.shared.active)" }

    private static func plate(_ key: String, _ make: () -> UIImage?) -> UIImage? {
        let key = "\(palette)|\(key)"
        if let hit = cache[key] { return hit }
        guard let made = make() else { return nil }
        if cache.count > 96 { cache.removeAll() }
        cache[key] = made
        return made
    }

    private static func render<V: View>(_ view: V, size: CGSize, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.isOpaque = false
        return renderer.uiImage
    }

    /// `PosterImage`'s loading ground (panel2 → card, top-leading to
    /// bottom-trailing) at the frame's aspect; a two-stop ramp stretches exactly.
    static func placeholder(aspect: CGFloat) -> UIImage? {
        let aspect = aspect > 0 && aspect.isFinite ? (aspect * 100).rounded() / 100 : 2 / 3
        return plate("placeholder|\(aspect)") {
            let size = CGSize(width: 120, height: (120 / aspect).rounded())
            return render(LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading,
                                         endPoint: .bottomTrailing), size: size, scale: 1)
        }
    }

    /// The lit poster's edge: the top-edge highlight and the hairline (or a
    /// selection ring), exactly as `shelfPoster` strokes them, for one size.
    static func edge(size: CGSize, radius: CGFloat, ring: Color, ringWidth: CGFloat, scale: CGFloat) -> UIImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let key = "edge|\(Int(size.width * 4))x\(Int(size.height * 4))|\(radius)|\(ring)|\(ringWidth)|\(scale)"
        return plate(key) {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            return render(ZStack {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top,
                                                  endPoint: .init(x: 0.5, y: 0.04)), lineWidth: 1)
                shape.strokeBorder(ring, lineWidth: ringWidth)
            }, size: size, scale: scale)
        }
    }

    /// The shelf's deep shadow, as a nine-slice drawn once per corner radius
    /// and theme: its corners and edges hold the whole blur, and the middle
    /// is flat, so it stretches to any card. A plate per card size re-blurred
    /// on the main thread whenever the grid's column width changed (a title
    /// opening or closing on the open Duo, the split handle), and the shared
    /// cache's reset re-blurred every size again.
    static func shadow(radius: CGFloat) -> (image: UIImage, insets: EdgeInsets, bleed: CGFloat)? {
        let isLight = Theme.isLight
        let blur: CGFloat = 11
        let bleed = ArtBlurRenderer.shadowBleed(blur: blur)
        // From the plate's edge: the bleed, then the blur's reach inside the
        // card (or its corner, if larger); past that the shadow is flat.
        let cap = bleed + max(radius, bleed) + 1
        let core = (cap - bleed) * 2 + 2
        let image = plate("shadow9|\(radius)|\(isLight)") {
            ArtBlurRenderer.shadow(size: CGSize(width: core, height: core), radius: radius, blur: blur,
                                   opacity: isLight ? 0.18 : 0.9, scale: 2).image
        }
        return image.map { ($0, EdgeInsets(top: cap, leading: cap, bottom: cap, trailing: cap), bleed) }
    }

    /// The smallest card the nine-slice shadow stretches to.
    static func shadowFits(_ size: CGSize, radius: CGFloat) -> Bool {
        let core = (max(radius, ArtBlurRenderer.shadowBleed(blur: 11)) + 1) * 2 + 2
        return size.width >= core && size.height >= core
    }

    /// The same shadow drawn whole under one card size, for a card smaller
    /// than the nine-slice's middle.
    static func shadow(size: CGSize, radius: CGFloat) -> (image: UIImage, bleed: CGFloat)? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let isLight = Theme.isLight
        let key = "shadow|\(Int(size.width * 4))x\(Int(size.height * 4))|\(radius)|\(isLight)"
        let image = plate(key) {
            ArtBlurRenderer.shadow(size: size, radius: radius, blur: 11, opacity: isLight ? 0.18 : 0.9, scale: 2).image
        }
        return image.map { ($0, ArtBlurRenderer.shadowBleed(blur: 11)) }
    }
}

extension View {
    /// `shelfPoster` for the Library grid's cards, with its edge strokes and
    /// shadow as pre-rendered plates (`ShelfPlates`): the same look, and no
    /// Core Graphics drawing as cards scroll in. `size` (when the grid knows
    /// it) spares each card a measuring pass. For fixed-size cards only: a
    /// size that animates would render a plate per frame.
    func shelfPosterPlated(radius: CGFloat, ring: Color? = nil, ringWidth: CGFloat = 0.5, size: CGSize? = nil) -> some View {
        modifier(ShelfPlated(radius: radius, ring: ring ?? Theme.txt.opacity(0.07), ringWidth: ringWidth, size: size))
    }
}

private struct ShelfPlated: ViewModifier {
    let radius: CGFloat
    let ring: Color
    let ringWidth: CGFloat
    let size: CGSize?
    @Environment(\.displayScale) private var scale

    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if let size {
                    edge(size)
                } else {
                    GeometryReader { edge($0.size) }
                }
            }
            .background {
                if let size {
                    shadow(size)
                } else {
                    GeometryReader { shadow($0.size).frame(width: $0.size.width, height: $0.size.height) }
                }
            }
    }

    @ViewBuilder
    private func edge(_ size: CGSize) -> some View {
        if let edge = ShelfPlates.edge(size: size, radius: radius, ring: ring, ringWidth: ringWidth, scale: scale) {
            Image(uiImage: edge).resizable()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Centred on the card, `bleed` out on every side, dropped 12.
    @ViewBuilder
    private func shadow(_ size: CGSize) -> some View {
        if ShelfPlates.shadowFits(size, radius: radius), let made = ShelfPlates.shadow(radius: radius) {
            Image(uiImage: made.image)
                .resizable(capInsets: made.insets, resizingMode: .stretch)
                .frame(width: size.width + made.bleed * 2, height: size.height + made.bleed * 2)
                .offset(y: 12)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else if let made = ShelfPlates.shadow(size: size, radius: radius) {
            Image(uiImage: made.image)
                .resizable()
                .frame(width: size.width + made.bleed * 2, height: size.height + made.bleed * 2)
                .offset(y: 12)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
