import SwiftUI
import FusionhaKit

/// v2's Files tab for a series (mock browse-title.js `seriesFiles`, the
/// owner's option 1 by episode): HD | 4K (the page scope, so the version
/// cards land here on their version) and Rename files, then per season a
/// header on the ground ("6 of 8 episodes · 1 missing · 26.9 GB") over one
/// W1 card of episode rows. A file row opens v1's file sheet (facts, path,
/// Copy, Delete); a missing or unaired episode pushes its page.
struct V2SeriesFilesTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail

    private var versions: [DetailEdition] { detail.orderedEditions }
    private var version: DetailEdition? { store.v2ShownVersion ?? versions.first }

    var body: some View {
        let sections = version.map { buildSections(for: $0) } ?? []
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if versions.count > 1 { V2EpisodeVersionPicker(editions: versions, selection: selection) }
                Spacer(minLength: 8)
                if (model.me?.can("edit") ?? true) && sections.contains(where: { $0.fileCount > 0 }) {
                    V2RenameFilesButton()
                }
            }
            .v2FadesUnderTitleBar()
            if sections.isEmpty {
                Text("No files imported yet for this version.")
                    .font(.system(size: 14))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .v2CardStyle(padding: 14, radius: 20)
            }
            ForEach(sections) { section in
                V2SeasonFilesBlock(section: section)
            }
        }
    }

    private var selection: Binding<Int> {
        Binding(get: { version?.id ?? 0 }, set: { id in
            guard let edition = versions.first(where: { $0.id == id }) else { return }
            store.scope = DetailScope(tier: edition.tier.rawValue, version: edition.versionKey)
        })
    }

    /// Seasons with a file or a missing aired episode in this version. A
    /// monitored episode still to air keeps its place too, dimmed with its
    /// air date (mock "E08 Forever · Airs Tue 10 Nov"), so the rows match
    /// the header's "6 of 8 episodes".
    private func buildSections(for edition: DetailEdition) -> [SeasonFilesSection] {
        detail.seasonsAscending.compactMap { season in
            let owned = season.fileRows(editionId: edition.id)
            guard !owned.isEmpty else { return nil }
            let files = owned.compactMap(\.file)
            let rows = owned + Self.unairedRows(season, editionId: edition.id)
            let ordered = rows.sorted { ($0.episodes.first?.episodeNumber ?? 0) < ($1.episodes.first?.episodeNumber ?? 0) }
            return SeasonFilesSection(season: season, edition: edition, rows: ordered, fileCount: files.count,
                                      bytes: files.compactMap(\.size).reduce(0, +))
        }
    }

    /// Monitored, fileless episodes still to air, one row each.
    private static func unairedRows(_ season: Season, editionId: Int) -> [SeasonFileRow] {
        guard season.monitored != false else { return [] }
        return season.episodes
            .filter { ep in
                ep.monitored != false && ep.file(for: editionId) == nil && ep.status(editionId: editionId) == .soon
            }
            .map { SeasonFileRow(file: nil, episodes: [$0]) }
    }
}

/// Rename files as a glass pill (mock `btn('Rename files', {icon: 'doc'})`).
struct V2RenameFilesButton: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page

    var body: some View {
        Button("Rename files", systemImage: "doc.text") { store.openRename() }
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundStyle(page?.ink ?? Theme.txt)
            .buttonStyle(.glass)
    }
}

/// One season of one version: the header on the ground, the rows in a card.
struct V2SeasonFilesBlock: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    let section: SeasonFilesSection

    private var summary: String {
        let cover = section.season.cover(editionId: section.edition.id)
        var parts = ["\(cover.owned) of \(cover.total) episode\(cover.total == 1 ? "" : "s")"]
        if cover.wanted > 0 { parts.append("\(cover.wanted) missing") }
        if section.bytes > 0 { parts.append(DetailText.bytes(section.bytes)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.season.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(page?.ink ?? Theme.txt)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(summary)
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
            }
            VStack(spacing: 0) {
                ForEach(section.rows) { row in
                    if row.id != section.rows.first?.id {
                        Rectangle()
                            .fill((page?.ink ?? Theme.txt).opacity(0.1))
                            .frame(height: 0.5)
                            .padding(.leading, 14)
                    }
                    rowButton(row)
                }
            }
            .background { ModuleSurface(radius: 20) }
        }
    }

    private func rowButton(_ row: SeasonFileRow) -> some View {
        Button {
            if let file = row.file {
                store.fileSheet = EpisodeFileTarget(fileId: file.id, editionId: section.edition.id,
                                                    seasonNumber: section.season.seasonNumber)
            } else if let episode = row.episodes.first {
                store.episodeSheet = EpisodeSheetTarget(episodeId: episode.id, seasonNumber: section.season.seasonNumber)
            }
        } label: {
            V2EpisodeFileLine(row: row, tier: section.edition.tier)
        }
        .buttonStyle(.plain)
    }
}
