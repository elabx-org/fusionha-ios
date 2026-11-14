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
/// not glass: the art itself stays clean on the focused title.
struct V2HologramPlate: View {
    let image: UIImage?
    var wash: Color = .clear
    var washOpacity: Double = 0
    var washBlend: BlendMode = .normal
    var edge: Color = .clear

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: V2HologramArt.cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            Theme.panel2
            if let image {
                Image(uiImage: image)
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
