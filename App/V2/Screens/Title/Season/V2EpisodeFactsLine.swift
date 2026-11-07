import SwiftUI
import FusionhaKit

/// One version's file on an episode row: its chips (only what differs from
/// the season, `SeasonFileFacts`) and its size.
struct V2EpisodeFactsPart: Identifiable, Hashable {
    let editionId: Int
    let tier: QualityTier
    let fileId: Int
    let line: FileFactsLine
    var id: Int { editionId }

    /// The episode's files in the season's versions, in version order.
    static func parts(_ episode: Episode, versions: [SeasonVersionFileFacts]) -> [V2EpisodeFactsPart] {
        versions.compactMap { version in
            guard let file = episode.file(for: version.editionId) else { return nil }
            return V2EpisodeFactsPart(editionId: version.editionId, tier: version.tier, fileId: file.id,
                                      line: version.facts.line(for: file))
        }
    }

    /// The row's size: every version's file together.
    static func size(_ parts: [V2EpisodeFactsPart]) -> String? {
        let bytes = parts.compactMap(\.line.bytes).reduce(0, +)
        return bytes > 0 ? DetailText.bytes(bytes) : nil
    }

    /// One sentence for VoiceOver: "2.4 GB, quality WEBRip 1080p, differs…".
    static func spoken(_ parts: [V2EpisodeFactsPart], labelsTiers: Bool) -> String {
        var sentence = size(parts).map { [$0] } ?? []
        for part in parts where !part.line.chips.isEmpty {
            let chips = FileFactsSpeech.line(part.line.chips, size: nil)
            sentence.append(labelsTiers ? "\(part.tier.badgeLetters): \(chips)" : chips)
        }
        return sentence.joined(separator: ", ")
    }
}

/// An episode row's badge line (owner option B, 2026-11-06): the HD/4K
/// ticket (`leading`), then the file's fact chips, wrapping under it at
/// large text; the size right-aligned in even-width digits so the season's
/// sizes form a column. Tapping the group chip opens Release groups, the
/// rest of the facts the file's sheet; without actions it is plain content.
struct V2EpisodeFactsLine<Leading: View>: View {
    let parts: [V2EpisodeFactsPart]
    /// A title with more than one version names each group of chips.
    var labelsTiers = false
    var onGroup: (() -> Void)?
    var onFile: ((V2EpisodeFactsPart) -> Void)?
    @ViewBuilder let leading: Leading
    @ScaledMetric(relativeTo: .caption2) private var scale: CGFloat = 1
    @Environment(\.badgeInk) private var inkOverride

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            FlowRow(spacing: 5, lineSpacing: 4) {
                leading
                ForEach(parts) { part in
                    if labelsTiers && !part.line.chips.isEmpty {
                        V2FactTierLabel(tier: part.tier).padding(.leading, 2)
                    }
                    ForEach(part.line.chips) { chip in
                        tappable(chip, part: part)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let size = V2EpisodeFactsPart.size(parts) {
                sizeLabel(size)
            }
        }
    }

    @ViewBuilder
    private func tappable(_ chip: FileFactChip, part: V2EpisodeFactsPart) -> some View {
        if chip.kind == .group, let onGroup {
            Button(action: onGroup) { V2FactChip(chip: chip) }
                .buttonStyle(.borderless)
        } else if let onFile {
            Button { onFile(part) } label: { V2FactChip(chip: chip) }
                .buttonStyle(.borderless)
        } else {
            V2FactChip(chip: chip)
        }
    }

    @ViewBuilder
    private func sizeLabel(_ size: String) -> some View {
        let text = Text(verbatim: size)
            .font(.system(size: 11 * scale, weight: .medium))
            .monospacedDigit()
            .foregroundStyle((inkOverride ?? .page).secondary)
            .lineLimit(1)
            .fixedSize()
            .frame(height: TicketMetrics.height * scale)
        if let onFile, let first = parts.first {
            Button { onFile(first) } label: { text }
                .buttonStyle(.borderless)
        } else {
            text
        }
    }
}
