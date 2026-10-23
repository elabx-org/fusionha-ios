import Foundation

// MARK: - Unified search: lanes, dedupe and merge (owner-approved 2026-10-23)
//
// One search over the library and every metadata provider. The owned lane is
// the app's own (instant, local); this file is the provider side: every
// provider's hits, deduped by `in_library` (a title you own shows as the
// library row, never as an add row) and by id, TMDB and TheTVDB rows for the
// same title merged into one row that keeps its sources.

/// A metadata provider the unified search asks.
public enum UnifiedSearchProvider: String, Sendable, CaseIterable, Hashable {
    case tmdb, tvdb

    /// The providers asked for a kind filter: TheTVDB is series-only, so
    /// Movies skips it.
    public static func asked(for kind: SearchKind) -> Set<UnifiedSearchProvider> {
        kind == .movie ? [.tmdb] : [.tmdb, .tvdb]
    }
}

/// The add lane's source menu (All sources / TMDB / TheTVDB).
public enum UnifiedSearchSourceFilter: String, Sendable, CaseIterable {
    case all, tmdb, tvdb

    public func includes(_ sources: Set<UnifiedSearchProvider>) -> Bool {
        switch self {
        case .all: return true
        case .tmdb: return sources.contains(.tmdb)
        case .tvdb: return sources.contains(.tvdb)
        }
    }
}

/// One "Available to add" row: a TMDB hit, a TheTVDB hit, or both merged.
public struct UnifiedAddHit: Identifiable, Hashable, Sendable {
    public var tmdb: MediaSearchResult?
    public var tvdb: TvdbSearchResult?

    public init(tmdb: MediaSearchResult? = nil, tvdb: TvdbSearchResult? = nil) {
        self.tmdb = tmdb
        self.tvdb = tvdb
    }

    public var id: String { tmdb.map { "tmdb-\($0.id)" } ?? "tvdb-\(tvdb?.tvdbId ?? 0)" }
    public var sources: Set<UnifiedSearchProvider> {
        var s = Set<UnifiedSearchProvider>()
        if tmdb != nil { s.insert(.tmdb) }
        if tvdb != nil { s.insert(.tvdb) }
        return s
    }
    /// Only TheTVDB knows it: the one row that carries a mark ("only").
    public var isTvdbOnly: Bool { tmdb == nil && tvdb != nil }
    public var title: String { tmdb?.title ?? tvdb?.title ?? "" }
    public var year: Int? { tmdb?.year ?? tvdb?.year }
    /// TheTVDB's search is series-only.
    public var kind: MediaKind { tmdb?.kind ?? .series }
    public var posterUrl: String? { tmdb?.posterUrl ?? tvdb?.imageUrl }
}

/// What the provider side of the unified search shows, as it stands.
public struct UnifiedSearchLanes: Equatable, Sendable {
    /// The id lookup's hit(s), pinned as "Exact match".
    public var exact: [MediaSearchResult] = []
    /// "Available to add", deduped and merged, in arrival order.
    public var add: [UnifiedAddHit] = []
    /// Provider hits you already own (they show in the library lane).
    public var ownedTmdb: [MediaSearchResult] = []
    /// TheTVDB hits you own, as library item ids.
    public var ownedLibraryIds: [Int] = []
    /// Providers asked for this term (Movies skips TheTVDB).
    public var asked: Set<UnifiedSearchProvider> = []
    /// Providers still answering.
    public var pending: Set<UnifiedSearchProvider> = []
    /// Providers with no API key (409 `*_not_configured`): silently skipped.
    public var unconfigured: Set<UnifiedSearchProvider> = []
    /// Providers that failed this time.
    public var failed: Set<UnifiedSearchProvider> = []

    public init() {}

    public var isSettled: Bool { pending.isEmpty }
    /// The providers that answered (for the lane label's marks).
    public var answered: [UnifiedSearchProvider] {
        UnifiedSearchProvider.allCases.filter {
            asked.contains($0) && !pending.contains($0) && !unconfigured.contains($0) && !failed.contains($0)
        }
    }
}

/// Builds `UnifiedSearchLanes` as each provider answers. Pure, so the client
/// fan-out and a later server `GET /search/unified` share the same rules.
public struct UnifiedSearchAccumulator: Sendable {
    public private(set) var tmdb: [MediaSearchResult] = []
    public private(set) var tvdb: [TvdbSearchResult] = []
    public private(set) var exact: [MediaSearchResult] = []
    public var pending: Set<UnifiedSearchProvider>
    public let asked: Set<UnifiedSearchProvider>
    public var unconfigured: Set<UnifiedSearchProvider> = []
    public var failed: Set<UnifiedSearchProvider> = []

    public init(pending: Set<UnifiedSearchProvider> = Set(UnifiedSearchProvider.allCases)) {
        self.pending = pending
        self.asked = pending
    }

    public mutating func receive(tmdb rows: [MediaSearchResult]) {
        tmdb = rows
        pending.remove(.tmdb)
    }

    public mutating func receive(tvdb rows: [TvdbSearchResult]) {
        tvdb = rows
        pending.remove(.tvdb)
    }

    public mutating func receive(exact rows: [MediaSearchResult]) {
        for row in rows where !exact.contains(where: { $0.id == row.id }) { exact.append(row) }
    }

    public mutating func unavailable(_ provider: UnifiedSearchProvider) {
        unconfigured.insert(provider)
        pending.remove(provider)
    }

    public mutating func fail(_ provider: UnifiedSearchProvider) {
        failed.insert(provider)
        pending.remove(provider)
    }

    public var lanes: UnifiedSearchLanes {
        var lanes = UnifiedSearchLanes()
        lanes.asked = asked
        lanes.pending = pending
        lanes.unconfigured = unconfigured
        lanes.failed = failed
        lanes.ownedTmdb = (tmdb + exact).filter(\.inLibrary).uniqued(by: \.id)
        lanes.ownedLibraryIds = tvdb.filter { $0.inLibrary == true }.compactMap(\.libraryItemId)
        lanes.exact = exact.filter { !$0.inLibrary }
        let pinned = Set(lanes.exact.map(\.id))
        lanes.add = Self.merge(tmdb: tmdb, tvdb: tvdb).filter { hit in
            !(hit.tmdb.map { pinned.contains($0.id) } ?? false)
        }
        return lanes
    }

    /// TMDB rows first (their order), then TheTVDB rows: one that matches a
    /// TMDB row joins it (by TheTVDB's `tmdb_id` on a series, else by
    /// normalised title + year); the rest are TheTVDB-only rows. Owned hits
    /// never reach the add lane.
    public static func merge(tmdb: [MediaSearchResult], tvdb: [TvdbSearchResult]) -> [UnifiedAddHit] {
        let ownedSeriesTmdb = Set(tmdb.filter { $0.inLibrary && $0.kind != .movie }.map(\.tmdbId))
        var hits = tmdb.filter { !$0.inLibrary }.uniqued(by: \.id).map { UnifiedAddHit(tmdb: $0) }
        var seenTvdb = Set<Int>()
        for row in tvdb where row.inLibrary != true && seenTvdb.insert(row.tvdbId).inserted {
            if let id = row.tmdbId, ownedSeriesTmdb.contains(id) { continue }
            if let i = matchIndex(row, in: hits) {
                if hits[i].tvdb == nil { hits[i].tvdb = row }
            } else {
                hits.append(UnifiedAddHit(tvdb: row))
            }
        }
        return hits
    }

    private static func matchIndex(_ row: TvdbSearchResult, in hits: [UnifiedAddHit]) -> Int? {
        if let id = row.tmdbId,
           let i = hits.firstIndex(where: { $0.tmdb?.tmdbId == id && $0.tmdb?.kind != .movie }) {
            return i
        }
        let key = normalizedTitle(row.title)
        return hits.firstIndex { hit in
            guard let t = hit.tmdb, t.kind != .movie, normalizedTitle(t.title) == key else { return false }
            guard let a = t.year, let b = row.year else { return true }
            return a == b
        }
    }

    /// Lowercased, accents and punctuation dropped, a leading "the" dropped:
    /// "The Office (US)" and "the office us" match.
    public static func normalizedTitle(_ title: String) -> String {
        let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        let words = folded.split { !($0.isLetter || $0.isNumber) }.map(String.init)
        let trimmed = words.first == "the" ? Array(words.dropFirst()) : words
        return trimmed.joined(separator: " ")
    }
}

fileprivate extension Array {
    func uniqued<Key: Hashable>(by key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}
