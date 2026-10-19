import SwiftUI
import UIKit
import FusionhaKit

/// The "HD·4K" combo pill: only the tiers present, HD purple, 4K cyan.
struct TierComboLabel: View {
    let tiers: [QualityTier]

    var body: some View {
        let hasHD = tiers.contains(.hd) || tiers.isEmpty
        let has4K = tiers.contains(.uhd)
        HStack(spacing: 2) {
            if hasHD { Text("HD").foregroundStyle(Theme.edition) }
            if hasHD && has4K { Text("·").foregroundStyle(Theme.mut) }
            if has4K { Text("4K").foregroundStyle(Theme.grab) }
        }
        .font(.system(size: 11, weight: .bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Theme.panel2, in: Capsule())
    }
}

// MARK: - Shared rows kept for other screens

struct LibraryResultRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    if let year = item.year { Text(String(year)) }
                    if item.isAnime == true { AnimeChip() } else { KindGlyph(kind: item.kind) }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                TierComboLabel(tiers: item.editions.map(\.tier))
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

extension Bundle {
    var appVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}

