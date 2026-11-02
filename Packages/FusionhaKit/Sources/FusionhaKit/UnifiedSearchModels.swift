import Foundation

// MARK: - GET /api/v1/search/unified (fusionha 0.4.236)
//
// The library and TMDB in one call. `tmdb=auto` searches TMDB only when the
// library has no match; `always` / `never` force it. TMDB runs under a time
// budget and reports how it went in `sources.tmdb`; the library rows come back
// either way. A request-only account gets `sources.library = forbidden`.

/// When the server searches TMDB.
public enum UnifiedTmdbMode: String, Sendable, Hashable {
    /// Only when the library has no match (the Search tab's default).
    case auto
    /// Always ("Search to add").
    case always
    case never
}

/// `sources.library`.
public enum UnifiedLibrarySource: String, Sendable, Hashable, Decodable {
    case ok, forbidden

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UnifiedLibrarySource(rawValue: raw) ?? .ok
    }
}

/// `sources.tmdb`: how the TMDB lane went.
public enum UnifiedTmdbSource: String, Sendable, Hashable, Decodable {
    case ok
    /// Not searched: `auto` and the library matched, or `never`.
    case skipped
    /// The time budget ran out; the rows are whatever answered in time.
    case timeout
    /// TMDB failed.
    case unavailable
    /// No TMDB API key.
    case notConfigured = "not_configured"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = UnifiedTmdbSource(rawValue: raw) ?? .unavailable
    }
}

public struct UnifiedSearchResponse: Decodable, Sendable, Hashable {
    public struct Query: Decodable, Sendable, Hashable {
        /// The term as sent.
        public let term: String
        /// The lower-cased title the library lane matched on.
        public let title: String
        /// A trailing year split off the term.
        public let year: Int?
    }

    public struct Sources: Decodable, Sendable, Hashable {
        public let library: UnifiedLibrarySource
        public let tmdb: UnifiedTmdbSource
    }

    public struct Library: Decodable, Sendable, Hashable {
        /// Every match before the `limit` cap (for "+N more").
        public let total: Int
        /// The ranked matches, each the `GET /library` row.
        public let items: [MediaItem]
    }

    public struct Tmdb: Decodable, Sendable, Hashable {
        /// Credit for the "via" label.
        public let provider: String?
        /// The `GET /search?kind=all` rows, with `in_library`.
        public let items: [MediaSearchResult]
    }

    public let query: Query
    public let sources: Sources
    public let library: Library
    public let tmdb: Tmdb
}

extension SearchKind {
    /// The `kinds` filter for `/search/unified`: none for All (the server's
    /// default is every kind). Anime is its own kind there.
    var unifiedKinds: [String] {
        self == .all ? [] : [rawValue]
    }
}

extension APIClient {
    /// `GET /api/v1/search/unified`: the library (at most `limit` rows) and
    /// TMDB in one call.
    public func searchUnified(term: String, kind: SearchKind, tmdb: UnifiedTmdbMode,
                              limit: Int = 8) async throws -> UnifiedSearchResponse {
        var query = [URLQueryItem(name: "q", value: term),
                     URLQueryItem(name: "limit", value: "\(limit)"),
                     URLQueryItem(name: "tmdb", value: tmdb.rawValue)]
        query += kind.unifiedKinds.map { URLQueryItem(name: "kinds", value: $0) }
        return try await get("/api/v1/search/unified", query: query)
    }
}
