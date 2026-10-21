import FusionhaKit
import SwiftUI

/// One frame of a fusion move (web `living/fusion-moves.ts` `paintFrame`): the
/// two figures on their floor shadows, posed by `FusionDance`, shaken on contact,
/// then the contact spark and the merge whirl. Drawn on the fx canvas while the
/// mark is hidden; the last frame is the F at rest, exactly where the mark is.
/// The figures reuse the moves' own painters: `LivingBladeArt` (the F and the
/// clapper), `LivingTVArt` (the `tv` move's TV) and `LivingQualityArt` (the
/// `quality` move's copies and meters).
@MainActor
enum LivingFusionFrame {
    typealias D = FusionDance

    static func paint(_ show: LivingFusionShow, in ctx: GraphicsContext, t: Double, mark: CGRect) {
        let s = Double(mark.width) / 100
        let pl = D.pose(t, .left, show.pair, show.geo)
        let pr = D.pose(t, .right, show.pair, show.geo)
        let shake = D.shake(t)
        var box = ctx
        box.translateBy(x: mark.minX + shake.dx, y: mark.minY + shake.dy)
        box.scaleBy(x: s, y: s)
        let onFloor = D.onFloor(t)
        for p in [pl, pr] {
            LivingFusionPaint.floor(box, x: p.dx + 50, y: 93 + 1 / s, alpha: onFloor * (0.9 - min(0.5, p.lift / 30)))
        }
        switch show.pair {
        case .media: paintMedia(box, t: t, s: s, pl, pr)
        case .quality: paintQuality(box, t: t, s: s, pl, pr)
        }
        LivingFusionPaint.contact(ctx, at: CGPoint(x: mark.minX + D.cx * s, y: mark.minY + show.geo.yTouch * s),
                                  since: t - D.T.touch, k: s)
        LivingFusionPaint.whirl(ctx, centre: CGPoint(x: mark.minX + 52 * s, y: mark.minY + 51 * s), size: 100 * s,
                                wp: D.whirl(t))
    }

    /// Applies a `FusionDance` frame on top of the context's transform.
    static func concat(_ ctx: inout GraphicsContext, _ m: LivingMat) {
        ctx.concatenate(CGAffineTransform(a: m.a, b: m.b, c: m.c, d: m.d, tx: m.e, ty: m.f))
    }

    /// The clapper (left) and the TV with the F inside (right).
    private static func paintMedia(_ ctx: GraphicsContext, t: Double, s: Double, _ pl: D.Pose, _ pr: D.Pose) {
        let mm = D.movieMorph(t)
        let shapes = mm.back
            ? LivingVector.lerpSets(LivingVector.movieShapes, LivingVector.movieBack, mm.k)
            : LivingVector.lerpSets(LivingVector.fShapes, LivingVector.movieShapes, mm.k)
        var left = ctx
        concat(&left, pl.m.mul(.about(D.movPiv, .scale(D.movieScale(t)))))
        LivingBladeArt.paint(left, shapes, .init(lag: pl.lag, arm: D.clapArm(t), deco: D.deco(t), flash: D.clapFlash(t)))
        guard t >= D.T.split.0 else { return }
        let markPx = D.tvMarkPx(s)
        let kTv = markPx / (100 * s)
        let tvT = D.tvTime(t)
        let tp = tvT >= 0 ? LivingTVArt.pose(tvT) : LivingTVArt.Pose(a: 0, ty: 0, kx: 1, ky: 1, br: 1)
        var right = ctx
        concat(&right, pr.m)
        if tvT >= 0 {
            var tv = right
            let o = D.tvBox(s, kTv)
            tv.translateBy(x: o.x, y: o.y)
            tv.scaleBy(x: 1 / s, y: 1 / s) // the TV painter works in points
            LivingTVArt.paint(&tv, tvT, s: markPx, origin: .zero)
        }
        let kv = D.lerp(1, kTv, tp.a)
        let inner = LivingMat.translate(D.tvBox(s, kv).x, tp.a * D.tvBox(s, kTv).y)
            .mul(LivingMat.scale(kv)
                .mul(.about(LivingPt(50, 50), LivingMat.translate(0, tp.ty * 100).mul(.scale(tp.kx, tp.ky)))))
        concat(&right, inner)
        LivingBladeArt.paint(right, LivingVector.fShapes, .init(lag: pr.lag))
    }

    /// The HD and 4K figures: the vector F hands over to the quality copies.
    private static func paintQuality(_ ctx: GraphicsContext, t: Double, s: Double, _ pl: D.Pose, _ pr: D.Pose) {
        let qa = D.qAlpha(t)
        let vk = D.qualityScale(t)
        if qa < 1 {
            var sides: [(LivingMat, Double, [Double]?)] = [(pl.m, 1, pl.lag)]
            if t >= D.T.split.0 { sides.append((pr.m, D.qualityFlip(t), pr.lag)) }
            for (m, flip, lag) in sides {
                var figure = ctx
                concat(&figure, m.mul(.about(D.piv, .scale(flip * vk, vk))))
                LivingBladeArt.paint(figure, LivingVector.fShapes, .init(lag: lag, alpha: 1 - qa))
            }
        }
        guard qa > 0, let q = LivingQuality.frame(ms: D.qTime(t), size: 0, centre: .zero) else { return }
        let copies: [(LivingMat, CGFloat, Int, Double, Double, Double)] = [
            (pl.m, 1, q.resL, 0, q.fillL, q.flashL),
            (pr.m, -1, q.resR, q.glowR, q.fillR, q.flashR),
        ]
        let size = D.kQ * 100
        for (m, flip, res, glow, fill, flash) in copies {
            var copy = ctx
            concat(&copy, m)
            copy.translateBy(x: 50, y: 93 - 43 * D.kQ)
            copy.scaleBy(x: flip, y: 1) // the 4K copy is mirrored
            LivingQualityArt.drawPix(copy, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size), res: res,
                                     alpha: qa, glow: glow)
            LivingQualityArt.drawBar(copy, cx: 0, y: 50 * D.kQ + 16 / s, w: 62 * D.kQ, fill: fill, flash: flash,
                                     px: 1 / s, alpha: qa)
        }
    }
}
