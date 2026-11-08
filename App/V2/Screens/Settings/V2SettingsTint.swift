import SwiftUI

/// S1 on every Settings page (mock settings-v2b.js): the page wears its
/// section's colour as a soft tint on the ground (`.s2-tint`): the page's own
/// hue from the top left, its section's partner hue from the top right, and
/// a faint wash of the first at the foot. Grey on Monochrome; lighter on
/// light palettes (the mock's `.light .s2-tint { opacity: .65 }`).
enum V2SettingsTint {
    /// Each sidebar section's second hue (settings-v2b.js `PAGES`).
    private static let partners: [String: [UInt32]] = [
        "top": [0x0A84FF, 0x8E8E93], "media": [0x30B0C7, 0x0A84FF], "quality": [0xD04DD0, 0xAF52DE],
        "access": [0x30A46C, 0x34C759], "fetching": [0xFF9500, 0xFF6A1F], "requests": [0xF25C8A, 0xFF2D55],
        "system": [0x0A84FF, 0x6E7A8A],
    ]

    private static func section(_ slug: String) -> String? {
        let id = SettingsNav.canonical(slug)
        if id == "group:quality" { return "quality" }
        if id == "group:access" { return "access" }
        return V2SettingsNav.sidebar.first { $0.rows.contains(id) }?.id
    }

    /// The page's two hues: its own (or its section's) and the partner.
    static func hues(_ slug: String) -> (Color, Color) {
        if Theme.isMono { return (Color(hex: 0x8E8E93), Color(hex: 0x6E6E73)) }
        if SettingsNav.canonical(slug) == "appearance" { return (Color(hex: 0x6366F1), Color(hex: 0x22B8D8)) }
        let options = section(slug).flatMap { partners[$0] } ?? [0x6366F1, 0x22B8D8]
        let own = V2SettingsLook.hue(slug) ?? options[0]
        let partner = options.first { $0 != own } ?? options[0]
        return (Color(hex: own), Color(hex: partner))
    }
}

/// The tint itself, laid over a page ground. Never takes touches.
struct V2SettingsTintLayer: View {
    let slug: String

    var body: some View {
        let hues = V2SettingsTint.hues(slug)
        let h1 = hues.0, h2 = hues.1
        let strength = Theme.isLight ? 0.65 : 1.0
        ZStack {
            EllipticalGradient(colors: [h1.opacity(0.30 * strength), .clear], center: .topLeading,
                               startRadiusFraction: 0, endRadiusFraction: 0.85)
                .frame(height: 520)
                .frame(maxHeight: .infinity, alignment: .top)
            EllipticalGradient(colors: [h2.opacity(0.18 * strength), .clear], center: .topTrailing,
                               startRadiusFraction: 0, endRadiusFraction: 0.65)
                .frame(height: 460)
                .frame(maxHeight: .infinity, alignment: .top)
            EllipticalGradient(colors: [h1.opacity(0.10 * strength), .clear], center: .bottom,
                               startRadiusFraction: 0, endRadiusFraction: 0.55)
                .frame(height: 520)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A whole ground for a v1 panel (`settingsGround`): the palette's tint
/// ground with the section tint over it.
struct V2SettingsTintedGround: View {
    let slug: String

    var body: some View {
        ZStack {
            PageGround(palette: .tokens(Theme.palette))
            V2SettingsTintLayer(slug: slug)
        }
    }
}

extension View {
    /// A v2 Settings page on its section-tinted ground (and the page palette
    /// down the environment, as `v2PageGround`).
    func v2SettingsGround(_ slug: String) -> some View {
        background { V2SettingsTintLayer(slug: slug) }
            .v2PageGround(art: nil)
    }
}
