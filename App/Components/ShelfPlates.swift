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

    /// The shelf's deep shadow under one card size (as `ShelfShadow`'s
    /// nine-slice, drawn whole so it is a plain image).
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
    /// Core Graphics drawing as cards scroll in. For fixed-size cards only:
    /// a size that animates would render a plate per frame.
    func shelfPosterPlated(radius: CGFloat, ring: Color? = nil, ringWidth: CGFloat = 0.5) -> some View {
        modifier(ShelfPlated(radius: radius, ring: ring ?? Theme.txt.opacity(0.07), ringWidth: ringWidth))
    }
}

private struct ShelfPlated: ViewModifier {
    let radius: CGFloat
    let ring: Color
    let ringWidth: CGFloat
    @Environment(\.displayScale) private var scale

    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                GeometryReader { proxy in
                    if let edge = ShelfPlates.edge(size: proxy.size, radius: radius, ring: ring,
                                                   ringWidth: ringWidth, scale: scale) {
                        Image(uiImage: edge).resizable()
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .background {
                GeometryReader { proxy in
                    if let made = ShelfPlates.shadow(size: proxy.size, radius: radius) {
                        Image(uiImage: made.image)
                            .resizable()
                            .frame(width: proxy.size.width + made.bleed * 2, height: proxy.size.height + made.bleed * 2)
                            .offset(x: -made.bleed, y: -made.bleed + 12)
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}
