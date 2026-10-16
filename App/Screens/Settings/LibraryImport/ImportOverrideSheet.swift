import SwiftUI
import FusionhaKit

/// Override match (web `OverrideDialog`): search TMDB for the folder whose
/// match is wrong or missing. Picking a result repoints the folder (kept
/// across rescans) and accepts the row.
struct ImportOverrideSheet: View {
    let model: ImportWorkspaceModel
    let itemId: String
    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var results: [MediaSearchResult] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var picking: Int?

    private var item: LibraryImportItem? { model.item(itemId) }
    private var trimmed: String { term.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    content
                } header: {
                    if let item {
                        Text("Pick the correct TMDB title for \(item.title)").textCase(nil)
                    }
                }
                .listRowBackground(Theme.card)
                if let error = model.actionError {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Theme.danger)
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .searchable(text: $term, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search TMDB…")
            .navigationTitle("Override match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { SheetCancelButton { dismiss() } }
            }
            .task(id: trimmed) { await search() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if trimmed.isEmpty {
            note("Start typing to search TMDB.")
        } else if searching && results.isEmpty {
            note("Searching…")
        } else if let searchError {
            note(searchError)
        } else if results.isEmpty {
            note("No matches for “\(trimmed)”.")
        } else {
            ForEach(results) { r in
                Button { pick(r) } label: { resultRow(r) }
                    .buttonStyle(.plain)
                    .disabled(picking != nil)
            }
        }
    }

    private func resultRow(_ r: MediaSearchResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(r.title) (\(r.year.map(String.init) ?? "—"))")
                    .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(Theme.txt)
                Text((r.isAnime ? "Anime · " : "") + (r.kind == .movie ? "Movie" : "Series"))
                    .font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 6)
            if picking == r.tmdbId { ProgressView().controlSize(.small) }
        }
        .contentShape(Rectangle())
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(Theme.mut)
    }

    private func search() async {
        guard !trimmed.isEmpty, let client = model.client, let item else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        searching = true
        defer { searching = false }
        do {
            let kind: SearchKind = item.kind == .series ? .series : .movie
            let found = try await client.search(term: trimmed, kind: kind)
            guard !Task.isCancelled else { return }
            results = found
            searchError = nil
        } catch {
            if !Task.isCancelled { searchError = ErrorCopy.message(for: error, fallback: "Couldn’t search TMDB.") }
        }
    }

    private func pick(_ r: MediaSearchResult) {
        picking = r.tmdbId
        Task {
            let ok = await model.override(itemId, tmdbId: r.tmdbId)
            picking = nil
            if ok { dismiss() }
        }
    }
}
