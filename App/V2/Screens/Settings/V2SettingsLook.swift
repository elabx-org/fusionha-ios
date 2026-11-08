import SwiftUI

/// The S1 Settings look (mock settings-v2.js `T`): each row's tile colour
/// and symbol. Every section owns a hue family, as iOS Settings does: blues
/// for media, purple for quality, green for access, orange for fetching,
/// pink for requests, slate for system. Monochrome draws every tile grey.
enum V2SettingsLook {
    /// System hues per panel (the mock's), then the section's family.
    private static let hues: [String: UInt32] = [
        "overview": 0x6366F1, "general": 0x8E8E93, "metadata": 0x0A84FF,
        "roots": 0x0A84FF, "naming": 0x5E5CE6, "filemanagement": 0x30B0C7,
        "importlists": 0x0091D5, "import": 0x3D7BF7,
        "group:quality": 0xAF52DE, "profiles": 0xAF52DE, "formats": 0xD04DD0,
        "qualitydefinitions": 0x9B59D0, "releasefilters": 0xBF5AF2, "blocklist": 0x8E44AD,
        "defaultprofiles": 0xA463E0, "trash": 0xC062C9,
        "group:access": 0x34C759, "access": 0x34C759, "roles": 0x30A46C, "signin": 0x28B463,
        "plexserver": 0x3FAE5A, "publicaccess": 0x2FB57E, "apikey": 0x4CAF50,
        "clients": 0xFF9500, "indexers": 0xFF6A1F, "connect": 0xE8A10C,
        "notifications": 0xFF3B30, "instances": 0xA2845E,
        "request-rules": 0xFF2D55, "guardrails": 0xF25C8A,
        "system": 0x636366, "database": 0x6E7A8A, "backup": 0x4E6E8E, "security": 0x5B6676,
        "logs": 0x7C8794, "about": 0x8E8E93, "versions": 0x6B7280, "experimental": 0x5E6B7D,
        "discover": 0x56708A, "maintenance": 0x707A88,
    ]

    /// Symbols where the mock differs from v1's (and the CLAUDE.md icon
    /// rules: the magnifying glass is automatic search, the bin is delete).
    private static let symbols: [String: String] = [
        "overview": "square.grid.2x2.fill", "general": "gearshape.fill", "metadata": "book.fill", "roots": "folder.fill",
        "naming": "doc.text.fill", "import": "tray.and.arrow.down.fill",
        "group:quality": "viewfinder", "group:access": "checkmark.shield.fill",
        "trash": "books.vertical.fill", "indexers": "antenna.radiowaves.left.and.right",
        "clients": "arrow.down.to.line", "connect": "powerplug.fill", "notifications": "bell.fill",
        "instances": "link", "request-rules": "checklist", "guardrails": "shield.fill",
        "appearance": "paintpalette.fill", "system": "clock.fill", "backup": "clock.arrow.circlepath",
        "security": "lock.fill", "logs": "text.alignleft", "about": "info.circle.fill",
        "maintenance": "wrench.adjustable.fill", "discover": "safari.fill", "experimental": "flask.fill",
        "access": "person.2.fill", "roles": "checkmark.shield.fill", "signin": "key.fill",
        "apikey": "key.horizontal.fill", "publicaccess": "globe", "plexserver": "server.rack",
        "database": "cylinder.split.1x2.fill", "versions": "film.fill",
    ]

    /// A panel's own hue (nil when it has none of its own).
    static func hue(_ id: String) -> UInt32? { hues[SettingsNav.canonical(id)] ?? hues[id] }

    static func symbol(_ id: String) -> String {
        symbols[id] ?? SettingsNav.panel(id)?.icon ?? "gearshape"
    }

    /// The tile's fill: the hue with a lighter top (`linear-gradient(180deg,
    /// mix(c 78%, #fff), c)`). Appearance wears the brand gradient.
    static func fill(_ id: String) -> AnyShapeStyle {
        if Theme.isMono { return AnyShapeStyle(Color(hex: 0x6E6E73).gradient) }
        if id == "appearance" {
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x7C7FF7), Color(hex: 0x6366F1), Color(hex: 0x22B8D8)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        let c = Color(hex: hues[id] ?? 0x8E8E93)
        return AnyShapeStyle(LinearGradient(colors: [c.mix(with: .white, by: 0.22), c], startPoint: .top, endPoint: .bottom))
    }
}

/// A rounded square in the row's hue with a white symbol (iOS Settings).
struct V2SettingsTile: View {
    let id: String
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: V2SettingsLook.symbol(id))
            .font(.system(size: size * 0.53, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(V2SettingsLook.fill(id), in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.38), .clear], startPoint: .top, endPoint: .center),
                                  lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}
