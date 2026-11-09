import Foundation

/// The book-pose fold drawn as two seas meeting (owner 2026-11-09, option 2
/// of the hinge mock): each page's ground runs into the fold, and they meet
/// along a line that meanders down it, with soft eddies curling across the
/// line, long currents along each side, a faint pale seam where they touch
/// and a light shadow down the hinge. This works out the masks; the app
/// lays the two grounds under them.
public enum FoldSeas {
    /// A strip's masks, row-major, `width × height`, one byte per value.
    public struct Field: Sendable, Equatable {
        public let width: Int
        public let height: Int
        /// How much of the trailing page's sea shows (0 leading, 255 trailing).
        public let sea: [UInt8]
        /// Shading over both seas, premultiplied grey + alpha per pixel
        /// (RGBA, 4 bytes): the deepening, the grain, the seam, the hinge.
        public let shade: [UInt8]
    }

    /// Where the seas meet across the strip (0…1, 0.5 the middle): a
    /// brighter sea reaches a little further into the darker one.
    public static func meeting(leading: Double, trailing: Double) -> Double {
        0.5 - min(0.3, max(-0.3, (trailing - leading) * 2.2))
    }

    /// The masks for a strip of `width × height` pixels. The same seed draws
    /// the same water, so the pattern holds still between redraws.
    public static func field(width: Int, height: Int, meeting mid: Double, seed: UInt64 = 7) -> Field {
        let w = max(1, width), h = max(1, height)
        var noise = Noise(seed: seed)
        let swell = noise.layer(cells: (1, 7))
        let eddy = noise.layer(cells: (2, 16))
        let current = noise.layer(cells: (7, 4))
        var sea = [UInt8](repeating: 0, count: w * h)
        var shade = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            let v = (Double(y) + 0.5) / Double(h)
            // The meeting line meanders down the fold in a long, slow swell.
            let line = mid + 0.12 * (swell.value(0.5, v) - 0.5) * 2
            for x in 0..<w {
                let t = (Double(x) + 0.5) / Double(w)
                // Broad eddies curl either way across it…
                var tt = t + 0.20 * (eddy.value(t, v) - 0.5) * 2
                let near = exp(-pow((tt - line) / 0.22, 2))
                // …and currents run along each sea in long soft streaks.
                let streak = current.value(t, v) - 0.5
                tt += 0.10 * streak * near
                let k = smoothstep((tt - (line - 0.13)) / 0.26)
                let foam = exp(-pow((k - 0.5) / 0.22, 2)) * 0.07
                let hinge = 0.12 * exp(-pow((t - 0.5) / 0.08, 2))
                // Kept to darkening: the grain's light half would wash a pale ground out.
                let keep = min(1, (1 + 0.10 * streak) * (1 - 0.08 * near) * (1 - hinge)) * (1 - foam)
                let i = y * w + x
                sea[i] = UInt8((k * 255).rounded())
                let alpha = 1 - keep
                let grey = foam * 225 / 255            // premultiplied
                shade[i * 4] = UInt8(min(255, (grey * 255).rounded()))
                shade[i * 4 + 1] = shade[i * 4]
                shade[i * 4 + 2] = shade[i * 4]
                shade[i * 4 + 3] = UInt8(min(255, (alpha * 255).rounded()))
            }
        }
        return Field(width: w, height: h, sea: sea, shade: shade)
    }

    /// A page ground's luminance below which it is lifted, so the fold never
    /// reads as a black gap (a poster that is mostly black).
    public static let darkFloor = 0.08

    /// How much to brighten a ground of relative luminance `lum` (0…1).
    public static func lift(luminance lum: Double) -> Double {
        lum >= darkFloor ? 0 : 0.10 * (darkFloor - lum) / darkFloor
    }

    static func smoothstep(_ x: Double) -> Double {
        let k = min(1, max(0, x))
        return k * k * (3 - 2 * k)
    }
}

/// Smooth value noise in two octaves, from a seeded generator.
struct Noise {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }

    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state >> 11) / Double(1 << 53)
    }

    /// Two octaves over a `cells` grid (columns, rows), the second at twice the cells and half the weight.
    mutating func layer(cells: (Int, Int)) -> Layer {
        Layer(octaves: [grid(cells.0, cells.1), grid(cells.0 * 2, cells.1 * 2)])
    }

    private mutating func grid(_ cols: Int, _ rows: Int) -> Grid {
        Grid(cols: cols, rows: rows, values: (0..<((cols + 1) * (rows + 1))).map { _ in next() })
    }

    struct Grid {
        let cols: Int, rows: Int, values: [Double]

        func value(_ u: Double, _ v: Double) -> Double {
            let x = min(Double(cols), max(0, u * Double(cols)))
            let y = min(Double(rows), max(0, v * Double(rows)))
            let x0 = min(cols - 1, Int(x)), y0 = min(rows - 1, Int(y))
            let fx = FoldSeas.smoothstep(x - Double(x0)), fy = FoldSeas.smoothstep(y - Double(y0))
            func at(_ c: Int, _ r: Int) -> Double { values[r * (cols + 1) + c] }
            let top = at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx
            let bottom = at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx
            return top * (1 - fy) + bottom * fy
        }
    }

    struct Layer {
        let octaves: [Grid]

        func value(_ u: Double, _ v: Double) -> Double {
            (octaves[0].value(u, v) + 0.5 * octaves[1].value(u, v)) / 1.5
        }
    }
}
