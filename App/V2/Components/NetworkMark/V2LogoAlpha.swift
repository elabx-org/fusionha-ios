import UIKit

/// Turns a TMDB network/studio logo (a PNG on transparent) into a one-ink
/// mask for the mock's mono mark: white where the logo is, clear elsewhere.
/// - Most logos: the logo's own alpha (plain silhouette).
/// - Two-tone logos whose letters sit inside a filled shape (ABC's dark
///   disc, Warner Bros.' shield): the light parts stay, the dark fill is
///   knocked out, so the mark doesn't become a solid blob.
/// - A logo with almost no transparency (a logo on a solid tile): nil, no
///   mark, rather than a white block.
/// Checked against real logos from the library (2026-11-05).
enum V2LogoAlpha {
    /// Keyed by the logo's URL; a nil entry remembers "no clean mark".
    @MainActor private static var masks: [URL: UIImage?] = [:]

    @MainActor
    static func mask(for image: UIImage, url: URL) -> UIImage? {
        if let known = masks[url] { return known }
        let made = make(image)
        masks.updateValue(made, forKey: url)
        return made
    }

    private static func make(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 0, h > 0, w * h <= 1_000_000 else { return nil }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let drew: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)
            else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drew else { return nil }

        let count = w * h
        var clear = 0, opaque = 0, dark = 0, light = 0
        var lum = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let a = px[i * 4 + 3]
            if a < 20 { clear += 1 }
            guard a > 0 else { continue }
            // Un-premultiply for the colour's own lightness.
            let s = 255 / Float(a)
            let l = (0.2126 * Float(px[i * 4]) + 0.7152 * Float(px[i * 4 + 1]) + 0.0722 * Float(px[i * 4 + 2])) * s / 255
            lum[i] = l
            if a > 200 {
                opaque += 1
                if l < 0.25 { dark += 1 } else if l > 0.6 { light += 1 }
            }
        }
        // A logo on a solid tile: no clean silhouette to draw.
        guard Float(clear) / Float(count) >= 0.1, opaque > 0 else { return nil }
        let twoTone = Float(dark) / Float(opaque) > 0.15 && Float(light) / Float(opaque) > 0.1

        var out = [UInt8](repeating: 0, count: count * 4)
        for i in 0..<count {
            var a = Float(px[i * 4 + 3]) / 255
            if twoTone { a *= max(0, min(1, (lum[i] - 0.25) / 0.45)) }
            let v = UInt8((a * 255).rounded())
            // Premultiplied white.
            out[i * 4] = v; out[i * 4 + 1] = v; out[i * 4 + 2] = v; out[i * 4 + 3] = v
        }
        let made: CGImage? = out.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info)?.makeImage()
        }
        return made.map { UIImage(cgImage: $0, scale: image.scale, orientation: .up) }
    }
}
