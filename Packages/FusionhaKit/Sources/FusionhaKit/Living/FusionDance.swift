import Foundation

/// The two fusion moves' pairs: Movies × Series (clapper + TV) and HD × 4K.
public enum FusionPair: Sendable { case media, quality }
/// The left figure leads; the right one mirrors it.
public enum FusionSide: Sendable { case left, right }

/// The Living fusion moves' choreography maths (web `living/fusion-dance.ts`,
/// v0.4.224), pure. Everything is in the logo's 0–100 box. Two figures split out
/// of the F, step toward each other with mirrored hops, swing, dip and lean until
/// their inner edges meet on the centre line, then slide back into one F. Times
/// are seconds on the mock's timeline; a move plays `start`–`end`.
public enum FusionDance {
    // MARK: Easing

    public static func clamp(_ v: Double, _ a: Double = 0, _ b: Double = 1) -> Double { v < a ? a : v > b ? b : v }
    public static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    public static func prog(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
    public static func outC(_ x: Double) -> Double { 1 - pow(1 - clamp(x), 3) }
    static func bell(_ t: Double, _ a: Double, _ b: Double) -> Double { sin(Double.pi * prog(t, a, b)) }
    static func inOut(_ k: Double) -> Double { LivingVector.easeInOutCubic(k) }

    /// A CSS cubic-bezier evaluated at `x` (bisection on the x curve).
    public static func cubicBezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, _ x: Double) -> Double {
        func bez(_ a: Double, _ b: Double, _ t: Double) -> Double {
            3 * a * t * (1 - t) * (1 - t) + 3 * b * t * t * (1 - t) + t * t * t
        }
        let xc = clamp(x)
        var lo = 0.0, hi = 1.0
        for _ in 0..<22 {
            let m = (lo + hi) / 2
            if bez(x1, x2, m) < xc { lo = m } else { hi = m }
        }
        return bez(y1, y2, (lo + hi) / 2)
    }

    /// The Living EASE and SNAP curves as numbers.
    public static func easeFn(_ x: Double) -> Double { cubicBezier(0.22, 1, 0.36, 1, x) }
    public static func snapFn(_ x: Double) -> Double { cubicBezier(0.7, 0, 0.2, 1, x) }

    // MARK: Timeline (s)

    public enum T {
        public static let split = (0.36, 1.05)
        /// The clapper morph: 820 ms + 2 × 90 ms stagger.
        public static let morph = (0.5, 1.5)
        /// Stripes + board lines fade in (260 ms).
        public static let deco = (1.5, 1.76)
        public static let steps = [(1.5, 1.8), (1.8, 2.1), (2.1, 2.4)]
        public static let swing = (2.4, 2.86)
        public static let dip = (2.86, 3.1)
        public static let lean = (3.1, 3.4)
        public static let touch = 3.4
        /// Slide back into one F.
        public static let back = (3.55, 4.2)
    }

    /// The move starts just before the split and ends on the merged F.
    public static let start = 0.3
    public static let end = T.back.1

    /// The shipped clap: open 340 ms (to −24°), hold 260 ms, snap 70 ms.
    static let claps = [1.76, 2.73]
    /// 2.43 (mid-dance), and 3.40 = the touch.
    public static let clapHits = claps.map { $0 + 0.67 }

    public static func clapArm(_ t: Double) -> Double {
        for t0 in claps {
            let o = t0 + 0.34
            let h = o + 0.26
            if t >= t0 && t < o { return -24 * outC((t - t0) / 0.34) }
            if t >= o && t < h { return -24 }
            if t >= h && t < h + 0.07 { return -24 * (1 - (t - h) / 0.07) }
        }
        return 0
    }

    /// Brightness of the clapper (the shipped clap's flash), 1 = none.
    public static func clapFlash(_ t: Double) -> Double {
        clapHits.reduce(1) { f, h in f + (t >= h && t < h + 0.24 ? 0.5 * (1 - (t - h) / 0.24) : 0) }
    }

    /// The `tv` move's time (ms) for a timeline time (−1 = no TV): the frame grows
    /// in with the morph, the scan line runs during the side-steps, it holds, then
    /// fades out. Its CRT off/on (1700–2950 ms) is skipped.
    public static func tvTime(_ t: Double) -> Double {
        if t < T.morph.0 || t >= T.back.0 + 0.3 { return -1 }
        if t < 1.2 { return 700 * prog(t, T.morph.0, 1.2) }
        if t < 2.05 { return 700 + 850 * prog(t, 1.2, 2.05) }
        if t < T.back.0 { return 1600 }
        return 3050 + 450 * prog(t, T.back.0, T.back.0 + 0.3)
    }

    /// The `quality` move's time (ms): the copies step up their resolution through the dance.
    public static let qIn = (0.85, 1.1)
    public static let qOut = (3.45, 3.6)
    public static func qTime(_ t: Double) -> Double { 760 + (3350 - 760) * prog(t, qIn.0, qOut.0) }
    /// Raster copies' opacity (the vector F hands over to them and back).
    public static func qAlpha(_ t: Double) -> Double { prog(t, qIn.0, qIn.1) * (1 - prog(t, qOut.0, qOut.1)) }

    // MARK: Per-pair scales and morphs

    /// The clapper's scale about its base: grows to `kMovie` with the morph,
    /// back to 1 as it slides home.
    public static func movieScale(_ t: Double) -> Double {
        lerp(1, kMovie, inOut(prog(t, T.morph.0, T.morph.1)) * (1 - inOut(prog(t, T.back.0, T.back.0 + 0.55))))
    }

    /// The HD/4K figures' scale about their base (the common copy size).
    public static func qualityScale(_ t: Double) -> Double {
        lerp(1, kQ, prog(t, qIn.0 - 0.4, qIn.0) * (1 - prog(t, qOut.0, T.back.1)))
    }

    /// The right F's turn (x scale, −1 = mirrored): it turns to face its partner
    /// before the copies appear, and back once they have gone.
    public static func qualityFlip(_ t: Double) -> Double {
        t < T.back.0
            ? cos(Double.pi * inOut(prog(t, 0.45, 0.85)))
            : -cos(Double.pi * inOut(prog(t, 3.6, 3.95)))
    }

    /// The clapper's morph progress per blade: F → clapper, then clapper → F.
    public static func movieMorph(_ t: Double) -> (back: Bool, k: (Int) -> Double) {
        if t < T.back.0 {
            return (false, { i in inOut(clamp((t - T.morph.0 - Double(i) * 0.09) / 0.82)) })
        }
        return (true, { i in inOut(clamp((t - T.back.0 - Double(i) * 0.05) / 0.55)) })
    }

    /// The 2 px contact shake's progress (0 → 1 over 220 ms after the touch).
    public static func shake(_ t: Double) -> (dx: Double, dy: Double) {
        let p = prog(t, T.touch, T.touch + 0.22)
        let amp = p > 0 && p < 1 ? 2 * (1 - p) : 0
        return (sin(p * 62) * amp, cos(p * 47) * amp * 0.7)
    }

    /// The floor shadows' opacity scale over the dance.
    public static func onFloor(_ t: Double) -> Double { prog(t, 0.9, 1.4) * (1 - prog(t, T.back.0, T.back.0 + 0.3)) }

    /// The merge whirl's progress (0 → 1 over the slide home).
    public static func whirl(_ t: Double) -> Double { prog(t, T.back.0 + 0.05, T.back.1 + 0.03) }

    /// The stripes + board lines' opacity.
    public static func deco(_ t: Double) -> Double {
        prog(t, T.deco.0, T.deco.1) * (1 - prog(t, T.back.0 - 0.2, T.back.0))
    }
}
