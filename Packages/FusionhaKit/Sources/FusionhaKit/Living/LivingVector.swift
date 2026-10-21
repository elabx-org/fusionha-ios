import Foundation

/// A point in the Living logo's 0–100 box ("box units").
public typealias LivingPt = SIMD2<Double>
/// A closed outline.
public typealias LivingPoly = [LivingPt]

/// The Living logo's vector F (web `living/vector-morph.ts`): the three blades
/// traced into polygons, resampled to the same point count, plus the morph
/// helpers (align, lerp) the fusion moves use for the clapper.
public enum LivingVector {
    /// Points per resampled outline.
    public static let np = 140

    /// The F's blades, resampled: the home shape every morph returns to.
    public static let fShapes: [LivingPoly] = fPoly.map(resample)

    /// The clapper (web `SHAPES.movie`): arm, striped stick and board, sampled
    /// and aligned to the F's blades so the morph doesn't twist.
    public static let movieShapes: [LivingPoly] = [
        roundRect(13, 27, 91, 38, 2), roundRect(13, 41, 91, 52, 2), roundRect(13, 55, 91, 94, 4),
    ].enumerated().map { i, part in align(fShapes[i], resample(part)) }
    /// The F's blades aligned to the clapper, for the morph home.
    public static let movieBack: [LivingPoly] = fShapes.enumerated().map { i, p in align(movieShapes[i], p) }

    /// Signed area (shoelace): its sign is the outline's winding.
    public static func area(_ p: LivingPoly) -> Double {
        var a = 0.0
        for i in p.indices {
            let q = p[(i + 1) % p.count]
            a += p[i].x * q.y - q.x * p[i].y
        }
        return a / 2
    }

    /// Resample a closed polygon to `np` points evenly spaced by arc length.
    public static func resample(_ p: LivingPoly) -> LivingPoly {
        let n = p.count
        var seg: [Double] = []
        var total = 0.0
        for i in 0..<n {
            let a = p[i], b = p[(i + 1) % n]
            let l = hypot(b.x - a.x, b.y - a.y)
            seg.append(l)
            total += l
        }
        var out: LivingPoly = []
        var i = 0
        var acc = 0.0
        for k in 0..<np {
            let d = Double(k) / Double(np) * total
            while acc + seg[i] < d && i < n - 1 {
                acc += seg[i]
                i += 1
            }
            let f = (d - acc) / (seg[i] == 0 ? 1 : seg[i])
            let a = p[i], b = p[(i + 1) % n]
            out.append(a + (b - a) * f)
        }
        return out
    }

    /// Re-order `dst` to match `src`: same winding, then the cyclic shift with
    /// the least summed squared distance.
    public static func align(_ src: LivingPoly, _ dst: LivingPoly) -> LivingPoly {
        var d0 = dst
        if (area(src) > 0) != (area(d0) > 0) { d0.reverse() }
        var best = 0
        var bestD = Double.infinity
        for k in stride(from: 0, to: np, by: 2) {
            var d = 0.0
            for j in stride(from: 0, to: np, by: 4) {
                let delta = src[j] - d0[(j + k) % np]
                d += delta.x * delta.x + delta.y * delta.y
            }
            if d < bestD {
                bestD = d
                best = k
            }
        }
        return d0.indices.map { d0[($0 + best) % np] }
    }

    /// Point-wise lerp of every outline in `from` toward `to`, per-blade staggered.
    public static func lerpSets(_ from: [LivingPoly], _ to: [LivingPoly], _ e: (Int) -> Double) -> [LivingPoly] {
        from.enumerated().map { i, p in
            let k = e(i)
            return p.enumerated().map { j, q in q + (to[i][j] - q) * k }
        }
    }

    public static func easeInOutCubic(_ k: Double) -> Double {
        k < 0.5 ? 4 * k * k * k : 1 - pow(-2 * k + 2, 3) / 2
    }

    /// A rounded rectangle as a polygon (9 points per corner), clockwise on screen.
    public static func roundRect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ r: Double) -> LivingPoly {
        let corners: [(Double, Double, Double)] = [
            (x1 - r, y0 + r, -Double.pi / 2), (x1 - r, y1 - r, 0),
            (x0 + r, y1 - r, Double.pi / 2), (x0 + r, y0 + r, Double.pi),
        ]
        var out: LivingPoly = []
        for (cx, cy, a0) in corners {
            for j in 0...8 {
                let a = a0 + Double(j) / 8 * (Double.pi / 2)
                out.append(LivingPt(cx + cos(a) * r, cy + sin(a) * r))
            }
        }
        return out
    }

    private static func P(_ x: Double, _ y: Double) -> LivingPt { LivingPt(x, y) }

    /// The traced F: top, middle and bottom blade.
    static let fPoly: [LivingPoly] = [
        [
            P(47.08, 9.05), P(92.36, 9.05), P(92.36, 12.95), P(91.25, 16.57), P(89.31, 20.19), P(85.69, 24.09),
            P(83.47, 25.77), P(78.75, 28.27), P(77.36, 28.55), P(75.97, 29.39), P(75.14, 29.39), P(72.92, 30.5),
            P(68.47, 31.89), P(67.64, 32.45), P(66.81, 32.45), P(65.97, 33.01), P(62.92, 33.84), P(61.25, 34.68),
            P(59.03, 35.52), P(15.42, 35.52), P(17.08, 29.67), P(19.31, 25.21), P(21.25, 22.42), P(24.31, 19.08),
            P(26.53, 17.13), P(30.97, 14.07), P(35.97, 11.56), P(42.36, 9.61), P(46.81, 9.33),
        ],
        [
            P(15.69, 35.24), P(59.86, 35.24), P(58.75, 35.52), P(58.47, 35.79), P(58.75, 36.07), P(79.58, 36.07),
            P(79.31, 39.14), P(77.36, 43.31), P(75.97, 45.26), P(73.19, 48.33), P(70.69, 50.28), P(67.08, 52.51),
            P(55.14, 58.36), P(54.58, 58.36), P(48.19, 61.42), P(47.64, 61.42), P(46.53, 62.26), P(43.47, 63.65),
            P(40.42, 65.88), P(12.64, 65.88), P(12.92, 65.04), P(12.92, 59.19), P(13.19, 58.91), P(13.19, 53.9),
            P(13.47, 53.62), P(13.75, 45.54), P(14.03, 45.26), P(14.03, 43.59), P(14.31, 43.31), P(14.31, 41.64),
            P(14.58, 41.36), P(14.58, 39.42), P(14.86, 39.14), P(15.42, 35.52),
        ],
        [
            P(12.64, 65.6), P(40.69, 65.6), P(39.86, 66.16), P(39.86, 71.17), P(39.58, 71.45), P(39.58, 72.84),
            P(39.31, 73.12), P(39.03, 75.07), P(38.47, 75.91), P(38.19, 77.3), P(35.42, 82.03), P(32.92, 84.82),
            P(29.58, 87.88), P(27.08, 89.55), P(23.19, 91.5), P(18.47, 92.9), P(17.08, 92.9), P(16.81, 93.18),
            P(13.19, 93.18), P(12.64, 92.9),
        ],
    ]
}
