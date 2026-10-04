import SwiftUI
import FusionhaKit

/// fusionha's design tokens (`design/DESIGN-STANDARDS.md`), shared by the app and widgets.
enum Theme {
    // Surfaces and text (web `styles/tokens.css`, dark theme).
    static let bg = Color(hex: 0x0C0D11)
    static let panel = Color(hex: 0x14161D)
    static let panel2 = Color(hex: 0x181B23)
    static let card = Color(hex: 0x151821)
    static let line = Color.white.opacity(0.08)
    static let txt = Color(hex: 0xE9EAF0)
    static let mut = Color(hex: 0x9AA0AD)
    static let dim = Color(hex: 0x6B7280)

    static let kindMovie = Color(hex: 0x38BDF8)
    static let kindSeries = Color(hex: 0xA855F7)
    static let kindAnime = Color(hex: 0xF472B6)

    static let radiusSm: CGFloat = 9
    static let radius: CGFloat = 11
    static let radiusLg: CGFloat = 14

    static let indigo = Color(hex: 0x6366F1)
    static let cyan = Color(hex: 0x22D3EE)
    /// `--i1` / `--i2` aliases, so ports read like the CSS.
    static let i1 = indigo
    static let i2 = cyan
    /// The "fusion" gradient. Brand mark and primary actions only, never a status.
    static let fusion = LinearGradient(colors: [indigo, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let done = Color(hex: 0x34D399)
    static let grab = Color(hex: 0x22D3EE)
    static let miss = Color(hex: 0xF59E0B)
    static let unaired = Color(hex: 0x3B82F6)
    static let unmonitored = Color(hex: 0x6B7280)
    static let onair = Color(hex: 0xFBBF24)
    static let premiere = Color(hex: 0x818CF8)
    static let stuck = Color(hex: 0xFB923C)
    static let edition = Color(hex: 0xA78BFA)
    static let anime = Color(hex: 0xF472B6)
    static let danger = Color(hex: 0xF87171)
    static let plexGold = Color(hex: 0xE5A00D)

    /// The login screen's brand gradient (Login.module.css `.stage --grad`).
    static let loginGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x3B82F6), location: 0),
            .init(color: Color(hex: 0x8B5CF6), location: 0.38),
            .init(color: Color(hex: 0xD946EF), location: 0.66),
            .init(color: Color(hex: 0xF9A826), location: 1),
        ],
        startPoint: .leading, endPoint: .trailing)

    /// Library kind accents (`--kind-*`); animation rides the anime pink.
    static func kind(_ kind: LibraryKind) -> Color {
        switch kind {
        case .movie: return kindMovie
        case .series: return kindSeries
        case .anime, .animation: return kindAnime
        }
    }

    /// Mobile layout tokens (`--page-gutter`, `--bottom-nav-clearance`).
    /// SegGroup active text: `color-mix(in srgb, var(--i2) 45%, var(--txt))`.
    static let segActiveText = Color(hex: 0x8FE0EF)

    static let pageGutter: CGFloat = 10
    static let bottomNavClearance: CGFloat = 76

    static func kind(_ bucket: KindBucket) -> Color {
        switch bucket {
        case .movie: return kindMovie
        case .series: return kindSeries
        case .anime: return kindAnime
        }
    }
}

extension RailState {
    /// Rail fill colour, from the web's RAIL_STATUS map.
    var color: Color {
        switch self {
        case .owned: return Theme.done
        case .partial, .wanted: return Theme.miss
        case .downloading: return Theme.grab
        case .upgrading: return Theme.edition
        case .upcoming: return Theme.unaired
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

extension EditionStatus {
    /// Same status → colour mapping as the web's `status.ts`.
    var color: Color {
        switch self {
        case .downloaded: return Theme.done
        case .downloading, .available: return Theme.grab
        case .upgrading: return Theme.edition
        case .missing, .deadlink: return Theme.miss
        case .unaired, .upcoming: return Theme.unaired
        case .unmonitored, .other: return Theme.unmonitored
        case .onair: return Theme.onair
        case .premiere: return Theme.premiere
        case .stuck: return Theme.stuck
        }
    }
}

extension QualityTier {
    /// Tier chip colour: HD = edition purple, 4K = cyan.
    var color: Color { self == .hd ? Theme.edition : Theme.grab }
    /// The tier pill text on cards: `HD` / `4K`.
    var pill: String { self == .hd ? "HD" : "4K" }
}

/// A small edition chip, e.g. `UHD·4K` tinted by its status. Content, not glass.
struct EditionChip: View {
    let tier: QualityTier
    var status: EditionStatus? = nil

    var body: some View {
        let tint = status?.color ?? tier.color
        Text(tier.chipLabel)
            .font(.caption2.monospaced().weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
            .accessibilityLabel("\(tier.chipLabel)\(status.map { ", \($0.label)" } ?? "")")
    }
}
