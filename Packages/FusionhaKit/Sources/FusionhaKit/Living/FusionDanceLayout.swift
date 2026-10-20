import Foundation

/// Where the fusion figures stand (web `fusion-dance.ts` geometry + poses).
extension FusionDance {
    // MARK: Geometry (box units)

    /// The glyph's centre: the centre line.
    public static let cx = 52.0
    /// Each figure tilts and squashes about its base.
    public static let piv = LivingPt(50, 93)
    /// Degrees, at contact.
    public static let leanDeg = 9.0
    /// Inner edges' distance from the centre line at pose A.
    static let gapA = 55.0
    /// HD and 4K copies: one common size.
    public static let kQ = 0.88
    /// Clapper and TV body share this height.
    public static let hObj = 74.0
    /// The clapper's box (`SHAPES.movie`): x0, y0, x1, y1.
    static let clapBox = (13.0, 27.0, 91.0, 94.0)
    public static let kMovie = hObj / (clapBox.3 - clapBox.1)
    public static let movPiv = LivingPt((clapBox.0 + clapBox.2) / 2, 93)
    static let clapBot = movPiv.y + (clapBox.3 - movPiv.y) * kMovie

    /// The TV painter's mark size (px) whose body (0.76 S + its 3.2 px stroke)
    /// is the clapper's height, for a mark of `s` px per box unit.
    public static func tvMarkPx(_ s: Double) -> Double { (hObj * s - 3.2) / 0.76 }
    /// Painter box origin (box units) inside the TV figure at scale `k`: centred,
    /// the frame's outer bottom edge level with the clapper's base.
    public static func tvBox(_ s: Double, _ k: Double) -> LivingPt {
        LivingPt(50 - 50 * k, clapBot - (93 * k + 1.6 / s))
    }

    static func scaleAbout(_ p: LivingPoly, _ pv: LivingPt, _ k: Double) -> LivingPoly {
        p.map { pv + ($0 - pv) * k }
    }

    /// Outlines (box units) of each figure's object, as drawn at full size.
    public static func clapperOutline() -> LivingPoly {
        let parts: [(Double, Double, Double, Double, Double)] = [(13, 27, 91, 38, 2), (13, 41, 91, 52, 2), (13, 55, 91, 94, 4)]
        return scaleAbout(parts.flatMap { LivingVector.roundRect($0.0, $0.1, $0.2, $0.3, $0.4) }, movPiv, kMovie)
    }

    public static func tvOutline(_ s: Double) -> LivingPoly {
        let sp = tvMarkPx(s)
        let k = sp / (100 * s)
        let o = tvBox(s, k)
        let hw = 1.6 / sp * 100
        return LivingVector.roundRect(1 - hw, 17 - hw, 99 + hw, 93 + hw, 10 + hw).map { o + $0 * k }
    }

    public static func qualityOutline() -> LivingPoly { scaleAbout(LivingVector.fShapes.flatMap { $0 }, piv, kQ) }

    public static func outlines(_ pair: FusionPair, _ s: Double) -> (left: LivingPoly, right: LivingPoly) {
        if pair == .media { return (clapperOutline(), tvOutline(s)) }
        let f = qualityOutline()
        return (f, f.map { LivingPt(100 - $0.x, $0.y) }) // the 4K copy is mirrored
    }

    static func maxX(_ p: LivingPoly) -> LivingPt { p.reduce(LivingPt(-1e9, 0)) { $1.x > $0.x ? $1 : $0 } }
    static func minX(_ p: LivingPoly) -> LivingPt { p.reduce(LivingPt(1e9, 0)) { $1.x < $0.x ? $1 : $0 } }
    public static func edges(_ p: LivingPoly) -> (min: Double, max: Double) { (minX(p).x, maxX(p).x) }

    // MARK: Layout

    /// Figure offsets (box units) at pose A and at contact, and the contact height.
    public struct Layout: Equatable, Sendable {
        public var dxLA, dxRA, dxLC, dxRC: Double
        public var yTouch: Double
    }

    /// At pose A the inner edges sit `gapA` from the centre line; at contact each
    /// figure, leaning `leanDeg` about its base, touches it.
    public static func layout(_ pair: FusionPair, _ s: Double) -> Layout {
        let (l, r) = outlines(pair, s)
        func lean(_ p: LivingPoly, _ deg: Double) -> LivingPoly {
            let m = LivingMat.about(piv, .rotate(deg))
            return p.map(m.apply)
        }
        let inL = maxX(lean(l, leanDeg))
        let dxLA = cx - gapA - maxX(l).x
        let dxLC = cx - inL.x
        if pair == .quality {
            // mirrored about the centre line: box centre 50 + dx ↔ 2·CX − (50 + dx)
            return Layout(dxLA: dxLA, dxRA: 2 * cx - 100 - dxLA, dxLC: dxLC, dxRC: 2 * cx - 100 - dxLC, yTouch: inL.y)
        }
        return Layout(dxLA: dxLA, dxRA: cx + gapA - minX(r).x, dxLC: dxLC, dxRC: cx - minX(lean(r, -leanDeg)).x,
                      yTouch: inL.y)
    }

    // MARK: Motion

    /// Travel toward the centre: 0 at pose A, 1 at contact.
    public static func travel(_ t: Double) -> Double {
        var k = 0.0
        let stepK = [0.2, 0.4, 0.58]
        for (i, (a, b)) in T.steps.enumerated() where t >= a {
            k = lerp(i > 0 ? stepK[i - 1] : 0, stepK[i], inOut(prog(t, a, b)))
        }
        if t >= T.swing.0 { k = lerp(0.58, 0.72, inOut(prog(t, T.swing.0, T.swing.1))) }
        if t >= T.dip.0 { k = lerp(0.72, 0.78, inOut(prog(t, T.dip.0, T.dip.1))) }
        if t >= T.lean.0 { k = lerp(0.78, 1, easeFn(prog(t, T.lean.0, T.lean.1))) }
        return k
    }

    /// The left figure's own motion (the right one mirrors it): lift (box units,
    /// + up), tilt (deg, + toward the partner) and squash.
    public static func motion(_ t: Double) -> (lift: Double, tilt: Double, sx: Double, sy: Double) {
        var lift = 0.0, tilt = 0.0, sx = 1.0, sy = 1.0
        for (i, (a, b)) in T.steps.enumerated() {
            let h = bell(t, a, b)
            lift += h * 7
            tilt += h * (i % 2 == 1 ? -4 : 5)
            let land = t > b - 0.06 ? bell(t, b - 0.06, b + 0.08) : 0
            sy -= land * 0.05
            sx += land * 0.03
        }
        // swing: tilt away and rise, then over the top toward the partner
        if t > T.swing.0 && t < T.swing.1 {
            let u = prog(t, T.swing.0, T.swing.1)
            lift += sin(Double.pi * u) * 16
            tilt += u < 0.62
                ? -22 * sin(Double.pi * min(1, u * 1.6))
                : 14 * sin(Double.pi * (u - 0.62) / 0.38)
        }
        // dip: crouch, a little squash
        let dp = bell(t, T.dip.0, T.dip.1 + 0.08)
        sy -= dp * 0.12
        sx += dp * 0.06
        lift -= dp * 2
        // lean in and hold through the touch, straighten while merging
        let ln = easeFn(prog(t, T.lean.0, T.lean.1)) * (1 - inOut(prog(t, T.back.0, T.back.1)))
        tilt += leanDeg * ln
        return (lift, tilt, sx, sy)
    }

    /// A figure's frame (box units → mark box units, before the object's own
    /// placement), the per-blade split lag, and its offset + lift for the shadow.
    public struct Pose: Sendable {
        public var m: LivingMat
        public var lag: [Double]?
        public var dx: Double
        public var lift: Double
    }

    /// A figure's frame at time `t`: offset, the split sway, then the dance tilt
    /// and squash about its base. Left and right are mirror images.
    public static func pose(_ t: Double, _ side: FusionSide, _ pair: FusionPair, _ geo: Layout) -> Pose {
        let isL = side == .left
        let (dxA, dxC) = isL ? (geo.dxLA, geo.dxLC) : (geo.dxRA, geo.dxRC)
        let sp = easeFn(prog(t, T.split.0, T.split.1))
        let mg = snapFn(prog(t, T.back.0, T.back.1 - 0.04))
        let dx = lerp(lerp(0, dxA, sp) + (dxC - dxA) * travel(t), 0, mg)
        let mo = motion(t)
        let dir: Double = isL ? 1 : -1
        let sway = 8 * sin(Double.pi * prog(t, T.split.0, 1.25)) * -dir
        let rotX: Double = pair == .media ? 52 : 50
        var m = LivingMat.translate(dx, -mo.lift)
        if sway != 0 { m = m.mul(.about(LivingPt(rotX, 51), .rotate(sway))) }
        m = m.mul(.about(piv, LivingMat.rotate(mo.tilt * dir).mul(.scale(mo.sx, mo.sy))))
        var lag: [Double]?
        if t > T.split.0 && t < 1.3 {
            lag = (0..<3).map { i in
                lerp(0, geo.dxLA, easeFn(prog(t - Double(i) * 0.05, T.split.0, T.split.1))) - lerp(0, geo.dxLA, sp)
            }
        }
        if !isL { lag = lag?.map { -$0 } }
        return Pose(m: m, lag: lag, dx: dx, lift: mo.lift)
    }
}
