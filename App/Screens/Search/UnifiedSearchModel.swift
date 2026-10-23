import SwiftUI
import FusionhaKit

/// The unified search's provider side (owner-approved 2026-10-23): the add lane
/// runs as you type, ~300 ms after the last keystroke, through a
/// `UnifiedSearchSource` (today the client fan-out over TMDB, TheTVDB and the id
/// lookup). Each provider's rows land as it answers; a new term or kind cancels
/// the calls still in flight. The owned lane stays local and instant
/// (`OwnedSearch`). Before you type: Trending this week, per kind.
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
            let rows = try await client.discover(kind: kind, list: .trending)
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
