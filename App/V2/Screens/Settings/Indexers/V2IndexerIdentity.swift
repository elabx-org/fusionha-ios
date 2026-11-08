import SwiftUI
import FusionhaKit

/// Each indexer's identity (mock settings-ix.js `COL` / `MONO`): a colour
/// that is not a state (no orange or amber: a green dot is fine, orange is
/// backing off) and a two-letter monogram. Colours follow the indexers'
/// ids, so an indexer keeps its colour as the list re-sorts. Monochrome
/// draws them as steps of grey.
enum V2IndexerIdentity {
    private static let hues: [UInt32] = [
        0x0A84FF, 0x5E5CE6, 0x30B0C7, 0x34C759, 0xFF2D55, 0xAF52DE,
        0x00A5A0, 0xA2845E, 0x32ADE6, 0xBF5AF2, 0xFF375F, 0x8E8E93,
    ]

    /// The colour for an indexer, given every indexer's id.
    static func color(_ id: Int, among ids: [Int]) -> Color {
        let index = ids.sorted().firstIndex(of: id) ?? 0
        if Theme.isMono {
            return Theme.txt.opacity(max(0.3, 0.86 - Double(index % 6) * 0.1))
        }
        return Color(hex: hues[index % hues.count])
    }

    /// "altHUB" → "aH", "DrunkenSlug" → "DS", "Nzb.life" → "NL", "Easynews" → "Ea".
    static func monogram(_ name: String) -> String {
        let words = name.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        if words.count >= 2, let a = words[0].first, let b = words[1].first {
            return String(a).uppercased() + String(b).uppercased()
        }
        let word = words.first ?? name
        if let first = word.first, first.isLowercase, let capital = word.dropFirst().first(where: \.isUppercase) {
            return String(first) + String(capital)
        }
        let capitals = word.filter(\.isUppercase)
        if capitals.count >= 2 { return String(capitals.prefix(2)) }
        return String(word.prefix(2)).capitalized
    }
}

/// The indexer's tile: its colour with a lighter top, the monogram, and the
/// state dot at the corner (green fine, orange backing off, grey off).
struct V2IndexerTile: View {
    let name: String
    let color: Color
    let state: String
    var size: CGFloat = 40

    private var stateColor: Color {
        switch state {
        case "backoff": return Theme.stuck
        case "disabled": return Theme.dim
        default: return Theme.done
        }
    }

    var body: some View {
        Text(V2IndexerIdentity.monogram(name))
            .font(.system(size: size * 0.37, weight: .bold))
            .tracking(-0.4)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [color.mix(with: .white, by: 0.22), color], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(stateColor)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .background(Circle().fill(Theme.card).padding(-2.5))
                    .offset(x: 3, y: 3)
            }
            .accessibilityHidden(true)
    }
}

/// The USENET / TORRENT tag (mock `.ixv-pr`): a quiet outline.
struct V2IndexerProtocolTag: View {
    let isTorrent: Bool
    @Environment(\.pagePalette) private var page

    var body: some View {
        let ink = page?.inkMuted ?? Theme.mut
        Text(isTorrent ? "TORRENT" : "USENET")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(ink)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(ink.opacity(0.55)))
            .fixedSize()
    }
}
