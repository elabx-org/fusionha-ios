import SwiftUI

/// The `quality` move's drawing (web `living/quality-art.ts`): the logo copy at
/// a coarse resolution (soft HD, stepping up to crisp 4K) and its progress
/// meter. Shared by the `quality` move and the HD × 4K fusion move; the
/// timeline is `LivingQuality.frame`.
@MainActor
enum LivingQualityArt {
    /// The logo in `rect`, rendered at `res`² px (0 = full) and scaled up
    /// unsmoothed so it reads as pixels.
    static func drawPix(_ ctx: GraphicsContext, in rect: CGRect, res: Int, alpha: Double, glow: Double) {
        let image: Image
        if res > 0, let px = LivingQuality.pixelated(res) {
            image = Image(uiImage: px).interpolation(.none)
        } else {
            image = Image("BrandLogo")
        }
        var plain = ctx
        plain.blendMode = .normal
        plain.drawLayer { layer in
            layer.opacity = alpha
            if glow > 0 { layer.addFilter(.shadow(color: Color(hex: 0xA5F3FC).opacity(0.55 * glow), radius: CGFloat(11 * glow))) }
            layer.draw(image.resizable(), in: rect)
        }
    }

    /// A progress meter `w` wide centred on `cx`, top at `y`; `px` is one point in
    /// the current units (the meter stays 4pt tall under a scale).
    static func drawBar(_ ctx: GraphicsContext, cx: CGFloat, y: CGFloat, w: CGFloat, fill: Double, flash: Double,
                        px: CGFloat = 1, alpha: Double = 1) {
        let h = 4 * px, r = 2 * px
        var plain = ctx
        plain.blendMode = .normal
        plain.drawLayer { layer in
            layer.opacity = alpha
            let track = Path(roundedRect: CGRect(x: cx - w / 2, y: y, width: w, height: h), cornerRadius: r)
            layer.fill(track, with: .color(.white.opacity(0.08)))
            if fill > 0 {
                let bar = Path(roundedRect: CGRect(x: cx - w / 2, y: y, width: max(h, w * CGFloat(fill)), height: h), cornerRadius: r)
                layer.fill(bar, with: .linearGradient(LivingTVArt.brand, startPoint: CGPoint(x: cx - w / 2, y: 0),
                                                      endPoint: CGPoint(x: cx + w / 2, y: 0)))
            }
            if flash > 0 {
                layer.addFilter(.shadow(color: .white, radius: 6))
                layer.fill(track, with: .color(.white.opacity(flash)))
            }
        }
    }
}
