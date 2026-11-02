import SwiftUI
import FusionhaKit

// The series Files tab (FilesSections), read by episode (owner-approved
// option 1): one collapsible card per season × version, one row per episode
// file in episode order, missing episodes in their place, and a tap opens the
// file sheet. Deviates from the web's filename list; see docs/ui-plan.md.

/// One season × version card's data, built once per render of the tab.
struct SeasonFilesSection: Identifiable {
    let season: Season
    let edition: DetailEdition
    let rows: [SeasonFileRow]
    let fileCount: Int
    let bytes: Double
    var id: String { "\(season.seasonNumber)-\(edition.id)" }

    var summary: String { season.fileSummary(editionId: edition.id, fileCount: fileCount) }
}

struct SeriesFilesTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail
    @State private var collapsed: Set<String> = []

    /// Each version keeps its own cards (each tier lives in its own root
    /// folder); a card appears once the version has a file in that season.
    private var sections: [SeasonFilesSection] {
        var out: [SeasonFilesSection] = []
        for season in detail.seasonsAscending {
            for edition in store.scopedEditions {
                let rows = season.fileRows(editionId: edition.id)
                let files = rows.compactMap(\.file)
                guard !files.isEmpty else { continue }
                out.append(SeasonFilesSection(season: season, edition: edition, rows: rows, fileCount: files.count,
                                              bytes: files.compactMap(\.size).reduce(0, +)))
            }
        }
        return out
    }

    var body: some View {
        let sections = sections
        // Each version's first card is the hero strip's scroll target.
        let leads = Set(Dictionary(grouping: sections, by: \.edition.id).compactMap { $0.value.first?.id })
        VStack(alignment: .leading, spacing: 12) {
            if (model.me?.can("edit") ?? true) && !sections.isEmpty {
                HStack {
                    Spacer()
                    DetailRenameFilesButton { store.openRename() }
                }
            }
            if sections.isEmpty {
                EmptyBox(message: "No files imported yet.")
            }
            ForEach(sections) { section in
                SeasonFilesCard(section: section, collapsed: collapsedBinding(section.id))
                    .versionHighlight(section.edition, anchor: "file-\(section.edition.id)")
                    .id(leads.contains(section.id) ? "file-\(section.edition.id)" : "section-\(section.id)")
            }
        }
    }

    private func collapsedBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { collapsed.contains(id) },
            set: { isCollapsed in
                if isCollapsed { collapsed.insert(id) } else { collapsed.remove(id) }
            }
        )
    }
}
