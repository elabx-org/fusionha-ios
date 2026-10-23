import SwiftUI
import FusionhaKit

/// The unified search's lanes for one term: "Exact match" (an id), "In your
/// library" (instant, capped at 8, "+N more in Library"), then "Available to
/// add · <marks>" filling in as each provider answers. No "Search to add" step.
struct SearchResults: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    let term: String
    let kind: SearchKind
    let search: UnifiedSearchModel
    @Binding var filter: UnifiedSearchSourceFilter
    let actions: SearchAddActions

    private var lanes: UnifiedSearchLanes { search.lanes }
    /// The lanes still show the previous term's answer while this one runs.
    private var stale: Bool { !search.isCurrent(term, kind) }
    private var canAdd: Bool { model.me.map { $0.hasCapability("add") } ?? !model.requestScoped }

    var body: some View {
        let owned = ownedRows
        let hits = addHits
        let exact = lanes.exact.filter(kind.matches)
        VStack(alignment: .leading, spacing: 0) {
            if !exact.isEmpty && !stale {
                SearchLaneLabel(text: "Exact match", count: exact.count)
                SearchLaneCard {
                    ForEach(Array(exact.enumerated()), id: \.element.id) { i, result in
                        SearchAddRow(hit: UnifiedAddHit(tmdb: result), actions: actions).searchStagger(i)
                    }
                }
                .transition(.searchRow(motion: motion))
            }
            if !model.requestScoped { ownedLane(owned) }
            addLane(hits)
        }
    }

    // MARK: In your library

    private var ownedRows: (rows: [MediaItem], total: Int) {
        guard !model.requestScoped else { return ([], 0) }
        let ids = stale ? [] : lanes.ownedTmdb.compactMap { model.libraryItemId(for: $0) } + lanes.ownedLibraryIds
        let items = kind.bucket.map { bucket in model.library.filter { $0.kindBucket == bucket } } ?? model.library
        return OwnedSearch.rows(items, term: term, providerOwned: ids)
    }

    @ViewBuilder
    private func ownedLane(_ owned: (rows: [MediaItem], total: Int)) -> some View {
        if owned.total > 0 {
            SearchLaneLabel(text: "In your library", count: owned.total)
            SearchLaneCard {
                ForEach(Array(owned.rows.enumerated()), id: \.element.id) { i, item in
                    SearchOwnedRow(item: item).searchStagger(i)
                }
            }
            if owned.total > owned.rows.count { moreInLibrary(owned.total - owned.rows.count) }
        } else {
            SearchLaneLabel(text: "In your library", count: nil)
            note(kind.noun.map { "No \($0) in your library for “\(term)”." } ?? "Nothing in your library for “\(term)”.")
        }
    }

    private func moreInLibrary(_ count: Int) -> some View {
        Button {
            model.searchText = term
            model.searchScope = .library
            model.tab = .library
        } label: {
            Text("+ \(count) more in Library")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.i2)
                .padding(.horizontal, Theme.pageGutter + 2)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Available to add

    private var addHits: [UnifiedAddHit] {
        var hits = lanes.add
        // A requester can still ask for a title the server has (another version).
        if model.requestScoped { hits += lanes.ownedTmdb.filter(kind.matches).map { UnifiedAddHit(tmdb: $0) } }
        if !canAdd { hits.removeAll(where: \.isTvdbOnly) }
        return hits.filter { filter.includes($0.sources) }
    }

    @ViewBuilder
    private func addLane(_ hits: [UnifiedAddHit]) -> some View {
        SearchLaneLabel(text: model.requestScoped ? "Available to request" : "Available to add",
                        count: hits.isEmpty ? nil : hits.count) {
            SearchSourceMenu(filter: $filter, available: lanes.answered)
        }
        if !hits.isEmpty {
            SearchLaneCard {
                ForEach(Array(hits.enumerated()), id: \.element.id) { i, hit in
                    SearchAddRow(hit: hit, actions: actions).searchStagger(i)
                }
            }
            .opacity(stale ? 0.55 : 1)
        }
        if search.searching || stale {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(Theme.mut)
                Text(searchingText).font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            .padding(.horizontal, Theme.pageGutter + 2)
            .padding(.vertical, 12)
            .transition(.opacity)
        } else if hits.isEmpty {
            note(emptyText)
        }
    }

    private var searchingText: String {
        let names = lanes.pending.isEmpty || stale ? ["TMDB", "TheTVDB"]
            : UnifiedSearchProvider.allCases.filter { lanes.pending.contains($0) }.map { $0 == .tmdb ? "TMDB" : "TheTVDB" }
        return "Searching \(names.joined(separator: " and "))…"
    }

    private var emptyText: String {
        if lanes.unconfigured.contains(.tmdb) && filter != .tvdb && !lanes.answered.contains(.tvdb) {
            return "Adding needs a TMDB key — add one in Settings › Metadata."
        }
        if filter == .tvdb && lanes.unconfigured.contains(.tvdb) {
            return "TheTVDB needs a key — add one in Settings › Metadata."
        }
        if !lanes.failed.isEmpty && lanes.answered.isEmpty {
            return "Couldn't reach the metadata provider — try again."
        }
        return "Nothing to \(model.requestScoped ? "request" : "add") for “\(term)”."
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.mut)
            .padding(.horizontal, Theme.pageGutter + 2)
            .padding(.vertical, 8)
    }
}
