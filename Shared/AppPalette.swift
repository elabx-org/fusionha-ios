import SwiftUI
import Observation
import WidgetKit
import FusionhaKit

/// The app's colour palettes (per device, Settings › Appearance). `Theme`'s
/// surfaces, text, accent and status colours read the active palette through
/// `PaletteStore`, an `@Observable`: every view that drew with a `Theme` colour
/// re-renders when the palette changes, so switching keeps your place.
/// Mocks: `docs/design/palettes/dark-palettes.html`.
enum AppPalette: String, CaseIterable, Identifiable, Sendable {
    case videoStore = "video-store"
    case graphite
    case oled
    case aurora
    case frost
    case eclipse
    case daylight
    case noir

    var id: String { rawValue }

    static let dark: [AppPalette] = [.videoStore, .graphite, .oled, .noir, .aurora, .frost, .eclipse]
    static let light: [AppPalette] = [.daylight]

    var isLight: Bool { tokens.isLight }

    var name: String {
        switch self {
        case .videoStore: return "Video store"
        case .graphite: return "Graphite indigo"
        case .oled: return "OLED mono"
        case .aurora: return "Aurora"
        case .frost: return "Frost"
        case .eclipse: return "Eclipse"
        case .daylight: return "Daylight"
        case .noir: return "Noir"
        }
    }

    var blurb: String {
        switch self {
        case .videoStore: return "Warm black, cream and brass."
        case .graphite: return "The web app's cool greys with its indigo accent."
        case .oled: return "True black and white; colour comes only from posters and statuses."
        case .aurora: return "The web app exactly: cool ink, indigo to cyan."
        case .frost: return "Blue-black slate with a frosted, pale-blue light."
        case .eclipse: return "Ink black lit by a sunset corona, coral to magenta to violet."
        case .daylight: return "The web app's light theme with the indigo accent."
        case .noir: return "Black and white at full contrast: white type and hairlines on black, like a film title card."
        }
    }

    var tokens: PaletteTokens {
        switch self {
        case .videoStore: return .videoStore
        case .graphite: return .graphite
        case .oled: return .oled
        case .aurora: return .aurora
        case .frost: return .frost
        case .eclipse: return .eclipse
        case .daylight: return .daylight
        case .noir: return .noir
        }
    }
}

/// Light, dark, or follow the system (the light palette by day, the dark one at night).
enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case dark, light, automatic
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .automatic: return "Automatic"
        }
    }
}

/// One palette's colours. Status and tier hues are the web's `status.ts`; the
/// light palette deepens them a step so they stay readable on white.
struct PaletteTokens: Sendable {
    let isLight: Bool
    let bg: UInt32, panel: UInt32, panel2: UInt32
    /// The hairline colour and its opacity.
    let line: UInt32, lineOpacity: Double
    let txt: UInt32, mut: UInt32, dim: UInt32
    /// Control tint and quiet accents (`--i1`), and links / the selected mark (`--i2`).
    let i1: UInt32, i2: UInt32
    /// The primary action's fill (top/leading to bottom/trailing) and its text.
    let primaryFrom: UInt32, primaryTo: UInt32, onPrimary: UInt32
    /// Text and ticks on a fill of `i1` (a checked box, an accent button).
    let onAccent: UInt32
    var done: UInt32 = 0x34D399
    var grab: UInt32 = 0x22D3EE
    var miss: UInt32 = 0xF59E0B
    var unaired: UInt32 = 0x3B82F6
    var unmonitored: UInt32 = 0x6B7280
    var onair: UInt32 = 0xFBBF24
    var premiere: UInt32 = 0x818CF8
    var stuck: UInt32 = 0xFB923C
    var edition: UInt32 = 0xA78BFA
    var anime: UInt32 = 0xF472B6
    var danger: UInt32 = 0xF87171
    /// An optional middle stop for the primary fill (Eclipse's three-colour corona).
    var primaryVia: UInt32? = nil

    static let videoStore = PaletteTokens(
        isLight: false, bg: 0x0F0D0B, panel: 0x1A1714, panel2: 0x24201C, line: 0xF4ECE1, lineOpacity: 0.08,
        txt: 0xF4ECE1, mut: 0xB3A796, dim: 0x8C8172, i1: 0xD9C3A0, i2: 0xEDE0CB,
        primaryFrom: 0xFBF5EC, primaryTo: 0xE9DECF, onPrimary: 0x15110D, onAccent: 0x15110D)

    static let graphite = PaletteTokens(
        isLight: false, bg: 0x0E0F13, panel: 0x16181E, panel2: 0x1D2028, line: 0xFFFFFF, lineOpacity: 0.08,
        txt: 0xECEDF3, mut: 0xA0A5B3, dim: 0x6E7381, i1: 0x818CF8, i2: 0xA5B4FC,
        primaryFrom: 0x6366F1, primaryTo: 0x818CF8, onPrimary: 0xFFFFFF, onAccent: 0xFFFFFF)

    static let oled = PaletteTokens(
        isLight: false, bg: 0x000000, panel: 0x111113, panel2: 0x1A1A1D, line: 0xFFFFFF, lineOpacity: 0.09,
        txt: 0xF5F5F7, mut: 0xA1A1A6, dim: 0x6E6E73, i1: 0xD1D1D6, i2: 0xFFFFFF,
        primaryFrom: 0xFFFFFF, primaryTo: 0xE5E5EA, onPrimary: 0x000000, onAccent: 0x000000)

    static let aurora = PaletteTokens(
        isLight: false, bg: 0x0C0D11, panel: 0x14161D, panel2: 0x181B23, line: 0xFFFFFF, lineOpacity: 0.08,
        txt: 0xE9EAF0, mut: 0x9AA0AD, dim: 0x6B7280, i1: 0x6366F1, i2: 0x22D3EE,
        primaryFrom: 0x6366F1, primaryTo: 0x22D3EE, onPrimary: 0x08131A, onAccent: 0xFFFFFF)

    static let eclipse = PaletteTokens(
        isLight: false, bg: 0x09080B, panel: 0x131116, panel2: 0x1B181F, line: 0xFFF0F5, lineOpacity: 0.08,
        txt: 0xF4F0F6, mut: 0xABA3B0, dim: 0x726B78, i1: 0xFF5C7A, i2: 0xFF9DB4,
        primaryFrom: 0xFF7A45, primaryTo: 0x8B5CF6, onPrimary: 0xFFFFFF, onAccent: 0xFFFFFF,
        primaryVia: 0xFF2E7E)

    static let frost = PaletteTokens(
        isLight: false, bg: 0x0B0E13, panel: 0x121821, panel2: 0x19212C, line: 0xC8DCFF, lineOpacity: 0.08,
        txt: 0xE8EEF6, mut: 0x93A1B5, dim: 0x627086, i1: 0x8EA8EE, i2: 0xB9CCFF,
        primaryFrom: 0xF4F8FF, primaryTo: 0xC8D7F5, onPrimary: 0x0B1220, onAccent: 0x0B1220)

    static let daylight = PaletteTokens(
        isLight: true, bg: 0xF5F6F8, panel: 0xFFFFFF, panel2: 0xF0F1F4, line: 0x0F1115, lineOpacity: 0.10,
        txt: 0x14161D, mut: 0x55606F, dim: 0x8A94A3, i1: 0x4F46E5, i2: 0x4338CA,
        primaryFrom: 0x4F46E5, primaryTo: 0x6366F1, onPrimary: 0xFFFFFF, onAccent: 0xFFFFFF,
        done: 0x059669, grab: 0x0891B2, miss: 0xD97706, unaired: 0x2563EB, unmonitored: 0x6B7280,
        onair: 0xCA8A04, premiere: 0x6366F1, stuck: 0xEA580C, edition: 0x7C3AED, anime: 0xDB2777,
        danger: 0xDC2626)

    static let noir = PaletteTokens(
        isLight: false, bg: 0x000000, panel: 0x000000, panel2: 0x0E0E0E, line: 0xFFFFFF, lineOpacity: 0.22,
        txt: 0xFFFFFF, mut: 0xC7C7C7, dim: 0x8A8A8A, i1: 0xFFFFFF, i2: 0xFFFFFF,
        primaryFrom: 0xFFFFFF, primaryTo: 0xFFFFFF, onPrimary: 0x000000, onAccent: 0x000000)
}

extension PaletteTokens {
    /// The primary action's fill, top-leading to bottom-trailing.
    var primaryGradient: LinearGradient {
        let stops = [primaryFrom] + (primaryVia.map { [$0] } ?? []) + [primaryTo]
        return LinearGradient(colors: stops.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// The device's palette choice, stored in the App Group so the widgets match.
/// Not actor-bound: `Theme` reads it from any context.
@Observable
final class PaletteStore {
    static let shared = PaletteStore()

    private static let paletteKey = "app_palette"
    private static let lightKey = "app_palette_light"
    private static let appearanceKey = "app_appearance"
    private static var defaults: UserDefaults { UserDefaults(suiteName: CredentialStore.appGroup) ?? .standard }

    /// The dark palette (used for Dark, and at night with Automatic).
    private(set) var darkPalette: AppPalette
    /// The light palette (used for Light, and by day with Automatic).
    private(set) var lightPalette: AppPalette
    private(set) var appearance: AppAppearance
    /// What the system is showing, for Automatic.
    private(set) var systemIsLight = false
    /// The palette on screen now.
    private(set) var active: AppPalette
    /// The sign-in screen is drawn over a dark backdrop, so it keeps the dark palette.
    private(set) var signInShowing = false
    /// Widgets stay dark (their art and glass are designed for it); they use the dark palette.
    private let isWidget = Bundle.main.bundleIdentifier?.hasSuffix(".widgets") == true

    private init() {
        let d = Self.defaults
        let dark = AppPalette(rawValue: d.string(forKey: Self.paletteKey) ?? "") ?? .videoStore
        darkPalette = AppPalette.dark.contains(dark) ? dark : .videoStore
        let light = AppPalette(rawValue: d.string(forKey: Self.lightKey) ?? "") ?? .daylight
        lightPalette = AppPalette.light.contains(light) ? light : .daylight
        appearance = AppAppearance(rawValue: d.string(forKey: Self.appearanceKey) ?? "") ?? .dark
        #if DEBUG
        // CI screenshots: `FUSIONHA_SCREENSHOT_PALETTE=daylight` shows one palette.
        if let raw = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_PALETTE"], let forced = AppPalette(rawValue: raw) {
            if forced.isLight { lightPalette = forced; appearance = .light } else { darkPalette = forced; appearance = .dark }
        }
        #endif
        active = darkPalette
        active = resolve()
    }

    /// The colour scheme to force (nil follows the system).
    var preferredScheme: ColorScheme? {
        switch appearance {
        case .dark: return .dark
        case .light: return .light
        case .automatic: return nil
        }
    }

    /// What the screen is forced to (nil follows the system); dark while signed out.
    var screenScheme: ColorScheme? { signInShowing ? .dark : preferredScheme }

    /// Picks a palette: a dark one becomes the dark palette, a light one the
    /// light palette. Picking one the current appearance wouldn't show switches
    /// the appearance to match (Automatic stays Automatic).
    func select(_ palette: AppPalette) {
        if palette.isLight {
            lightPalette = palette
            Self.defaults.set(palette.rawValue, forKey: Self.lightKey)
            if appearance == .dark { select(appearance: .light) }
        } else {
            darkPalette = palette
            Self.defaults.set(palette.rawValue, forKey: Self.paletteKey)
            if appearance == .light { select(appearance: .dark) }
            WidgetCenter.shared.reloadAllTimelines()
        }
        apply()
    }

    func select(appearance next: AppAppearance) {
        appearance = next
        Self.defaults.set(next.rawValue, forKey: Self.appearanceKey)
        apply()
    }

    func setSignInShowing(_ on: Bool) {
        guard signInShowing != on else { return }
        signInShowing = on
        apply()
    }

    func systemScheme(_ scheme: ColorScheme) {
        guard systemIsLight != (scheme == .light) else { return }
        systemIsLight = scheme == .light
        apply()
    }

    /// Re-reads the stored choice (the widgets, which run in their own process).
    func reload() {
        let fresh = PaletteStore()
        darkPalette = fresh.darkPalette
        lightPalette = fresh.lightPalette
        appearance = fresh.appearance
        apply()
    }

    private func apply() {
        let next = resolve()
        if next != active { active = next }
    }

    private func resolve() -> AppPalette {
        if isWidget || signInShowing { return darkPalette }
        switch appearance {
        case .dark: return darkPalette
        case .light: return lightPalette
        case .automatic: return systemIsLight ? lightPalette : darkPalette
        }
    }
}
