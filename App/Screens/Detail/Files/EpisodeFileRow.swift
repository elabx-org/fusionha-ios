import SwiftUI
import FusionhaKit

/// One episode file: `E01`, the title, and a facts line (quality, video,
/// audio, group) under it; the size trails. A dead link turns the facts line
/// to the stuck colour; a file below its version's tier tints its quality.
struct EpisodeFileRow: View {
    let row: SeasonFileRow
    let file: MovieFile
    let tier: QualityTier

    var body: some View {
        let facts = EpisodeFileFacts(file: file, tier: tier)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            EpisodeNumberLabel(text: row.label)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.txt)
                    .lineLimit(1)
                    .truncationMode(.tail)
                factsLine(facts)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                DetailAnalysisBadge(file: file)
                Text(facts.size)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.mut)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the file's details")
    }

    private func factsLine(_ facts: EpisodeFileFacts) -> Text {
        if facts.deadLink {
            let parts: [String?] = ["Dead link", facts.quality, facts.rest.isEmpty ? nil : facts.rest]
            return Text(parts.compactMap { $0 }.joined(separator: " · ")).foregroundStyle(Theme.stuck)
        }
        let rest = facts.rest
        guard let quality = facts.quality else {
            return Text(rest.isEmpty ? "No media facts yet" : rest).foregroundStyle(Theme.mut)
        }
        let qualityText = Text(quality).foregroundStyle(facts.belowTier ? EditionStatus.upgrading.color : Theme.mut)
        if rest.isEmpty { return qualityText }
        return Text("\(qualityText)\(Text(" · " + rest).foregroundStyle(Theme.mut))")
    }
}

/// A monitored, aired episode with no file in this version: it keeps its
/// place, dimmed, with "Missing" in the missing colour. A tap opens the
/// episode sheet, where it can be searched.
struct MissingEpisodeRow: View {
    let row: SeasonFileRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            EpisodeNumberLabel(text: row.label)
            Text(row.title)
                .font(.system(size: 14))
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Missing")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EditionStatus.missing.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the episode")
    }
}

/// The leading `E01` / `E25–26`, mono and muted.
struct EpisodeNumberLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.dim)
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 30, alignment: .leading)
    }
}
