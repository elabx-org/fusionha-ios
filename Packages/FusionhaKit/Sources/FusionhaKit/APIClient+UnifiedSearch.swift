import Foundation

extension APIClient {
    /// `GET /api/v1/search/by-id`: a pasted IMDb / TVDB / TMDB id (`tt…`,
    /// `tvdb:N`, `tmdb:N`) resolved to one add candidate. 404 when the id names
    /// nothing, 422 when it isn't an id, 409 `tmdb_not_configured`.
    public func searchById(_ id: String, kind: SearchKind) async throws -> MediaSearchResult {
        try await get("/api/v1/search/by-id", query: [URLQueryItem(name: "id", value: id),
                                                      URLQueryItem(name: "kind", value: kind.rawValue)])
    }
}
