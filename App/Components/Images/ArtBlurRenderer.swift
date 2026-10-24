import SwiftUI
import UIKit
import CoreImage
import FusionhaKit

/// Renders an `ArtBlurSpec` once: the art aspect-filled into a small bitmap,
/// clipped, colour-adjusted, blurred and faded in Core Image, off the main
/// thread. The result is drawn as a plain image, so scrolling a grid of
/// glowing posters composites bitmaps instead of running a live blur,
/// saturation and opacity pass per card.
enum ArtBlurRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static let space = CGColorSpace(name: CGColorSpace.sRGB)!

    static func render(_ source: CGImage, spec: ArtBlurSpec) -> CGImage? {
        guard let drawn = draw(source, spec: spec) else { return nil }
        var image = CIImage(cgImage: drawn)
        let extent = image.extent
        if spec.clampsEdges { image = image.clampedToExtent() }
        image = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: spec.saturation,
            kCIInputBrightnessKey: spec.brightness,
            kCIInputContrastKey: 1,
        ])
        image = image.applyingGaussianBlur(sigma: spec.blur)
        if spec.alpha < 1 {
            image = image.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: spec.alpha),
            ])
        }
        return context.createCGImage(image.cropped(to: extent), from: extent)
    }

    /// The art aspect-filled into `spec.art`, clipped to its corner radius,
    /// on a transparent canvas.
    private static func draw(_ source: CGImage, spec: ArtBlurSpec) -> CGImage? {
        let width = Int(spec.canvasWidth), height = Int(spec.canvasHeight)
        guard width > 0, height > 0,
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Core Graphics is bottom-left: flip the spec's top-left rect.
        let rect = CGRect(x: spec.art.x, y: Double(height) - spec.art.y - spec.art.height,
                          width: spec.art.width, height: spec.art.height)
        if spec.cornerRadius > 0 {
            let r = min(spec.cornerRadius, rect.width / 2, rect.height / 2)
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
            ctx.clip()
        } else {
            ctx.clip(to: rect)
        }
        ctx.interpolationQuality = .medium
        let sw = Double(source.width), sh = Double(source.height)
        let fill = max(rect.width / sw, rect.height / sh)
        let fw = sw * fill, fh = sh * fill
        ctx.draw(source, in: CGRect(x: rect.midX - fw / 2, y: rect.midY - fh / 2, width: fw, height: fh))
        return ctx.makeImage()
    }

    /// A soft drop shadow for a rounded card, as a nine-slice image: the
    /// corners and blurred edges stay fixed and the middle stretches, so one
    /// bitmap serves every card size. `bleed` points of shadow lie outside
    /// the card on each side.
    static func shadow(radius: CGFloat, blur: CGFloat, opacity: Double, scale: CGFloat) -> (image: UIImage, bleed: CGFloat) {
        let bleed = ceil(blur * 3)
        let inner = radius * 2 + 4
        let side = bleed * 2 + inner
        let px = Int(side * scale)
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (UIImage(), 0) }
        let card = CGRect(x: bleed * scale, y: bleed * scale, width: inner * scale, height: inner * scale)
        ctx.addPath(CGPath(roundedRect: card, cornerWidth: radius * scale, cornerHeight: radius * scale, transform: nil))
        ctx.setFillColor(UIColor.black.withAlphaComponent(opacity).cgColor)
        ctx.fillPath()
        guard let plate = ctx.makeImage() else { return (UIImage(), 0) }
        let input = CIImage(cgImage: plate)
        let blurred = input.applyingGaussianBlur(sigma: Double(blur * scale)).cropped(to: input.extent)
        guard let cg = context.createCGImage(blurred, from: input.extent) else { return (UIImage(), 0) }
        return (UIImage(cgImage: cg, scale: scale, orientation: .up), bleed)
    }
}

/// Rendered blurred art, cached per URL and spec (`ArtBlurSpec.key`).
@MainActor
final class ArtBlurCache {
    static let shared = ArtBlurCache()

    private let memory = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private var shadows: [String: (image: UIImage, bleed: CGFloat)] = [:]

    private init() {
        memory.totalCostLimit = 24 << 20
    }

    func removeAll() {
        memory.removeAllObjects()
    }

    func cached(_ key: String) -> UIImage? {
        memory.object(forKey: key as NSString)
    }

    /// The rendered bitmap for `url`: the source decoded small through the
    /// image pipeline, then blurred on a background thread.
    func image(for url: URL, spec: ArtBlurSpec) async -> UIImage? {
        let key = spec.key(for: url.absoluteString)
        if let hit = cached(key) { return hit }
        if let running = inflight[key] { return await running.value }
        let task = Task<UIImage?, Never> {
            let fill = CGSize(width: spec.sourceWidth, height: spec.sourceHeight)
            guard let source = await ImagePipeline.shared.image(for: url, fill: fill, scale: 1)?.cgImage else { return nil }
            let rendered = await Task.detached(priority: .utility) { ArtBlurRenderer.render(source, spec: spec) }.value
            return rendered.map { UIImage(cgImage: $0) }
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        if let result, let cg = result.cgImage {
            memory.setObject(result, forKey: key as NSString, cost: cg.width * cg.height * 4)
        }
        return result
    }

    /// The shelf shadow nine-slice for a corner radius and palette (tiny,
    /// rendered once each).
    func shadow(radius: CGFloat, isLight: Bool) -> (image: UIImage, bleed: CGFloat) {
        let key = "\(Int(radius * 10))|\(isLight)"
        if let hit = shadows[key] { return hit }
        let made = ArtBlurRenderer.shadow(radius: radius, blur: 11, opacity: isLight ? 0.18 : 0.9, scale: 2)
        shadows[key] = made
        return made
    }
}
