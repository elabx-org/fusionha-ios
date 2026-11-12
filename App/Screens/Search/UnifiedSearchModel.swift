import SwiftUI
import FusionhaKit

/// The unified search's provider side (owner-approved 2026-10-23): the add lane
/// runs as you type, ~300 ms after the last keystroke, through a
/// `UnifiedSearchSource` (the server's `/search/unified` for the library and
/// TMDB, beside TheTVDB and the id lookup). Each provider's rows land as it
/// answers; a new term or kind cancels the calls still in flight. TMDB always
/// runs (`tmdb=always`): the approved spec has no "Search to add" step. The owned lane stays local and instant (`OwnedSearch`), with
/// the server's library rows until the library has loaded. Before you type:
/// Trending this week, per kind.
@MainActor
@Observable
final class UnifiedSearchModel {
    /// The provider side for `key`.
    private(set) var lanes = UnifiedSearchLanes()
    /// The kind and term `lanes` belong to ("" before the first answer).
    private(set) var key = ""

    /// Trending this week per kind (the Add sheet's feed), kept while the tab lives.
    private(set) var trending: [SearchKind: [MediaSearchResult]] = [:]
    private(set) var trendingFailed = false
    /// 409 `tmdb_not_configured`: the KeyMissing notice instead of Trending.
    private(set) var trendingMissingKey = false
    /// Kinds whose feed is the popular list, not Trending: the server's
    /// trending list comes back empty for anime (fusionha, 2026-11-12), so
    /// Anime shows `/discover/filter` by popularity instead of nothing.
    private(set) var popularInstead: Set<SearchKind> = []

    var searching: Bool { !lanes.isSettled }

    static func key(_ term: String, _ kind: SearchKind) -> String { "\(kind.rawValue)|\(term)" }

    /// Runs one term to completion (call from `.task(id:)`; cancelling the
    /// task cancels the provider calls).
    func run(_ term: String, kind: SearchKind, source: (any UnifiedSearchSource)?, motion: Bool) async {
        guard !term.isEmpty, let source else {
            lanes = UnifiedSearchLanes()
            key = ""
            return
        }
        // Debounce typing.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        var first = true
        for await next in source.lanes(for: term, kind: kind) {
            guard !Task.isCancelled else { return }
            withAnimation(motion ? .spring(duration: 0.35, bounce: 0) : .easeInOut(duration: 0.2)) {
                if first {
                    key = Self.key(term, kind)
                    first = false
                }
                lanes = next
            }
        }
    }

    /// Answers for this term and kind (stale lanes for an older one are dimmed).
    func isCurrent(_ term: String, _ kind: SearchKind) -> Bool { key == Self.key(term, kind) }

    func loadTrending(_ kind: SearchKind, client: APIClient?) async {
        guard trending[kind] == nil, let client else { return }
        do {
            var rows = try await client.discover(kind: kind, list: .trending)
            if rows.isEmpty, kind != .all,
               let popular = try? await client.discoverFilter(kind: kind, filter: DiscoverFilter()), !popular.isEmpty {
                rows = popular
                popularInstead.insert(kind)
            }
            trending[kind] = rows
            trendingFailed = false
            trendingMissingKey = false
        } catch {
            if Task.isCancelled { return }
            trendingMissingKey = AddTitleSheet.missingKey(error, "tmdb_not_configured")
            trendingFailed = true
        }
    }
}
