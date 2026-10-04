import Foundation

// Endpoints behind the Activity and Wanted screens, matching the web's calls.
extension APIClient {
    private func q(_ pairs: [(String, String?)]) -> [URLQueryItem] {
        pairs.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
    }

    private func call<T: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await perform(request(method: method, path: path, query: query))
    }

    private func call<T: Decodable, B: Encodable>(_ method: String, _ path: String, query: [URLQueryItem] = [], body: B) async throws -> T {
        var req = request(method: method, path: path, query: query)
        req.httpBody = try Self.encoder.encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(req)
    }

    private func fire(_ method: String, _ path: String, query: [URLQueryItem] = []) async throws {
        let _: EmptyResponse = try await call(method, path, query: query)
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let t = text?.trimmingCharacters(in: .whitespaces), !t.isEmpty else { return nil }
        return t
    }

    // MARK: Queue

    /// `GET /api/v1/queue?page=&page_size=&q=` (the Activity feed; AppModel polls page 1 separately).
    public func queuePage(page: Int = 1, pageSize: Int = 50, query: String? = nil) async throws -> QueuePage {
        try await get("/api/v1/queue", query: q([("page", "\(page)"), ("page_size", "\(pageSize)"), ("q", Self.nonEmpty(query))]))
    }

    public func processQueueNow() async throws -> QueueProcessResult {
        try await call("POST", "/api/v1/queue/process")
    }

    /// `DELETE /api/v1/queue/{id}`, each option only sent when on.
    public func removeQueueItem(id: Int, deleteData: Bool = false, blocklist: Bool = false, search: Bool = false) async throws {
        try await fire("DELETE", "/api/v1/queue/\(id)", query: q([
            ("blocklist", blocklist ? "true" : nil),
            ("delete_data", deleteData ? "true" : nil),
            ("search", search ? "true" : nil),
        ]))
    }

    // MARK: Search

    /// The decision-engine search (`POST /library/{id}/search`, no `/api/v1` prefix),
    /// optionally scoped to one edition / episode, or to missing targets only.
    public func runSearch(itemId: Int, editionId: Int? = nil, episodeId: Int? = nil, missingOnly: Bool = false) async throws {
        try await fire("POST", "/library/\(itemId)/search", query: q([
            ("edition_id", editionId.map(String.init)),
            ("episode_id", episodeId.map(String.init)),
            ("missing_only", missingOnly ? "true" : nil),
        ]))
    }

    /// `POST /api/v1/library/{id}/search/gradual[?missing_only=true]` — one episode at a time in the background.
    public func startGradualSearch(itemId: Int, missingOnly: Bool) async throws -> GradualSearchStart {
        try await call("POST", "/api/v1/library/\(itemId)/search/gradual", query: q([("missing_only", missingOnly ? "true" : nil)]))
    }

    public func cancelGradualSearch(itemId: Int) async throws {
        try await fire("POST", "/api/v1/library/\(itemId)/search/gradual/cancel")
    }

    // MARK: History

    public func historyPage(page: Int = 1, pageSize: Int = 50, query: String? = nil) async throws -> HistoryPage {
        try await get("/api/v1/history", query: q([("page", "\(page)"), ("page_size", "\(pageSize)"), ("q", Self.nonEmpty(query))]))
    }

    public func historySparkline(days: Int = 14) async throws -> [HistorySparklineDay] {
        try await get("/api/v1/history/sparkline", query: [URLQueryItem(name: "days", value: "\(days)")])
    }

    public func regrab(historyId: Int, override: Bool = false) async throws -> RegrabResult {
        try await call("POST", "/api/v1/history/\(historyId)/regrab", body: RegrabRequest(override: override))
    }

    // MARK: Blocklist

    public func blocklistPage(page: Int = 1, pageSize: Int = 50, query: String? = nil) async throws -> BlocklistPage {
        try await get("/api/v1/blocklist", query: q([("page", "\(page)"), ("page_size", "\(pageSize)"), ("q", Self.nonEmpty(query))]))
    }

    public func blocklistRelease(_ body: BlocklistCreate) async throws -> BlocklistCreateResponse {
        try await call("POST", "/api/v1/blocklist", body: body)
    }

    public func deleteBlocklistEntry(id: Int) async throws {
        try await fire("DELETE", "/api/v1/blocklist/\(id)")
    }

    public func deleteBlocklistEntries(ids: [Int]) async throws {
        let _: EmptyResponse = try await call("DELETE", "/api/v1/blocklist", body: BlocklistIds(ids: ids))
    }

    public func clearBlocklist() async throws -> ClearedCount {
        try await call("DELETE", "/api/v1/blocklist/all")
    }

    // MARK: Tasks

    public func systemRuns(page: Int = 1, pageSize: Int = 200) async throws -> CommandRunPage {
        try await get("/api/v1/system/runs", query: q([("page", "\(page)"), ("page_size", "\(pageSize)")]))
    }

    public func systemRun(id: Int) async throws -> CommandRunDetail {
        try await get("/api/v1/system/runs/\(id)")
    }

    public func cancelRun(id: Int) async throws {
        try await fire("POST", "/api/v1/system/runs/\(id)/cancel")
    }

    public func activitySystemTasks() async throws -> [ActivitySystemTask] {
        try await get("/api/v1/system/tasks")
    }

    public func runTask(name: String) async throws {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        try await fire("POST", "/api/v1/system/tasks/\(encoded)/run")
    }

    public func enrichmentStatus() async throws -> EnrichmentStatus {
        try await get("/api/v1/import/enrichment-status")
    }

    public func activitySettings() async throws -> ActivitySettings {
        try await get("/api/v1/settings")
    }

    public func updateActivitySettings(_ body: ActivitySettingsUpdate) async throws {
        let _: EmptyResponse = try await call("PUT", "/api/v1/settings", body: body)
    }

    // MARK: Audit / Indexers

    public func audit(limit: Int = 100, beforeId: Int? = nil) async throws -> [AuditEntry] {
        try await get("/api/v1/audit", query: q([("limit", "\(limit)"), ("before_id", beforeId.map(String.init))]))
    }

    public func activityIndexerStats(range: String) async throws -> ActivityIndexerStats {
        try await get("/api/v1/indexers/stats", query: [URLQueryItem(name: "range", value: range)])
    }

    // MARK: Wanted

    public func wantedPage(state: WantedState?, page: Int = 1, pageSize: Int = 50, query: String? = nil) async throws -> WantedPage {
        try await get("/api/v1/wanted", query: q([
            ("page", "\(page)"), ("page_size", "\(pageSize)"),
            ("state", state?.rawValue), ("q", Self.nonEmpty(query)),
        ]))
    }

    public func fourKAvailable(page: Int = 1, pageSize: Int = 50, query: String? = nil) async throws -> FourKAvailablePage {
        try await get("/api/v1/wanted/4k-available", query: q([("page", "\(page)"), ("page_size", "\(pageSize)"), ("q", Self.nonEmpty(query))]))
    }

    public func checkFourK(itemId: Int) async throws -> CheckFourKResult {
        try await call("POST", "/api/v1/library/\(itemId)/check-4k")
    }

    public func addEdition(itemId: Int, _ body: EditionAddRequest) async throws {
        let _: EmptyResponse = try await call("POST", "/api/v1/library/\(itemId)/editions", body: body)
    }
}
