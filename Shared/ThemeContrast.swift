import SwiftUI
import UIKit

/// Palette-aware tokens for things that used to be a fixed `.white`, `.black`
/// or hex: text on status fills, shadows, shimmers and scrims. Every one
/// reads the active palette, so Daylight (light) and the pale-fill palettes
/// (OLED, Noir, Frost, Monochrome) keep their contrast.
extension Theme {
    // MARK: Contrast

    /// WCAG relative luminance of an sRGB hex colour.
    static func luminance(hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let c = Double((hex >> shift) & 0xFF) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    /// Black or white, whichever reads better on a fill of this hex colour.
    static func onFill(hex: UInt32) -> Color {
        // White wins when (1.05 / (L + 0.05)) beats ((L + 0.05) / 0.05).
        luminance(hex: hex) > 0.179 ? .black : .white
    }

    /// Black or white text on a fill of `color` (a palette colour or a blend).
    static func onTint(_ color: Color) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return .white }
        let hex = (UInt32((r * 255).rounded()) << 16) | (UInt32((g * 255).rounded()) << 8) | UInt32((b * 255).rounded())
        return onFill(hex: hex)
    }

    /// Text and glyphs on a `danger` fill (OLED's danger is pale pink).
    static var onDanger: Color { onFill(hex: palette.danger) }

    /// The accent as text (a status word, a link): lifted toward white on the
    /// dark grounds so small type keeps its contrast; the accent itself on Daylight.
    static var accentText: Color { isLight ? i1 : i1.mix(with: .white, by: 0.3) }

    /// The Letterboxd mark (the web's `LbIcon` in `--i2`); a grey under
    /// Monochrome, where a brand tint would read as a status.
    static var letterboxdMark: Color { isMono ? mut : i2 }

    // MARK: Surfaces

    /// The poster's drop shadow: deep on the dark grounds, soft on Daylight.
    static var shelfShadow: Color { .black.opacity(isLight ? 0.18 : 0.9) }

    /// The pole text is lifted toward on this ground: white on the dark
    /// palettes, black on Daylight.
    static var pole: Color { isLight ? .black : .white }

    /// Skeleton shimmer: light on dark grounds, dark on Daylight.
    static var shimmer: Color { pole }

    /// The band sweeping a download or progress fill (a `grab` fill): white on a
    /// dark fill, black on a pale one (OLED, Noir, Frost, Monochrome).
    static var sweep: Color { onTint(grab) }

    /// A dim disc or pill over poster art (art is dark in every palette).
    static var scrim: Color { Color(hex: 0x0C0D11) }

    /// Text and glyphs on a `scrim` plate (the scrim is dark in every palette).
    static var onScrim: Color { .white }

    /// The hairline ringing a frosted plate over art (the web's 16% white edge).
    static var plateLine: Color { onScrim.opacity(0.16) }

    /// The hole and track of a progress ring, from the ground.
    static var ringTrack: Color { isLight ? panel2 : .black.opacity(0.55) }
    static var ringHole: Color { bg.opacity(0.85) }

    // MARK: Library kinds

    /// Kind accents (`--kind-*`): web values on the dark palettes, deeper on
    /// Daylight's white, shades of grey on Monochrome.
    static var kindMovie: Color {
        isMono ? Color(hex: 0xF2F2F2) : isLight ? Color(hex: 0x0369A1) : Color(hex: 0x38BDF8)
    }
    static var kindSeries: Color {
        isMono ? Color(hex: 0xBDBDBD) : isLight ? Color(hex: 0x7E22CE) : Color(hex: 0xA855F7)
    }
    static var kindAnime: Color {
        isMono ? Color(hex: 0x8E8E8E) : isLight ? Color(hex: 0xBE185D) : Color(hex: 0xF472B6)
    }

    /// The deep end of a role avatar's gradient: the tint, darkened (flat in
    /// Monochrome, which has no hue to shade).
    static func avatarDeep(_ tint: Color) -> Color {
        isMono ? tint : tint.mix(with: .black, by: 0.3)
    }
}
