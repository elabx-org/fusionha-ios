import SwiftUI
import FusionhaKit

/// Search with an empty term (from the web's Add item search): the kind
/// filter, recent searches as chips, then "Trending this week · TMDB" as a
/// poster grid (3 across; 3 a page while a Spread spans both pages, the kind
/// filter on the right page). Each poster has + Add on the art (person
/// Request for a requester); a title you own is the Library's poster card
/// (S2: art glow, status chips) and opens.
struct SearchBeforeTyping: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    @Environment(\.browseLook) private var look
    let kind: SearchKind
    let search: UnifiedSearchModel
    let recent: [String]
    let run: (String) -> Void
    let forget: (String) -> Void

    private var canAdd: Bool { model.me.map { $0.hasCapability("add") } ?? !model.requestScoped }
    private var canRequest: Bool { model.me?.hasCapability("request") == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // v1's Spread: chips on the left page, the kind filter on the right.
            // v2 keeps the typed results' order on every width (owner, build
            // 1162: the chips ran into the filter and the filter into the
            // column): the filter at the leading edge, the chips under it.
            if spread.spans && look == nil {
                // The leading slot always exists (even with no recent searches), so
                // the kind filter stays on the right page.
                FoldSpanRow {
                    ZStack(alignment: .leading) {
                        Color.clear.frame(height: 1)
                        chips
                    }
                    // The chips scroll within their half: unclipped they ran
                    // under the kind filter on the flat open Duo.
                    .clipShape(Rectangle().inset(by: -4))
                } trailing: {
                    SearchKindPicker()
                }
                    .padding(.horizontal, Theme.pageGutter)
            } else {
                SearchKindPicker().frame(maxWidth: 520, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.pageGutter)
                chips.padding(.horizontal, Theme.pageGutter).padding(.top, 12)
            }
            trending
        }
        .task(id: kind) { await search.loadTrending(kind, client: model.client) }
    }

    @ViewBuilder
    private var chips: some View {
        if !recent.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(recent, id: \.self) { term in
                        RecentSearchChip(term: term) { run(term) } forget: { forget(term) }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    /// Trending rows you own, as their library items (requesters see none).
    private func ownedItems(_ rows: [MediaSearchResult]) -> [String: MediaItem] {
        guard !model.requestScoped else { return [:] }
        let byId = Dictionary(model.library.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var owned: [String: MediaItem] = [:]
        for row in rows where row.inLibrary || row.libraryItemId != nil {
            if let id = model.libraryItemId(for: row), let item = byId[id] { owned[row.id] = item }
        }
        return owned
    }

    @ViewBuilder
    private var trending: some View {
        SearchLaneLabel(text: "Trending this week", count: nil) {
            HStack(spacing: 4) {
                Text("·").foregroundStyle(Theme.dim)
                TmdbLogo(size: 9, label: "TMDB")
            }
        }
        if let rows = search.trending[kind] {
            let owned = ownedItems(rows)
            AdaptivePosterGrid {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, result in
                    Group {
                        // A title you own is the Library's own card (glow, status chips).
                        if let item = owned[result.id] {
                            PosterCard(item: item)
                        } else {
                            DiscoverCard(result: result, canAdd: canAdd, canRequest: canRequest)
                        }
                    }
                    .searchStagger(i)
                }
            }
            .padding(.horizontal, Theme.pageGutter)
        } else if search.trendingMissingKey {
            MetadataKeyNotice(provider: "tmdb", feature: "Trending")
                .padding(.horizontal, Theme.pageGutter)
        } else if search.trendingFailed {
            Text("Couldn't load Trending — try again.")
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
                .padding(.horizontal, Theme.pageGutter + 2)
        } else {
            ProgressView().controlSize(.small).tint(Theme.mut)
                .frame(maxWidth: .infinity, minHeight: 160)
        }
    }
}

/// A recent search: a small glass chip that runs it again (hold to forget it).
struct RecentSearchChip: View {
    let term: String
    let run: () -> Void
    let forget: () -> Void

    var body: some View {
        Button(action: run) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold))
                Text(term).font(.system(size: 13, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(Theme.txt)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassControl()
        .contextMenu {
            Button("Remove from recent searches", systemImage: "trash", role: .destructive, action: forget)
        }
        .accessibilityHint("Searches again")
    }
}
