import Foundation

/// The palette families that change how blurred art is drawn: Monochrome
/// keeps it grey, light palettes (Daylight) use a fainter glow.
public enum ArtTone: String, Sendable, CaseIterable {
    case dark, light, mono

    /// Monochrome wins over light: a light mono palette still stays grey.
    public init(isLight: Bool, isMono: Bool) {
        self = isMono ? .mono : isLight ? .light : .dark
    }
}

/// A rectangle in pixels, top-left origin.
public struct ArtBlurRect: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// How one piece of blurred art is rendered once into a small bitmap, so a
/// scrolling grid draws a plain image instead of a live blur, saturation and
/// opacity pass per card. Pure numbers: the app renders it (Core Image).
public struct ArtBlurSpec: Hashable, Sendable {
    public enum Kind: String, Sendable {
        /// The soft glow of a poster's or shelf card's own art under it.
        case glow
        /// The title page's ambient wash (`AmbientBackdrop`).
        case detailAmbient
        /// The preview / add page's ambient wash (`PreviewAmbient`).
        case previewAmbient
    }

    public var kind: Kind
    public var tone: ArtTone
    /// The bitmap's size in pixels.
    public var canvasWidth: Double
    public var canvasHeight: Double
    /// Where the art is drawn (aspect-filled, clipped to `cornerRadius`).
    public var art: ArtBlurRect
    public var cornerRadius: Double
    /// Gaussian sigma in pixels.
    public var blur: Double
    public var saturation: Double
    public var brightness: Double
    /// Baked into the bitmap, so the view draws it at full opacity.
    public var alpha: Double
    /// Ambient art blurs with its edges clamped (fills to the edge); a glow
    /// fades out to transparent around the card.
    public var clampsEdges: Bool
    /// The bitmap's size over the frame it is drawn for: a glow bleeds past
    /// its card, so the image is scaled up around the card's centre.
    public var overscanX: Double
    public var overscanY: Double
    /// The size the source art is decoded at, in pixels (it is only colour).
    public var sourceWidth: Double
    public var sourceHeight: Double

    /// The cache key: one bitmap per URL, kind, tone and geometry.
    public func key(for url: String) -> String {
        "\(kind.rawValue)|\(tone.rawValue)|\(Int(canvasWidth.rounded()))x\(Int(canvasHeight.rounded()))"
            + "|r\(Int(cornerRadius.rounded()))|\(url)"
    }
}

extension ArtBlurSpec {
    /// The glow's bitmap is this many pixels across the card (it is soft).
    public static let glowPixels = 96.0
    /// The live glow it replaces: scale 0.92, dropped 12 pt, blur 20 pt,
    /// saturation 1.9 (0 in Monochrome), opacity 0.45 light / 0.6 dark.
    public static let glowBlur = 20.0
    public static let glowDrop = 12.0
    public static let glowInset = 0.92

    /// Aspects are bucketed to two decimals so 2:3 and 0.6667 share a bitmap.
    public static func bucket(_ aspect: Double) -> Double {
        guard aspect.isFinite, aspect > 0 else { return 1 }
        return (aspect * 100).rounded() / 100
    }

    /// The glow under a card `aspect` (width / height) wide, sized for a card
    /// `referenceWidth` points across (its usual phone width: the blur and
    /// drop scale with the card, so they match there and stay in proportion
    /// elsewhere). `cornerRadius` is the card's, in points.
    public static func glow(aspect: Double, tone: ArtTone, cornerRadius: Double,
                            referenceWidth: Double) -> ArtBlurSpec {
        let aspect = bucket(aspect)
        let w = max(referenceWidth, 1), h = w / aspect
        let pad = glowBlur * 3
        let k = glowPixels / w
        let artW = w * glowInset, artH = h * glowInset
        let art = ArtBlurRect(x: (pad + (w - artW) / 2) * k, y: (pad + (h - artH) / 2 + glowDrop) * k,
                              width: artW * k, height: artH * k)
        return ArtBlurSpec(kind: .glow, tone: tone,
                           canvasWidth: ((w + 2 * pad) * k).rounded(), canvasHeight: ((h + 2 * pad) * k).rounded(),
                           art: art, cornerRadius: cornerRadius * glowInset * k, blur: glowBlur * k,
                           saturation: tone == .mono ? 0 : 1.9, brightness: 0,
                           alpha: tone == .light ? 0.45 : 0.6, clampsEdges: false,
                           overscanX: (w + 2 * pad) / w, overscanY: (h + 2 * pad) / h,
                           sourceWidth: 160, sourceHeight: (160 / aspect).rounded())
    }

    /// An ambient wash: the art aspect-filled into a small `aspect` canvas,
    /// blurred as the live `blur(72)` was on a phone page (`frame`, scaled
    /// 1.28 and clipped), then saturated and dimmed.
    public static func ambient(_ kind: Kind, tone: ArtTone, aspect: Double,
                               frame: (width: Double, height: Double) = (393, 852)) -> ArtBlurSpec {
        let aspect = bucket(aspect)
        let canvasW = 96.0, canvasH = (canvasW / aspect).rounded()
        // The art's on-screen width: aspect-filled into the frame, then 1.28×.
        let shown = max(frame.width, frame.height * aspect) * 1.28
        let saturation = tone == .mono ? 0 : 1.4
        let brightness: Double
        switch kind {
        case .previewAmbient: brightness = -0.12
        default: brightness = tone == .light ? 0 : -0.2
        }
        return ArtBlurSpec(kind: kind, tone: tone, canvasWidth: canvasW, canvasHeight: canvasH,
                           art: ArtBlurRect(x: 0, y: 0, width: canvasW, height: canvasH), cornerRadius: 0,
                           blur: 72 * canvasW / shown, saturation: saturation, brightness: brightness,
                           alpha: 1, clampsEdges: true, overscanX: 1.28, overscanY: 1.28,
                           sourceWidth: 160, sourceHeight: (160 / aspect).rounded())
    }
}
