import SwiftUI
import FusionhaKit

/// Match to library item (web `ItemMatchDialog`): search the library and
/// attach this file, or every file of a title (Re-match), to another title
/// (an `item_id` override per row).
struct MIItemMatchSheet: View {
    let rows: [ManualImportRow]
    private var row: ManualImportRow { rows[0] }
    @Environment(AppModel.self) private var model
    @Environment(ManualImportSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""

    init(row: ManualImportRow) { rows = [row] }
    init(rows: [ManualImportRow]) { self.rows = rows }

    private var matches: [MediaItem] {
        let q = term.trimmingCharacters(in: .whitespaces).lowercased()
        let items = q.isEmpty ? model.library : model.library.filter { $0.title.lowercased().contains(q) }
        return Array(items.prefix(40))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(matches) { item in
                        Button {
                            Task {
                                for r in rows where !r.committed { await session.patch(r, ["item_id": .int(item.id)]) }
                                if item.kind == .series { await session.loadSeasons(itemId: item.id) }
                                dismiss()
                            }
                        } label: { option(item) }
                    }
                } header: {
                    Text("Parsed as \(row.parsed.title ?? row.filename)\(row.parsed.year.map { " (\($0))" } ?? "")").textCase(nil)
                } footer: {
                    if matches.isEmpty {
                        Text(model.libraryLoaded ? "No library title matches “\(term)”. Add the title first, then scan again." : "Loading your library…")
                    }
                }
            }
            .searchable(text: $term, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search your library")
            .navigationTitle("Match to a library title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } } }
            .closeOnlyBars()
        }
        .task { if !model.libraryLoaded { await model.loadLibrary() } }
    }

    private func option(_ item: MediaItem) -> some View {
        HStack(spacing: 12) {
            ActPoster(url: item.posterUrl, title: item.title, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.txt)
                Text([item.year.map(String.init), item.isAnime == true ? "Anime" : item.kind == .series ? "Series" : "Movie"]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 0)
            if item.id == row.match.itemId { Image(systemName: "checkmark").foregroundStyle(Theme.i1) }
        }
        .contentShape(Rectangle())
    }
}
