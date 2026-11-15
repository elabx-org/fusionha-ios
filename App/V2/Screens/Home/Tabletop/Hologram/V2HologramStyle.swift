import SwiftUI
import FusionhaKit

/// How the hologram stands its focused title (2026-11-15), kept on this
/// device under `key` and chosen in the Hologram button's long-press menu
/// (`V2HologramSwitch`):
/// - `across` ("Across the fold", the default): the card stands on the
///   table just in front of the fold, drawn across both halves in a black
///   room drawn in lines.
/// - `glass` ("At the fold"): the card stands on the upright half itself
///   (`TabletopGlass`), and the upright half is pure black on every palette
///   with nothing else drawn on it, because black glass shows a real, dim
///   reflection of the bright table half at its true depth. The table half
///   is a black floor with its grid at full strength up to the fold.
enum V2HologramStyle: String, CaseIterable, Identifiable {
    case across
    case glass

    static let key = "v2.home.tabletopHologramStyle"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .across: "Across the fold"
        case .glass: "At the fold"
        }
    }

    /// How far toward "At the fold" the scene is drawn (the change animates it).
    var amount: Double { self == .glass ? 1 : 0 }

    /// The stored style; CI screenshots:
    /// `FUSIONHA_SCREENSHOT_TABLETOP_STYLE=glass|across` draws that one.
    static func current(stored: String) -> V2HologramStyle {
        #if DEBUG
        if let forced = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_TABLETOP_STYLE"]
            .flatMap(V2HologramStyle.init(rawValue:)) { return forced }
        #endif
        return V2HologramStyle(rawValue: stored) ?? .across
    }

    /// The style as the tabletop appears.
    static var resting: V2HologramStyle {
        current(stored: UserDefaults.standard.string(forKey: key) ?? across.rawValue)
    }
}

/// The page's type and controls over "At the fold": the room is black on
/// every palette, so they take light inks, the dark glass and the HD/4K
/// badges' dark-palette ink (a light palette's badges take Graphite's, its
/// indigo on dark grey). Only views inside read it: the page's own body
/// reads the palette from outside (`V2HologramHeading`).
struct V2HologramOnBlack: ViewModifier {
    let on: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.pagePalette) private var page
    @Environment(\.badgeInk) private var badge

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, on ? .dark : scheme)
            .environment(\.pagePalette, on ? onBlack : page)
            .environment(\.badgeInk, on ? BadgeInk.page(Self.darkTokens) : badge)
    }

    /// The active palette, or Graphite when it is a light one.
    static var darkTokens: PaletteTokens {
        Theme.palette.isLight ? .graphite : Theme.palette
    }

    private var onBlack: PagePalette {
        PagePalette(recipe: page?.recipe, paneRecipe: page?.paneRecipe,
                    tint: page?.tint ?? .black, tint2: page?.tint2 ?? .black,
                    ink: .white, inkMuted: .white.opacity(0.62),
                    isLight: false, isMono: page?.isMono ?? Theme.isMono)
    }
}

extension View {
    func hologramOnBlack(_ on: Bool) -> some View { modifier(V2HologramOnBlack(on: on)) }
}
