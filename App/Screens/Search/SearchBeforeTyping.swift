import SwiftUI
import FusionhaKit

/// Search with an empty term (from the web's Add item search): the kind
/// filter, recent searches as chips, then "Trending this week · TMDB" as a
/// poster grid (3 across; 3 a page while a Spread spans both pages, the kind
/// filter on the right page). Each poster has + Add on the art (person
/// Request for a requester); a title you own opens.
struct SearchBeforeTyping: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    let kind: SearchKind
    let search: UnifiedSearchModel
    let recent: [String]
    let run: (String) -> Void
    let forget: (String) -> Void

    private var canAdd: Bool { model.me.map { $0.hasCapability("add") } ?? !model.requestScoped }
    private var canRequest: Bool { model.me?.hasCapability("request") == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if spread.spans {
                FoldSpanRow { chips } trailing: { SearchKindPicker() }
                    .padding(.horizontal, Theme.pageGutter)
            } else {
                SearchKindPicker().padding(.horizontal, Theme.pageGutter)
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

    @ViewBuilder
    private var trending: some View {
        SearchLaneLabel(text: "Trending this week", count: nil) {
            HStack(spacing: 4) {
                Text("·").foregroundStyle(Theme.dim)
                TmdbLogo(size: 9, label: "TMDB")
            }
        }
        if let rows = search.trending[kind] {
            AdaptivePosterGrid {
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, result in
                    DiscoverCard(result: result, canAdd: canAdd, canRequest: canRequest).searchStagger(i)
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
