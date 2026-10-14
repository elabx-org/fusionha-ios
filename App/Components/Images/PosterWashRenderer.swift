import SwiftUI
import UIKit
import CoreImage
import ObjectiveC

/// Monochrome's poster wash, applied to the decoded art (the posters are
/// drawn by UIKit, which SwiftUI's colour effects don't reach). Reads the
/// palette, so a view that calls it redraws when the palette or wash changes.
/// The washed copy is attached to the source image (so it lives and dies
/// with it); other palettes return the art as is.
enum PosterWashRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static var greyKey: UInt8 = 0
    private static var softKey: UInt8 = 0

    static func washed(_ image: UIImage) -> UIImage {
        guard Theme.isMono else { return image }
        let wash = PaletteStore.shared.posterWash
        guard wash != .colour else { return image }
        if let hit = attached(image, wash) { return hit }
        guard let input = CIImage(image: image) else { return image }
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(input, forKey: kCIInputImageKey)
        filter?.setValue(wash == .greyscale ? 0 : 0.35, forKey: kCIInputSaturationKey)
        filter?.setValue(wash == .greyscale ? 1.06 : 1.0, forKey: kCIInputContrastKey)
        filter?.setValue(wash == .greyscale ? 0 : -0.04, forKey: kCIInputBrightnessKey)
        guard let output = filter?.outputImage,
              let cg = context.createCGImage(output, from: input.extent) else { return image }
        let result = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
        attach(result, to: image, wash)
        return result
    }

    private static func attached(_ image: UIImage, _ wash: PosterWash) -> UIImage? {
        wash == .greyscale ? objc_getAssociatedObject(image, &greyKey) as? UIImage
                           : objc_getAssociatedObject(image, &softKey) as? UIImage
    }

    private static func attach(_ washed: UIImage, to image: UIImage, _ wash: PosterWash) {
        if wash == .greyscale {
            objc_setAssociatedObject(image, &greyKey, washed, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            objc_setAssociatedObject(image, &softKey, washed, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension View {
    /// Monochrome's poster wash for small SwiftUI art (the app logo, the
    /// avatar): the same Greyscale / Soft wash / Full colour choice, applied
    /// as a saturation change. Other palettes leave it as is.
    func monochromeWash() -> some View {
        let wash = Theme.isMono ? PaletteStore.shared.posterWash : .colour
        return saturation(wash == .greyscale ? 0 : wash == .soft ? 0.35 : 1)
            .contrast(wash == .greyscale ? 1.06 : 1)
    }
}
