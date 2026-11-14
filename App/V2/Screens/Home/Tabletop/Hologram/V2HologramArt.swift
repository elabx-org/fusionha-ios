import SwiftUI
import UIKit
import FusionhaKit

/// A title's poster for the hologram scene: the art itself and a soft copy
/// for its reflection on the floor. The soft copy is the poster drawn once
/// into a few dozen pixels and stretched back, so nothing is blurred live.
struct V2HologramArt {
    let poster: UIImage
    let soft: UIImage

    /// The poster plate every piece is drawn from, before projection.
    static let box = CGSize(width: CGFloat(TabletopScene.posterWidth), height: CGFloat(TabletopScene.posterHeight))
    static let cornerRadius: CGFloat = 18

    /// The same poster the flat carousel shows (`V2ComingUpWideCard`), so it
    /// is usually already decoded.
    static func url(_ item: MediaItem) -> URL? {
        TMDBImage.resized(item.posterUrl ?? item.backdropUrl, to: "w500")
    }

    @MainActor
    static func load(_ item: MediaItem, scale: CGFloat) async -> V2HologramArt? {
        guard let url = url(item) else { return nil }
        let request = ArtRequest(url: url, points: box, scale: scale)
        guard let poster = await ImagePipeline.shared.image(for: url, fill: request.pixels, scale: scale) else { return nil }
        return V2HologramArt(poster: poster, soft: soften(poster))
    }

    private static func soften(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: 24, height: 36)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// One poster plate of the scene, at the plate's own size (the scene's
/// transform places it): the art with an optional colour laid over it (the
/// waiting titles' light, the slab's glass slices) and a lit edge. Content,
/// not glass: the art itself stays clean on the focused title. The print-in
/// shows it from its foot up (`reveal`); the lift carries the carousel
/// card's corner radius and shadow over (`radius`, `shadow`).
struct V2HologramPlate: View {
    let image: UIImage?
    var wash: Color = .clear
    var washOpacity: Double = 0
    var washBlend: BlendMode = .normal
    var edge: Color = .clear
    /// How much shows, from the foot up.
    var reveal: Double = 1
    var radius: CGFloat = V2HologramArt.cornerRadius
    /// The carousel card's shadow (0 none, 1 whole) and its size on this plate.
    var shadow: Double = 0
    var shadowScale: CGFloat = 1

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    var body: some View {
        if reveal < 1 {
            lit.mask(alignment: .bottom) {
                Rectangle().frame(height: V2HologramArt.box.height * max(0, reveal))
            }
            .transition(.identity)
        } else if shadow > 0 {
            // `V2ComingUpWideCard`'s shadow, at the plate's size.
            lit.shadow(color: .black.opacity(0.35 * shadow), radius: 14 * shadowScale, y: 12 * shadowScale)
                .transition(.identity)
        } else {
            lit.transition(.identity)
        }
    }

    private var lit: some View {
        ZStack {
            Theme.panel2
            if let image {
                // Washed on Monochrome, as the carousel's posters are.
                Image(uiImage: PosterWashRenderer.washed(image))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: V2HologramArt.box.width, height: V2HologramArt.box.height)
            }
            wash.opacity(washOpacity).blendMode(washBlend)
        }
        .frame(width: V2HologramArt.box.width, height: V2HologramArt.box.height)
        .compositingGroup()
        .clipShape(shape)
        .overlay(shape.strokeBorder(edge, lineWidth: 1.5))
    }
}
