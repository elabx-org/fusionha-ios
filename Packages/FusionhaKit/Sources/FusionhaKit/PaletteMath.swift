import Foundation

// The v2 art palette ground (owner 2026-11-05, mock palette-lift.js): pull an
// artwork's vivid colours, lift them to a lightness floor so they never go
// muddy, and paint the page with them. Pure maths on a plain pixel array, so
// the app's extractor (it draws the art into a 40×40 bitmap) stays a thin
// shell and the rules are unit-tested.

/// One 8-bit sRGB pixel.
public struct RGBA8: Equatable, Sendable {
    public var r: UInt8, g: UInt8, b: UInt8, a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

/// A colour as hue (degrees, 0..<360), saturation and lightness (0...1).
public struct HSLColor: Equatable, Sendable {
    public var h: Double, s: Double, l: Double

    public init(h: Double, s: Double, l: Double) {
        self.h = h
        self.s = s
        self.l = l
    }
}

/// An artwork's palette, ready for the page: three lifted colours (the mesh)
/// and the two page tints (cards, fades, the hero foot).
public struct ArtPaletteColors: Equatable, Sendable {
    public let colors: [HSLColor]
    public let tint: HSLColor
    public let tint2: HSLColor
}

public enum PaletteMath {
    /// Hue buckets of 30°.
    public static let bucketCount = 12
    /// Pixels at or under this weight are grey or near black/white: skipped.
    static let minWeight = 0.05

    /// RGB channels 0...255 to HSL (the mock's `hsl`).
    public static func hsl(r: Double, g: Double, b: Double) -> HSLColor {
        let r = r / 255, g = g / 255, b = b / 255
        let mx = max(r, g, b), mn = min(r, g, b)
        let l = (mx + mn) / 2
        guard mx != mn else { return HSLColor(h: 0, s: 0, l: l) }
        let d = mx - mn
        let s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        var h: Double
        if mx == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if mx == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h *= 60
        return HSLColor(h: h, s: s, l: l)
    }

    public static func hsl(_ p: RGBA8) -> HSLColor {
        hsl(r: Double(p.r), g: Double(p.g), b: Double(p.b))
    }

    /// HSL to RGB channels 0...1.
    public static func rgb(_ c: HSLColor) -> (r: Double, g: Double, b: Double) {
        let s = min(1, max(0, c.s)), l = min(1, max(0, c.l))
        guard s > 0 else { return (l, l, l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        let h = (c.h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        func channel(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        return (channel(h + 1.0 / 3), channel(h), channel(h - 1.0 / 3))
    }

    /// How much a pixel counts: vivid and mid-lightness win, grey and
    /// near-black or near-white count for nothing.
    public static func weight(_ c: HSLColor) -> Double {
        c.s * (1 - abs(c.l - 0.5) * 1.6)
    }

    /// The hue bucket (0..<12) of a colour.
    public static func bucket(_ c: HSLColor) -> Int {
        Int((c.h / 30).rounded(.down)) % bucketCount
    }

    /// The `count` heaviest hue buckets, each as its weighted mean colour,
    /// heaviest first. Short lists are padded with the first colour, or with
    /// the whole image's average when nothing is vivid. Empty for no pixels.
    public static func dominant(_ pixels: [RGBA8], count: Int = 3) -> [HSLColor] {
        let visible = pixels.filter { $0.a > 0 }
        guard !visible.isEmpty, count > 0 else { return [] }
        var w = [Double](repeating: 0, count: bucketCount)
        var r = w, g = w, b = w
        var sum = (r: 0.0, g: 0.0, b: 0.0)
        for p in visible {
            let pr = Double(p.r), pg = Double(p.g), pb = Double(p.b)
            sum.r += pr
            sum.g += pg
            sum.b += pb
            let c = hsl(r: pr, g: pg, b: pb)
            let k = weight(c)
            guard k > minWeight else { continue }
            let i = bucket(c)
            w[i] += k
            r[i] += pr * k
            g[i] += pg * k
            b[i] += pb * k
        }
        let n = Double(visible.count)
        let average = hsl(r: sum.r / n, g: sum.g / n, b: sum.b / n)
        // Heaviest first; equal weights keep hue order (the mock's stable sort).
        let order = (0..<bucketCount).filter { w[$0] > 0 }
            .sorted { w[$0] != w[$1] ? w[$0] > w[$1] : $0 < $1 }
        var top = order.prefix(count).map { hsl(r: r[$0] / w[$0], g: g[$0] / w[$0], b: b[$0] / w[$0]) }
        let pad = top.first ?? average
        while top.count < count { top.append(pad) }
        return top
    }

    /// Lifts a colour to the ground's floor: dark pages keep it vivid and
    /// mid-dark (s 0.42–0.78, l 0.34–0.46), light pages pale (s 0.40–0.70,
    /// l 0.80–0.86). `mono` palettes drop the hue (s 0).
    public static func lift(_ c: HSLColor, dark: Bool, mono: Bool = false) -> HSLColor {
        let s = dark ? min(0.78, max(c.s, 0.42)) : min(0.70, max(c.s, 0.40))
        let l = dark ? min(0.46, max(c.l, 0.34)) : min(0.86, max(c.l, 0.80))
        return HSLColor(h: c.h, s: mono ? 0 : s, l: l)
    }

    /// The page tint, from the lead (lifted) colour.
    public static func tint(_ lead: HSLColor, dark: Bool) -> HSLColor {
        HSLColor(h: lead.h, s: min(0.5, lead.s), l: dark ? 0.15 : 0.935)
    }

    /// The deeper second tint (cards on the tint).
    public static func tint2(_ lead: HSLColor, dark: Bool) -> HSLColor {
        HSLColor(h: lead.h, s: min(0.5, lead.s), l: dark ? 0.19 : 0.895)
    }

    /// The whole palette for a page, or nil for an empty image.
    public static func palette(_ pixels: [RGBA8], dark: Bool, mono: Bool = false) -> ArtPaletteColors? {
        let top = dominant(pixels)
        guard let first = top.first else { return nil }
        let lifted = top.map { lift($0, dark: dark, mono: mono) }
        let lead = lift(first, dark: dark, mono: mono)
        return ArtPaletteColors(colors: lifted, tint: tint(lead, dark: dark), tint2: tint2(lead, dark: dark))
    }
}
