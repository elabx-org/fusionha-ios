import Foundation

// The v2 page ground's layers (mock palette-lift.js): a vertical base in the
// art's first and last colours, under soft ellipses of the three lifted
// colours. Pure numbers, so the view only draws them.

/// One soft ellipse of the mesh, in fractions of the page: centred at
/// (`x`, `y`), `rx` of the width and `ry` of the height across its radius,
/// fading from `color` at `alpha` to clear at `fade` of the radius.
public struct GroundEllipse: Equatable, Sendable {
    public let color: HSLColor
    public let alpha: Double
    public let x: Double, y: Double
    public let rx: Double, ry: Double
    public let fade: Double

    public init(color: HSLColor, alpha: Double, x: Double, y: Double, rx: Double, ry: Double, fade: Double) {
        self.color = color
        self.alpha = alpha
        self.x = x
        self.y = y
        self.rx = rx
        self.ry = ry
        self.fade = fade
    }
}

/// A whole ground: the base runs `top` to `bottom`, the ellipses sit on it.
public struct GroundRecipe: Equatable, Sendable {
    public let top: HSLColor
    public let bottom: HSLColor
    public let ellipses: [GroundEllipse]

    public init(top: HSLColor, bottom: HSLColor, ellipses: [GroundEllipse]) {
        self.top = top
        self.bottom = bottom
        self.ellipses = ellipses
    }
}

public enum PageGroundRecipe {
    /// The page ground from three lifted colours (`PaletteMath.lift`):
    /// light grounds are a touch fainter (k 0.9). The base is the palette's
    /// own colours, never the page's near-black, and four ellipses reach
    /// every corner (top left, right, lower left, foot right), so no side
    /// of a wide page (the open Duo) is left black. `deep` (OLED, Noir, the
    /// true-black palettes) keeps the page dark but still tinted. Nil for no
    /// colours.
    public static func page(_ lifted: [HSLColor], dark: Bool, deep: Bool = false) -> GroundRecipe? {
        guard let a = lifted.first else { return nil }
        let b = lifted.count > 1 ? lifted[1] : a
        let c = lifted.count > 2 ? lifted[2] : b
        let k = dark ? (deep ? 0.55 : 1.0) : 0.9
        let top = dark ? (deep ? 0.07 : 0.20) : 0.93
        let bottom = dark ? (deep ? 0.05 : 0.15) : 0.95
        return GroundRecipe(
            top: HSLColor(h: a.h, s: a.s * 0.6, l: top),
            bottom: HSLColor(h: c.h, s: c.s * 0.6, l: bottom),
            ellipses: [
                GroundEllipse(color: a, alpha: 0.62 * k, x: 0.10, y: 0.08, rx: 0.80, ry: 0.36, fade: 0.72),
                GroundEllipse(color: b, alpha: 0.50 * k, x: 0.92, y: 0.40, rx: 0.75, ry: 0.40, fade: 0.72),
                GroundEllipse(color: c, alpha: 0.52 * k, x: 0.25, y: 0.72, rx: 0.85, ry: 0.40, fade: 0.72),
                GroundEllipse(color: a, alpha: 0.45 * k, x: 0.80, y: 0.98, rx: 0.80, ry: 0.36, fade: 0.72),
            ])
    }

    /// The open Duo's list pane: a deeper wash of the same colours, so the
    /// title page beside it stays the brighter one.
    public static func listPane(_ lifted: [HSLColor], dark: Bool) -> GroundRecipe? {
        guard let a = lifted.first else { return nil }
        let c = lifted.count > 2 ? lifted[2] : lifted[lifted.count - 1]
        let k = dark ? 1.0 : 0.9
        let l = dark ? 0.30 : 0.84
        return GroundRecipe(
            top: HSLColor(h: a.h, s: a.s * 0.55, l: dark ? 0.10 : 0.94),
            bottom: HSLColor(h: c.h, s: c.s * 0.55, l: dark ? 0.085 : 0.955),
            ellipses: [
                GroundEllipse(color: HSLColor(h: a.h, s: a.s, l: l), alpha: 0.50 * k,
                              x: 0.08, y: 0.30, rx: 0.60, ry: 0.45, fade: 0.75),
                GroundEllipse(color: HSLColor(h: c.h, s: c.s, l: l), alpha: 0.45 * k,
                              x: 0.10, y: 0.92, rx: 0.60, ry: 0.50, fade: 0.75),
            ])
    }

    /// The page's text inks, from its lead colour (the kit's --tintink /
    /// --tintmut): near-white or near-black, carrying a little of the hue.
    public static func ink(_ lead: HSLColor, dark: Bool) -> HSLColor {
        HSLColor(h: lead.h, s: min(0.3, lead.s), l: dark ? 0.92 : 0.11)
    }

    public static func inkMuted(_ lead: HSLColor, dark: Bool) -> HSLColor {
        HSLColor(h: lead.h, s: min(0.2, lead.s), l: dark ? 0.72 : 0.35)
    }
}
