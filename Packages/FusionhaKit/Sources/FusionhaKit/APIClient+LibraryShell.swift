import Foundation

// Endpoints for the Library page, the shell, the Add flow and Login.
extension APIClient {
    // MARK: Card + bulk actions

    public func bulkMonitor(_ body: BulkMonitorRequest) async throws {
        let _: BulkResult = try await send("POST", "/api/v1/library/bulk/monitor", body: body)
    }

    public func bulkRefresh(_ body: BulkRefreshRequest) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/library/bulk/refresh", body: body)
    }

    public func bulkQualityProfile(_ body: BulkQualityProfileRequest) async throws {
        let _: BulkResult = try await send("POST", "/api/v1/library/bulk/quality-profile", body: body)
    }

    @discardableResult
    public func bulkMinimumAvailability(_ body: BulkMinimumAvailabilityRequest) async throws -> BulkResult {
        try await send("POST", "/api/v1/library/bulk/minimum-availability", body: body)
    }

    public func bulkRootFolder(_ body: BulkRootFolderRequest) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/library/bulk/root-folder", body: body)
    }

    public func bulkDelete(_ body: BulkDeleteRequest) async throws {
        let _: BulkResult = try await send("POST", "/api/v1/library/bulk/delete", body: body)
    }

    /// `POST /api/v1/library/{id}/refresh?metadata_only=` → `202 {run_id}`.
    public func refreshItem(id: Int, metadataOnly: Bool = true) async throws -> RefreshDispatch {
        var req = request(method: "POST", path: "/api/v1/library/\(id)/refresh",
                          query: [URLQueryItem(name: "metadata_only", value: metadataOnly ? "true" : "false")])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(req)
    }

    public func run(id: Int) async throws -> CommandRunState {
        try await get("/api/v1/system/runs/\(id)")
    }

    /// `DELETE /api/v1/library/{id}[?deleteFiles=true]`.
    public func deleteItem(id: Int, deleteFiles: Bool) async throws {
        let query = deleteFiles ? [URLQueryItem(name: "deleteFiles", value: "true")] : []
        let _: EmptyResponse = try await perform(request(method: "DELETE", path: "/api/v1/library/\(id)", query: query))
    }

    // MARK: Shell

    public func libraryAttention() async throws -> AttentionItems {
        try await get("/api/v1/library/attention")
    }

    public func runAttention() async throws -> AttentionItems {
        try await get("/api/v1/system/runs/attention")
    }

    public func indexersUnavailable() async throws -> AttentionItems {
        try await get("/api/v1/system/indexers/unavailable")
    }

    public func commands() async throws -> [ShellCommand] {
        try await get("/api/v1/system/commands")
    }

    public func requests(status: String) async throws -> [MediaRequest] {
        try await get("/api/v1/requests", query: [URLQueryItem(name: "status", value: status)])
    }

    public func shellSettings() async throws -> ShellSettings {
        try await get("/api/v1/settings")
    }

    public func updateRailSettings(_ body: RailSettingsUpdate) async throws {
        let _: EmptyResponse = try await send("PUT", "/api/v1/settings", body: body)
    }

    /// Ends the server session (`POST /api/v1/auth/logout`).
    public func logout() async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/auth/logout", body: Optional<String>.none)
    }

    /// Revokes this device's personal token.
    public func revokeToken(id: Int) async throws {
        let _: EmptyResponse = try await perform(request(method: "DELETE", path: "/api/v1/tokens/\(id)", query: []))
    }

    /// The user's Plex avatar, fetched with this client's auth headers.
    public func avatarData(userId: Int) async throws -> Data {
        var req = request(method: "GET", path: "/api/v1/users/\(userId)/avatar", query: [])
        req.setValue("image/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw APIError.http(status: status, body: "") }
        return data
    }

    // MARK: Add

    public func searchTVDB(term: String) async throws -> [TvdbSearchResult] {
        try await get("/api/v1/search/tvdb", query: [URLQueryItem(name: "term", value: term)])
    }

    public func checkFourK(_ body: FourKAvailabilityRequest) async throws -> FourKAvailability {
        try await send("POST", "/api/v1/discover/check-4k", body: body)
    }

    public func qualityProfileSummaries() async throws -> [QualityProfileSummary] {
        try await get("/api/v1/qualityprofiles")
    }

    public func addItem(_ body: LibraryAddBody) async throws -> AddedItem {
        try await send("POST", "/api/v1/library", body: body)
    }

    // MARK: Login

    public func authProviders() async throws -> [SignInProvider] {
        try await get("/api/v1/auth/providers")
    }

    public func demoLogin(_ body: DemoLoginRequest) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/demo/login", body: body)
    }
}
