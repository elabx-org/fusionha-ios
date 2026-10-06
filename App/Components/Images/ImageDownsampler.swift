import ImageIO
import UIKit

/// Decodes artwork at the pixel size it is drawn at, never larger than the
/// source. ImageIO's thumbnail path decodes straight to the target size, so a
/// big TMDB size costs bandwidth once but only its on-screen pixels in memory.
enum ImageDownsampler {
    /// A decoded image, and whether it is the source's full resolution (so it
    /// covers any frame, however large).
    struct Decoded {
        let image: UIImage
        let isFull: Bool
    }

    /// Decodes `data` so it aspect-fills `fill` (in pixels) with no upscaling.
    /// With no `fill` (`.zero`) the long side is capped at `fallbackMax` pixels.
    /// The result is tagged with `scale`, so its point size is right on screen.
    static func decode(_ data: Data, fill: CGSize, fallbackMax: CGFloat, scale: CGFloat) -> Decoded? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let size = pixelSize(of: source)
        let sourceLong = max(size.width, size.height)
        let maxPixel = targetLongSide(size: size, fill: fill, fallbackMax: fallbackMax)
        let thumb = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumb) else { return nil }
        let image = UIImage(cgImage: cg, scale: max(scale, 1), orientation: .up)
        return Decoded(image: image, isFull: sourceLong > 0 && CGFloat(max(cg.width, cg.height)) >= sourceLong)
    }

    /// The scale an image of `pixels` needs to aspect-fill `fill` (≤ 1 means it covers).
    static func fillFactor(pixels: CGSize, fill: CGSize) -> CGFloat {
        guard pixels.width > 0, pixels.height > 0 else { return .infinity }
        return max(fill.width / pixels.width, fill.height / pixels.height)
    }

    private static func targetLongSide(size: CGSize, fill: CGSize, fallbackMax: CGFloat) -> CGFloat {
        let sourceLong = max(size.width, size.height)
        guard fill.width > 0, fill.height > 0, size.width > 0 else {
            return sourceLong > 0 ? min(fallbackMax, sourceLong) : fallbackMax
        }
        let factor = fillFactor(pixels: size, fill: fill)
        return factor >= 1 ? sourceLong : (sourceLong * factor).rounded(.up)
    }

    private static func pixelSize(of source: CGImageSource) -> CGSize {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return .zero }
        let w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        // EXIF orientations 5–8 swap the axes once the transform is applied.
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return orientation >= 5 ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }
}
