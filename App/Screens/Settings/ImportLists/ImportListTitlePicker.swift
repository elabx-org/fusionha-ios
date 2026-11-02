import SwiftUI
import FusionhaKit

/// Search TMDB and pick one title (web `TitlePicker`): the same search and
/// candidate rows as "Pick the right title" on the Account lists. Used by
/// the exclusion add sheet and the unmatched review. Debounced 300 ms.
struct ImportListTitlePicker: View {
    @Environment(AppModel.self) private var model
    let label: String
    var placeholder = "Search TMDB"
    @Binding var term: String
    @Binding var picked: MediaSearchResult?
    @State private var results: [MediaSearchResult] = []
    @State private var searching = false
    @State private var failed = false

    var body: some View {
        Section {
            TextField(placeholder, text: $term)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(label)
            if let empty {
                Text(empty).font(.footnote).foregroundStyle(Theme.mut)
            }
            ForEach(results) { result in
                PickCandidateRow(result: result, picked: picked == result) { picked = result }
            }
        } header: {
            Text(label)
        }
        .task(id: term) { await search() }
    }

    private var empty: String? {
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if failed { return "Couldn’t search just now. Try again." }
        if results.isEmpty { return searching ? "Searching…" : "No titles found." }
        return nil
    }

    private func search() async {
        let text = term.trimmingCharacters(in: .whitespaces)
        guard let client = model.client, !text.isEmpty else {
            results = []
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        searching = true
        defer { searching = false }
        do {
            results = Array(try await client.search(term: text, kind: .all).prefix(8))
            failed = false
            if let picked, !results.contains(picked) { self.picked = nil }
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            failed = true
        }
    }
}
