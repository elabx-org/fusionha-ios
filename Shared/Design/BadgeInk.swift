import SwiftUI

/// The inks of the v2 edition badges and rails (A1 monochrome, owner
/// 2026-11-04). The letters and the fill carry the meaning, not a hue:
/// on disk is filled in the label colour with the letters knocked out,
/// missing is an outline in the secondary label colour, the accent is only
/// for downloading, and orange only for held.
///
/// v2 only: v1's badges and rails keep their status colours.
struct BadgeInk: Sendable {
    /// The on-disk fill and the rails' on-disk stretch (label colour, 86%).
    var fill: Color
    /// Letters knocked out of a fill: the ground.
    var knockout: Color
    /// A rail's empty track (label colour, 15%): missing.
    var track: Color
    /// Outlines, their letters and the "n/m" count (label colour, 55%).
    var secondary: Color
    /// Downloading: the ring and a rail's downloading stretch.
    var accent: Color
    /// Held: the orange outline and "!", and a rail's held stretch (the
    /// palette's `stuck`: one orange, see docs/v2.md).
    var held: Color
    /// Full-strength text beside a rail (the storage legend's values).
    var label: Color
    /// On achromatic palettes the accent and held inks land on the on-disk
    /// grey, so rails draw downloading hatched and held as an outline.
    var patterned: Bool
}

extension BadgeInk {
    /// On a page ground in a palette (the active one by default). The accent
    /// is the palette's `i1`, lifted toward white on the dark grounds like
    /// `Theme.accentText` (Aurora's `i2` is cyan, so it is never used here).
    /// Aurora takes the mock's `--i1t` (#A5B4FC) instead of the lift.
    static func page(_ t: PaletteTokens) -> BadgeInk {
        let txt = Color(hex: t.txt)
        let i1 = Color(hex: t.i1)
        let lifted = t.i1 == 0x6366F1 ? Color(hex: 0xA5B4FC) : i1.mix(with: .white, by: 0.3)
        return BadgeInk(
            fill: txt.opacity(0.86),
            knockout: Color(hex: t.bg),
            track: txt.opacity(0.15),
            secondary: txt.opacity(0.55),
            accent: t.isLight ? i1 : lifted,
            held: Color(hex: t.stuck),
            label: txt,
            patterned: t.isMono || t.i1 == t.i2 || isAchromatic(t.i1))
    }

    /// A grey: its channels within 0x10 of each other (OLED, Noir, Monochrome).
    static func isAchromatic(_ hex: UInt32) -> Bool {
        let r = (hex >> 16) & 0xFF, g = (hex >> 8) & 0xFF, b = hex & 0xFF
        return max(r, g, b) - min(r, g, b) < 0x10
    }

    /// The active palette's page ink.
    static var page: BadgeInk { page(Theme.palette) }

    /// On a page tinted from its art (v2 title pages): the page's ink and
    /// ground. `muted` defaults to the ink at 60%.
    static func tinted(ink: Color, ground: Color, muted: Color? = nil, palette t: PaletteTokens = Theme.palette) -> BadgeInk {
        let base = page(t)
        return BadgeInk(
            fill: ink.opacity(0.88),
            knockout: ground,
            track: ink.opacity(0.16),
            secondary: muted ?? ink.opacity(0.6),
            accent: base.accent,
            held: base.held,
            label: ink,
            patterned: base.patterned)
    }

    /// Over artwork (hero cards): white ink on a dark plate in every
    /// palette. Monochrome keeps its accent colourless.
    static func onArt(_ t: PaletteTokens) -> BadgeInk {
        BadgeInk(
            fill: .white.opacity(0.88),
            knockout: Color(red: 10 / 255, green: 10 / 255, blue: 14 / 255).opacity(0.86),
            track: .white.opacity(0.2),
            secondary: .white.opacity(0.62),
            accent: t.isMono ? .white.opacity(0.88) : Color(hex: 0xA5B4FC),
            held: t.isMono ? .white.opacity(0.88) : Color(hex: 0xFDBA74),
            label: .white,
            patterned: t.isMono)
    }

    static var onArt: BadgeInk { onArt(Theme.palette) }
}

private struct BadgeInkKey: EnvironmentKey {
    /// nil: the active palette's page ink, read when the badge draws (so a
    /// palette switch redraws it).
    static let defaultValue: BadgeInk? = nil
}

extension EnvironmentValues {
    var badgeInk: BadgeInk? {
        get { self[BadgeInkKey.self] }
        set { self[BadgeInkKey.self] = newValue }
    }
}

extension View {
    /// The ink for every badge and rail inside: `.page`, `.tinted(…)`, `.onArt`.
    func badgeInk(_ ink: BadgeInk) -> some View {
        environment(\.badgeInk, ink)
    }
}
