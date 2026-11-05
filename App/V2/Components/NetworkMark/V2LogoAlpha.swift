import UIKit

/// Whether a logo is cut out (transparent around the mark), so it can be
/// drawn as a one-ink silhouette. A logo without alpha, or with an opaque
/// corner (a logo on a solid tile), would turn into a filled block.
enum V2LogoAlpha {
    @MainActor private static var verdicts: [ObjectIdentifier: Bool] = [:]

    @MainActor
    static func isCutOut(_ image: UIImage) -> Bool {
        let key = ObjectIdentifier(image)
        if let known = verdicts[key] { return known }
        let verdict = compute(image)
        verdicts[key] = verdict
        return verdict
    }

    private static func compute(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        switch cg.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        // The top-left pixel, drawn into a 1x1 alpha-only context.
        var alpha: UInt8 = 0
        guard let ctx = CGContext(data: &alpha, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return true }
        ctx.draw(cg, in: CGRect(x: 0, y: 1 - CGFloat(cg.height), width: CGFloat(cg.width), height: CGFloat(cg.height)))
        return alpha < 200
    }
}
