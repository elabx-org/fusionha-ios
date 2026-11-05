import SwiftUI
import FusionhaKit

/// The v2 page's palette (mock palette-lift.js), carried down the view tree
/// so everything on the page follows its art: the ground's mesh, the page
/// tints (the mock's --tint / --tint2: fades, the hero foot, cards on the
/// tint), the text inks (--tintink / --tintmut) and the badge ink.
///
/// Built either from the art's dominant colours (lifted for the palette) or,
/// with no art, from the palette's own tokens. v2 only reads it; v1 never
/// sets it.
struct PagePalette: Equatable, Sendable {
    /// The ground's layers; nil draws the token tint ground instead.
    var recipe: GroundRecipe?
    /// The list pane's deeper wash (open Duo), from the same colours.
    var paneRecipe: GroundRecipe?
    var tint: Color
    var tint2: Color
    var ink: Color
    var inkMuted: Color
    var isLight: Bool
    /// The palette has no hue (Monochrome, Noir, OLED): grounds stay grey.
    var isMono: Bool
    /// The colours came from art (false: the token tint).
    var fromArt: Bool { recipe != nil }

    /// Hue-less palettes skip the lift's saturation (plan S3).
    static func dropsHue(_ t: PaletteTokens) -> Bool {
        t.isMono || BadgeInk.isAchromatic(t.i1)
    }

    /// The true-black palettes (OLED, Noir): their grounds stay dark, tinted.
    static func isDeep(_ t: PaletteTokens) -> Bool {
        !t.isLight && t.bg == 0x000000
    }

    /// From an artwork's dominant colours (`ArtPaletteExtractor`), lifted for
    /// the palette `t`. Falls back to the token tint when `dominant` is empty.
    static func art(_ dominant: [HSLColor], tokens t: PaletteTokens) -> PagePalette {
        let dark = !t.isLight, mono = dropsHue(t)
        let lifted = dominant.map { PaletteMath.lift($0, dark: dark, mono: mono) }
        guard let lead = lifted.first,
              let recipe = PageGroundRecipe.page(lifted, dark: dark, deep: isDeep(t)) else { return tokens(t) }
        return PagePalette(
            recipe: recipe,
            paneRecipe: PageGroundRecipe.listPane(lifted, dark: dark),
            tint: Color(hsl: PaletteMath.tint(lead, dark: dark)),
            tint2: Color(hsl: PaletteMath.tint2(lead, dark: dark)),
            ink: Color(hsl: PageGroundRecipe.ink(lead, dark: dark)),
            inkMuted: Color(hsl: PageGroundRecipe.inkMuted(lead, dark: dark)),
            isLight: t.isLight,
            isMono: mono)
    }

    /// A page with no art: the palette's own ground and inks (cards-w.js
    /// `.w1-tint`, built from the tokens).
    static func tokens(_ t: PaletteTokens) -> PagePalette {
        PagePalette(
            recipe: nil,
            paneRecipe: nil,
            tint: Color(hex: t.bg),
            tint2: Color(hex: t.card ?? t.panel),
            ink: Color(hex: t.txt),
            inkMuted: Color(hex: t.mut),
            isLight: t.isLight,
            isMono: dropsHue(t))
    }

    /// The badge and rail ink on this page.
    func badgeInk(_ t: PaletteTokens) -> BadgeInk {
        fromArt ? .tinted(ink: ink, ground: tint, muted: inkMuted, palette: t) : .page(t)
    }
}

extension Color {
    /// An HSL colour (`PaletteMath`), in sRGB.
    init(hsl: HSLColor, opacity: Double = 1) {
        let c = PaletteMath.rgb(hsl)
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: opacity)
    }
}

private struct PagePaletteKey: EnvironmentKey {
    /// nil: not on a v2 page ground; read `Theme` as usual.
    static let defaultValue: PagePalette? = nil
}

extension EnvironmentValues {
    /// The page palette set by `.v2PageGround(…)`; nil off a v2 ground.
    var pagePalette: PagePalette? {
        get { self[PagePaletteKey.self] }
        set { self[PagePaletteKey.self] = newValue }
    }
}
