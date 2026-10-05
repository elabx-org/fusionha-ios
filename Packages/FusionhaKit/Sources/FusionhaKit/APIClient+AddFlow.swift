import Foundation

/// The Add title v2 endpoints.
extension APIClient {
    /// `GET /api/v1/discover/preview?tmdb_id&kind` read with the Add v2 fields.
    public func addPreview(kind: PreviewKind, tmdbId: Int) async throws -> AddPreview {
        try await get("/api/v1/discover/preview", query: [URLQueryItem(name: "tmdb_id", value: String(tmdbId)),
                                                          URLQueryItem(name: "kind", value: kind.rawValue)])
    }

    /// `GET /api/v1/preview/tvdb/{tvdb_id}`: the same shape for a TVDB-only pick.
    public func tvdbPreview(tvdbId: Int) async throws -> AddPreview {
        try await get("/api/v1/preview/tvdb/\(tvdbId)")
    }

    /// `GET /api/v1/library/last-added`; nil when there is no earlier add.
    public func lastAdded(kind: MediaKind, anime: Bool) async throws -> LastAdded? {
        try await get("/api/v1/library/last-added", query: [URLQueryItem(name: "kind", value: kind.rawValue),
                                                             URLQueryItem(name: "anime", value: anime ? "true" : "false")])
    }

    public func addSettings() async throws -> AddSettings {
        try await get("/api/v1/settings")
    }

    /// `POST /api/v1/library` with the v2 body.
    public func addTitle(_ body: AddTitleBody) async throws -> AddedTitle {
        try await send("POST", "/api/v1/library", body: body)
    }

    /// `POST /api/v1/discover/check-4k` for a TMDB or TVDB-only pick.
    public func addCheckFourK(_ body: AddFourKCheckBody) async throws -> FourKAvailability {
        try await send("POST", "/api/v1/discover/check-4k", body: body)
    }
}
