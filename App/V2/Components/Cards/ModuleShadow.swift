import SwiftUI
import UIKit
import CoreImage

/// The W1 card's soft shadow (cards-w.js: 0 10 28 black .22 dark, 0 8 24
/// navy .08 light) as a pre-blurred nine-slice, like the shelf's: a
/// `.shadow` re-rendered each card offscreen every frame. The card's own
/// area is cut out of the bitmap, so the shadow never darkens the
/// translucent material above it (CSS box-shadow sits outside the box).
struct ModuleShadow: View {
    let radius: CGFloat
    let light: Bool

    var body: some View {
        let made = ModuleShadowCache.shared.shadow(radius: radius, light: light)
        let side = made.bleed + radius + 1
        Image(uiImage: made.image)
            .resizable(capInsets: EdgeInsets(top: side, leading: side, bottom: side + made.drop, trailing: side),
                       resizingMode: .stretch)
            .padding(EdgeInsets(top: -made.bleed, leading: -made.bleed, bottom: -(made.bleed + made.drop),
                                trailing: -made.bleed))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

@MainActor
final class ModuleShadowCache {
    static let shared = ModuleShadowCache()

    struct Made {
        let image: UIImage
        /// Shadow outside the card on each side, in points.
        let bleed: CGFloat
        /// How far the shadow drops below the card.
        let drop: CGFloat
    }

    private var made: [String: Made] = [:]
    private static let context = CIContext(options: [.cacheIntermediates: false])
    private static let space = CGColorSpace(name: CGColorSpace.sRGB)!

    func shadow(radius: CGFloat, light: Bool) -> Made {
        let key = "\(Int(radius * 10))|\(light)"
        if let hit = made[key] { return hit }
        let blur: CGFloat = light ? 12 : 14, drop: CGFloat = light ? 8 : 10
        let result = Self.render(radius: radius, blur: blur, drop: drop, opacity: light ? 0.09 : 0.22, scale: 2)
        made[key] = result
        return result
    }

    /// A card `2r + 4` points square with its shadow `drop` points lower,
    /// blurred, and the card itself cleared.
    private static func render(radius: CGFloat, blur: CGFloat, drop: CGFloat, opacity: Double, scale: CGFloat) -> Made {
        let bleed = ceil(blur * 3)
        let inner = radius * 2 + 4
        let width = inner + bleed * 2, height = inner + bleed * 2 + drop
        let pw = Int((width * scale).rounded()), ph = Int((height * scale).rounded())
        let empty = Made(image: UIImage(), bleed: 0, drop: 0)
        guard let plate = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return empty }
        // Core Graphics is bottom-left: the card's top is `bleed` below the image's top.
        let card = CGRect(x: bleed * scale, y: (height - bleed - inner) * scale, width: inner * scale, height: inner * scale)
        let r = radius * scale
        plate.addPath(CGPath(roundedRect: card.offsetBy(dx: 0, dy: -drop * scale), cornerWidth: r, cornerHeight: r, transform: nil))
        plate.setFillColor(UIColor.black.withAlphaComponent(opacity).cgColor)
        plate.fillPath()
        guard let drawn = plate.makeImage() else { return empty }
        let input = CIImage(cgImage: drawn)
        let blurred = input.applyingGaussianBlur(sigma: Double(blur * scale)).cropped(to: input.extent)
        guard let soft = context.createCGImage(blurred, from: input.extent),
              let cut = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return empty }
        cut.draw(soft, in: CGRect(x: 0, y: 0, width: pw, height: ph))
        cut.setBlendMode(.clear)
        cut.addPath(CGPath(roundedRect: card, cornerWidth: r, cornerHeight: r, transform: nil))
        cut.fillPath()
        guard let cutImage = cut.makeImage() else { return empty }
        return Made(image: UIImage(cgImage: cutImage, scale: scale, orientation: .up), bleed: bleed, drop: drop)
    }
}
