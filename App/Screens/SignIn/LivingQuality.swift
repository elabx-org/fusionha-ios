import SwiftUI
import UIKit

/// The quality move's per-frame layout (moves.ts `quality`).
enum LivingQuality {
    struct Frame {
        var split: Double
        var offset: CGFloat
        var scaleL: CGFloat, scaleR: CGFloat
        var resL: Int, resR: Int
        var glowR: Double
        var fade: Double
        var fillL: Double, fillR: Double
        var flashL: Double, flashR: Double
    }

    static func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    static func frame(ms t: Double, size s: CGFloat, centre: CGPoint) -> Frame? {
        guard t >= 0, t <= 4300 else { return nil }
        let steps = [10, 16, 24, 36, 56, 0]
        let split = sstep(150, 750, t) * (1 - sstep(3500, 4100, t))
        let coarse = t > 250 && t < 3700
        var resL = 0, resR = 0
        if coarse {
            resL = t < 900 ? 10 : t < 1150 ? 16 : t < 1400 ? 24 : 40
            let k = Int(max(0, t - 900) / 170)
            resR = t < 900 ? 10 : steps[min(steps.count - 1, k)]
        }
        if t > 3550 { resL = 0 }
        let glowR = resR == 0 && t > 1700 && t < 3700 ? min(1, (t - 1700) / 300) * (1 - sstep(3400, 3700, t)) : 0
        let fade = t < 150 ? t / 150 : t > 4150 ? max(0, (4300 - t) / 150) : 1
        return Frame(split: split, offset: 0.64 * s * CGFloat(split), scaleL: 1 - 0.18 * CGFloat(split),
                     scaleR: 1 - 0.06 * CGFloat(split), resL: resL, resR: resR, glowR: glowR, fade: fade,
                     fillL: sstep(1100, 2500, t), fillR: sstep(1100, 3150, t),
                     flashL: t > 2500 && t < 2900 ? 1 - (t - 2500) / 400 : 0,
                     flashR: t > 3150 && t < 3550 ? 1 - (t - 3150) / 400 : 0)
    }

    /// The logo redrawn at `res`×`res` (nearest-neighbour when scaled back up).
    @MainActor static func pixelated(_ res: Int) -> UIImage? {
        if let hit = cache[res] { return hit }
        guard let logo = UIImage(named: "BrandLogo") else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: res, height: res), format: format).image { _ in
            logo.draw(in: CGRect(x: 0, y: 0, width: res, height: res))
        }
        cache[res] = image
        return image
    }

    @MainActor private static var cache: [Int: UIImage] = [:]
}
