import Foundation

// Endpoints the item detail page calls. Same paths, query keys and bodies as the
// web app's lib/api/detail.ts.
extension APIClient {
    private func call<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await perform(request(method: method, path: path, query: query))
    }

    private func call<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [URLQueryItem] = [], body: B) async throws -> T {
        var req = request(method: method, path: path, query: query)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try encoder.encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(req)
    }

    private static func items(_ pairs: [(String, String?)]) -> [URLQueryItem] {
        pairs.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
    }

    // MARK: Page data

    public func enrichmentStatus() async throws -> EnrichmentStatus {
        try await call("GET", "/api/v1/import/enrichment-status")
    }

    public func searchPauses(itemId: Int) async throws -> SearchPauses {
        try await call("GET", "/api/v1/library/\(itemId)/search-pauses")
    }

    public func detailSettings() async throws -> DetailSettings {
        try await call("GET", "/api/v1/settings")
    }

    public func editionDefinitions() async throws -> [EditionDefinition] {
        try await call("GET", "/api/v1/config/editions")
    }

    public func tags() async throws -> [ItemTag] {
        try await call("GET", "/api/v1/tags")
    }

    public func createTag(label: String) async throws -> ItemTag {
        try await call("POST", "/api/v1/tags", body: TagCreate(label: label))
    }

    /// The Searches tab: decision passes that touched this item, newest first.
    public func runs(touchedItem: Int, page: Int = 1, pageSize: Int = 50) async throws -> CommandRunPage {
        try await call("GET", "/api/v1/system/runs", query: [
            URLQueryItem(name: "touched_item", value: "\(touchedItem)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ])
    }

    public func commandRun(id: Int) async throws -> CommandRun {
        try await call("GET", "/api/v1/system/runs/\(id)")
    }

    // MARK: Searches

    /// The decision-engine search (`POST /library/{id}/search`, no `/api/v1` prefix).
    public func search(itemId: Int, editionId: Int? = nil, season: Int? = nil,
                       episodeId: Int? = nil, missingOnly: Bool = false) async throws -> [SearchDecision] {
        try await call("POST", "/library/\(itemId)/search", query: Self.items([
            ("episode_id", episodeId.map(String.init)),
            ("season", season.map(String.init)),
            ("version_id", editionId.map(String.init)),
            ("missing_only", missingOnly ? "true" : nil),
        ]))
    }

    /// One-at-a-time search: the whole title (`season == nil`) or one season.
    public func gradualSearch(itemId: Int, season: Int? = nil, editionId: Int? = nil,
                              missingOnly: Bool = false) async throws -> GradualSearchStart {
        let path = season.map { "/api/v1/library/\(itemId)/search/season/\($0)/gradual" }
            ?? "/api/v1/library/\(itemId)/search/gradual"
        return try await call("POST", path, query: Self.items([
            ("version_id", editionId.map(String.init)),
            ("missing_only", missingOnly ? "true" : nil),
        ]))
    }

    public func cancelGradualSearch(itemId: Int, season: Int? = nil) async throws {
        let path = season.map { "/api/v1/library/\(itemId)/search/season/\($0)/gradual/cancel" }
            ?? "/api/v1/library/\(itemId)/search/gradual/cancel"
        let _: EmptyResponse = try await call("POST", path)
    }

    public func releases(itemId: Int, editionId: Int, episodeId: Int? = nil, seasonNumber: Int? = nil) async throws -> [ReleasePreview] {
        try await call("GET", "/api/v1/library/\(itemId)/releases", query: Self.items([
            ("version_id", String(editionId)),
            ("episode_id", episodeId.map(String.init)),
            ("season_number", seasonNumber.map(String.init)),
        ]))
    }

    @discardableResult
    public func grab(itemId: Int, _ body: ReleaseGrabRequest) async throws -> ReleaseGrabResponse {
        try await call("POST", "/api/v1/library/\(itemId)/releases/grab", body: body)
    }

    /// Why this scope's automatic search is paused (backoff / failed-grab cooldown).
    public func releaseScopeStatus(itemId: Int, editionId: Int, episodeId: Int? = nil,
                                   seasonNumber: Int? = nil) async throws -> ReleaseScopeStatus {
        try await call("GET", "/api/v1/library/\(itemId)/releases/scope-status", query: Self.items([
            ("version_id", String(editionId)),
            ("episode_id", episodeId.map(String.init)),
            ("season_number", seasonNumber.map(String.init)),
        ]))
    }

    /// Indexers the failure backoff has auto-disabled (skipped by every search).
    public func unavailableIndexers() async throws -> IndexerUnavailableSummary {
        try await call("GET", "/api/v1/system/indexers/unavailable")
    }

    public func checkFourK(itemId: Int) async throws -> FourKCheck {
        try await call("POST", "/api/v1/library/\(itemId)/check-4k")
    }

    public func numberingPreview(itemId: Int) async throws -> NumberingPreview {
        try await call("GET", "/api/v1/library/\(itemId)/numbering/preview")
    }

    // MARK: Refresh

    public func refreshSeason(itemId: Int, season: Int) async throws -> RefreshDispatch {
        try await call("POST", "/api/v1/library/\(itemId)/seasons/\(season)/refresh")
    }

    // MARK: Edits

    public func setSeasonMonitored(itemId: Int, season: Int, monitored: Bool) async throws {
        let _: EmptyResponse = try await call("PATCH", "/api/v1/library/\(itemId)/seasons/\(season)",
                                              body: MonitorToggle(monitored: monitored))
    }

    public func updateItem(id: Int, _ body: ItemUpdate) async throws {
        let _: EmptyResponse = try await call("PATCH", "/api/v1/library/\(id)", body: body)
    }

    /// `PATCH /api/v1/library/{id}/episodes/{eid}`: the per-episode monitor toggle.
    public func setEpisodeMonitored(itemId: Int, episodeId: Int, monitored: Bool) async throws {
        let _: EmptyResponse = try await call("PATCH", "/api/v1/library/\(itemId)/episodes/\(episodeId)",
                                              body: MonitorToggle(monitored: monitored))
    }

    // Versions: `/versions` since 0.4.122 (the old `/editions` routes are deprecated).

    public func updateEdition(itemId: Int, editionId: Int, _ body: EditionUpdate) async throws {
        let _: EmptyResponse = try await call("PATCH", "/api/v1/library/\(itemId)/versions/\(editionId)", body: body)
    }

    public func addEdition(itemId: Int, _ body: EditionAdd) async throws {
        let _: EmptyResponse = try await call("POST", "/api/v1/library/\(itemId)/versions", body: body)
    }

    /// #82 dead-link "Search replacement": deletes the version's dead file(s), then re-grabs.
    public func replaceDeadVersion(versionId: Int) async throws {
        let _: EmptyResponse = try await call("POST", "/api/v1/library/versions/\(versionId)/replace-dead")
    }

    public func deleteEdition(itemId: Int, editionId: Int, deleteFiles: Bool) async throws {
        let _: EmptyResponse = try await call("DELETE", "/api/v1/library/\(itemId)/versions/\(editionId)",
                                              query: deleteFiles ? [URLQueryItem(name: "deleteFiles", value: "true")] : [])
    }

    public func deleteFile(id: Int, blocklist: Bool, search: Bool = true) async throws {
        let _: EmptyResponse = try await call("DELETE", "/api/v1/library/files/\(id)", query: [
            URLQueryItem(name: "blocklist", value: blocklist ? "true" : "false"),
            URLQueryItem(name: "search", value: search ? "true" : "false"),
        ])
    }

    public func cleanupLink(fileId: Int) async throws {
        let _: EmptyResponse = try await call("POST", "/api/v1/library/files/\(fileId)/cleanup-link")
    }

    public func regrab(historyId: Int) async throws {
        let _: EmptyResponse = try await call("POST", "/api/v1/history/\(historyId)/regrab")
    }
}
