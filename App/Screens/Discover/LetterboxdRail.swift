import SwiftUI
import FusionhaKit

/// Discover › Browse "From your Letterboxd" (web `SuggestionsRail`): titles
/// from the viewer's Letterboxd watchlist and linked lists that aren't in the
/// library or requested yet, with a chip per source. Shown only when the
/// server has items for this viewer, so Discover never shifts for anyone else.
struct LetterboxdRail: View {
    @Environment(AppModel.self) private var model
    let canAdd: Bool
    let canRequest: Bool
    @State private var base: SuggestionsRead?
    @State private var filtered: SuggestionsRead?
    @State private var sourceId: Int?

    private var items: [Suggestion] { (sourceId == nil ? base : filtered)?.items ?? [] }

    var body: some View {
        if let base, base.visible, !base.items.isEmpty {
            RailSection(title: "From your Letterboxd", count: count) {
                Image(systemName: "film.stack").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.mut)
            } toggle: {
                if base.sources.count > 1 {
                    DiscoverSegmented(options: chips(base), selection: $sourceId)
                }
            } track: {
                VStack(alignment: .leading, spacing: 0) {
                    posters
                    footer(base)
                }
            }
            .task(id: sourceId) { await loadFiltered() }
        } else {
            Color.clear.frame(height: 0)
                .task { await loadBase() }
        }
    }

    @ViewBuilder
    private var posters: some View {
        if items.isEmpty {
            RailStateLine(text: sourceId == nil ? "No titles right now." : "Loading…")
        } else {
            RailTrack {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DiscoverCard(result: item.searchResult, canAdd: canAdd, canRequest: canRequest)
                        .frame(width: 116)
                        .discoverReveal(index: index)
                }
            }
        }
    }

    private var count: String? {
        items.count == 1 ? "1 title" : "\(items.count) titles"
    }

    private func chips(_ read: SuggestionsRead) -> [(Int?, String)] {
        var options: [(Int?, String)] = [(nil, "All \(read.items.count)")]
        for source in read.sources {
            options.append((source.sourceId, "\(source.label) \(source.count)"))
        }
        return options
    }

    private func footer(_ read: SuggestionsRead) -> some View {
        let stale = Set(read.items.filter(\.stale).compactMap(\.sourceId)).count
        var hint = "Titles from your watchlist and linked lists that aren’t in the library yet."
        if stale == 1 {
            hint += " 1 source couldn’t be checked and shows its last good check."
        } else if stale > 1 {
            hint += " \(stale) sources couldn’t be checked and show their last good check."
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(hint).font(.system(size: 12)).foregroundStyle(Theme.dim)
            Button("Manage Letterboxd") { model.showingWatchlists = true }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.i2)
        }
    }

    private func loadBase() async {
        guard let client = model.client else { return }
        if let kept = await client.cached({ try await $0.suggestions() }) { base = kept }
        if let fresh = try? await client.suggestions() { base = fresh }
    }

    private func loadFiltered() async {
        guard let sourceId, let client = model.client else {
            filtered = nil
            return
        }
        filtered = nil
        filtered = try? await client.suggestions(sourceId: sourceId)
    }
}
