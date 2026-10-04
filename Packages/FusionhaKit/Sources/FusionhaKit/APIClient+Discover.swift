import Foundation

// Discover, Preview, Requests, Issues and account endpoints, with the same
// paths, queries and bodies the web app sends.
extension APIClient {
    private static func q(_ name: String, _ value: String?) -> URLQueryItem? {
        value.map { URLQueryItem(name: name, value: $0) }
    }

    // MARK: Discover rails

    /// `GET /api/v1/discover` with the rail's own params (`window` only for trending,
    /// `monetization` only for popular).
    public func discover(kind: SearchKind, list: DiscoverList, window: String?, monetization: DiscoverMonetization?) async throws -> [MediaSearchResult] {
        let items = [Self.q("kind", kind.rawValue), Self.q("list", list.rawValue),
                     Self.q("window", window), Self.q("monetization", monetization?.rawValue)].compactMap { $0 }
        return try await get("/api/v1/discover", query: items)
    }

    /// `GET /api/v1/discover/trailers?kind&list=popular|trending|top_rated`.
    public func trailers(kind: SearchKind, list: String) async throws -> [TrailerResult] {
        try await get("/api/v1/discover/trailers", query: [URLQueryItem(name: "kind", value: kind.rawValue),
                                                           URLQueryItem(name: "list", value: list)])
    }

    public func collections() async throws -> [CollectionSummary] {
        try await get("/api/v1/collections")
    }

    public func collection(id: Int) async throws -> CollectionDetail {
        try await get("/api/v1/collections/\(id)")
    }

    public func addCollection(id: Int, body: CollectionAddBody) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/collections/\(id)/add", body: body)
    }

    public func ignoreCollection(_ body: DiscoverIgnoreCreate) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/discover/ignores", body: body)
    }

    public func discoverGenres(kind: SearchKind) async throws -> [DiscoverGenre] {
        try await get("/api/v1/discover/genres", query: [URLQueryItem(name: "kind", value: kind.rawValue)])
    }

    public func watchProviders(kind: SearchKind) async throws -> [WatchProvider] {
        try await get("/api/v1/discover/watch-providers", query: [URLQueryItem(name: "kind", value: kind.rawValue)])
    }

    /// `GET /api/v1/discover/filter?kind&sort[&genre&year&min_rating&provider]`.
    public func discoverFilter(kind: SearchKind, filter: DiscoverFilter) async throws -> [MediaSearchResult] {
        let items = [Self.q("kind", kind.rawValue), Self.q("sort", filter.sort.rawValue),
                     Self.q("genre", filter.genre.map(String.init)), Self.q("year", filter.year.map(String.init)),
                     Self.q("min_rating", filter.minRating.map(String.init)),
                     Self.q("provider", filter.provider.map(String.init))].compactMap { $0 }
        return try await get("/api/v1/discover/filter", query: items)
    }

    public func discoverSettings() async throws -> DiscoverSettings {
        try await get("/api/v1/settings")
    }

    // MARK: 4K checks

    public func discoverCheckFourK(_ body: DiscoverCheckFourKBody) async throws -> FourKCheckResult {
        try await send("POST", "/api/v1/discover/check-4k", body: body)
    }

    public func libraryCheckFourK(itemId: Int) async throws -> FourKCheckResult {
        try await send("POST", "/api/v1/library/\(itemId)/check-4k", body: Optional<String>.none)
    }

    // MARK: Preview

    /// `GET /api/v1/discover/preview?tmdb_id&kind` (the Preview page).
    public func discoverPreview(kind: PreviewKind, tmdbId: Int) async throws -> MediaPreviewDetail {
        try await get("/api/v1/discover/preview", query: [URLQueryItem(name: "tmdb_id", value: String(tmdbId)),
                                                          URLQueryItem(name: "kind", value: kind.rawValue)])
    }

    /// `GET /api/v1/preview/{movie|series|anime}/{tmdb_id}` (request rows, the request modal).
    public func previewDetail(kind: PreviewKind, tmdbId: Int) async throws -> MediaPreviewDetail {
        try await get("/api/v1/preview/\(kind.rawValue)/\(tmdbId)")
    }

    public func previewSeason(kind: PreviewKind, tmdbId: Int, season: Int) async throws -> [PreviewEpisode] {
        try await get("/api/v1/preview/\(kind.rawValue)/\(tmdbId)/season/\(season)")
    }

    // MARK: Requests

    public func requests(status: String?) async throws -> [MediaRequest] {
        try await get("/api/v1/requests", query: [Self.q("status", status)].compactMap { $0 })
    }

    public func offerableEditions(kind: MediaKind, tmdbId: Int) async throws -> OfferableEditions {
        try await get("/api/v1/requests/offerable", query: [URLQueryItem(name: "kind", value: kind.rawValue),
                                                            URLQueryItem(name: "tmdb_id", value: String(tmdbId))])
    }

    public func createRequest(_ body: RequestCreateBody) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/requests", body: body)
    }

    public func approveRequest(id: Int, body: ApproveBody) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/requests/\(id)/approve", body: body)
    }

    public func rejectRequest(id: Int, body: RejectBody) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/requests/\(id)/reject", body: body)
    }

    public func withdrawRequest(id: Int) async throws {
        let _: EmptyResponse = try await send("DELETE", "/api/v1/requests/\(id)", body: Optional<String>.none)
    }

    // MARK: Issues

    public func issues(status: String) async throws -> [MediaIssue] {
        try await get("/api/v1/issues", query: [URLQueryItem(name: "status", value: status)])
    }

    public func reportIssue(_ body: IssueCreateBody) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/issues", body: body)
    }

    public func resolveIssue(id: Int, comment: String?) async throws {
        if let comment, !comment.isEmpty {
            let _: EmptyResponse = try await send("POST", "/api/v1/issues/\(id)/resolve", body: IssueResolveBody(comment: comment))
        } else {
            let _: EmptyResponse = try await send("POST", "/api/v1/issues/\(id)/resolve", body: Optional<String>.none)
        }
    }

    public func deleteIssue(id: Int) async throws {
        let _: EmptyResponse = try await send("DELETE", "/api/v1/issues/\(id)", body: Optional<String>.none)
    }
}
