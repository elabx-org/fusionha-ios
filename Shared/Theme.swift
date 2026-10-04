import SwiftUI
import FusionhaKit

/// fusionha's design tokens (`design/DESIGN-STANDARDS.md`), shared by the app and widgets.
enum Theme {
    static let indigo = Color(hex: 0x6366F1)
    static let cyan = Color(hex: 0x22D3EE)
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
