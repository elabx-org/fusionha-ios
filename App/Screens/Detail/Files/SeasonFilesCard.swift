import SwiftUI
import FusionhaKit

/// One season × version card of the Files tab: the header folds it, the rows
/// are the season's episode files in order, missing episodes in their place.
struct SeasonFilesCard: View {
    @Environment(DetailStore.self) private var store
    let section: SeasonFilesSection
    @Binding var collapsed: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if !collapsed {
                ForEach(section.rows) { row in
                    Rectangle().fill(Theme.line).frame(height: 1).padding(.leading, 16)
                    rowView(row)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .detailCard()
        .detailAnimation(.easeInOut(duration: 0.2), value: collapsed)
    }

    private var header: some View {
        Button { collapsed.toggle() } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
                    .foregroundStyle(Theme.mut)
                    .frame(height: 20)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(section.season.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.txt)
                        DetailTierChip(tier: section.edition.tier, label: section.edition.label)
                        Spacer(minLength: 4)
                        Text(DetailText.bytes(section.bytes))
                            .font(.system(size: 12.5, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.mut)
                            .lineLimit(1)
                    }
                    summary
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(collapsed ? "Shows the files" : "Hides the files")
    }

    /// `26 of 26 episodes · 25 files`; a `2 missing` tail in the missing colour.
    private var summary: some View {
        let text = section.summary
        let split = text.range(of: " · ", options: .backwards)
        let label: Text
        if let split, text.hasSuffix(" missing") {
            let head = String(text[..<split.lowerBound])
            let tail = String(text[split.upperBound...])
            label = Text("\(head) · \(Text(tail).foregroundStyle(EditionStatus.missing.color))")
        } else {
            label = Text(text)
        }
        return label
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
    }

    @ViewBuilder
    private func rowView(_ row: SeasonFileRow) -> some View {
        if let file = row.file {
            Button {
                store.fileSheet = EpisodeFileTarget(fileId: file.id, editionId: section.edition.id,
                                                    seasonNumber: section.season.seasonNumber)
            } label: {
                EpisodeFileRow(row: row, file: file, tier: section.edition.tier)
            }
            .buttonStyle(.plain)
        } else if let episode = row.episodes.first {
            Button {
                store.episodeSheet = EpisodeSheetTarget(episodeId: episode.id, seasonNumber: section.season.seasonNumber)
            } label: {
                MissingEpisodeRow(row: row)
            }
            .buttonStyle(.plain)
        }
    }
}
