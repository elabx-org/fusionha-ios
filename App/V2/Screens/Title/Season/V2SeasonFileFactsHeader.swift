import SwiftUI
import FusionhaKit

/// Under the season page's "13 of 13 on disk" (owner option B, 2026-11-06):
/// the facts every file in the season shares, said once as chips, then
/// "· 32.4 GB" for the season's files. One line per version that has
/// files, named by its tier when the title has more than one. Rows then
/// show only what differs. Content on the ground, centred like the bar.
struct V2SeasonFileFactsHeader: View {
    let versions: [SeasonVersionFileFacts]
    @Environment(\.pagePalette) private var page

    private var labelsTiers: Bool { versions.count > 1 }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(versions) { version in
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 5) { items(version) }
                    FlowRow(spacing: 5, lineSpacing: 4) { items(version) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder
    private func items(_ version: SeasonVersionFileFacts) -> some View {
        if labelsTiers { V2FactTierLabel(tier: version.tier) }
        ForEach(version.facts.shared) { V2FactChip(chip: $0) }
        if let size = version.facts.totalSize {
            Text(verbatim: version.facts.shared.isEmpty ? size : "· \(size)")
                .font(.system(size: 12.5))
                .monospacedDigit()
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var spoken: String {
        versions.map { version in
            var parts: [String] = []
            if !version.facts.shared.isEmpty {
                parts.append("Across the season: " + FileFactsSpeech.line(version.facts.shared, size: nil))
            }
            if let size = version.facts.totalSize { parts.append("\(size) on disk") }
            let line = parts.joined(separator: ", ")
            return labelsTiers ? "\(version.tier.badgeLetters): \(line)" : line
        }
        .joined(separator: ". ")
    }
}
