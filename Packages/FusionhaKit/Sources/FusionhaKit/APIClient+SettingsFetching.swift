import Foundation

/// The config collections behind the web's generic `createCrud` (`lib/api/config.ts`).
public enum ConfigCollection: String, Sendable {
    case rootFolders = "rootfolders"
    case downloadClients = "downloadclients"
    case searchIndexers = "searchindexers"
    case notificationAgents = "notificationagents"
}

/// Endpoints for the native Settings panels (Root Folders … Logs). Same routes and
/// bodies as the web panels.
extension APIClient {
    private static let jsonBodyEncoder = JSONEncoder()

    /// Sends a `SettingsJSON` body verbatim (keys stay snake_case; `null`s are kept).
    func sendJSON<T: Decodable>(_ method: String, _ path: String, _ body: SettingsJSON? = nil,
                                query: [URLQueryItem] = []) async throws -> T {
        var req = request(method: method, path: path, query: query)
        if let body {
            req.httpBody = try Self.jsonBodyEncoder.encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await perform(req)
    }

    func sendJSON(_ method: String, _ path: String, _ body: SettingsJSON? = nil,
                  query: [URLQueryItem] = []) async throws {
        let _: EmptyResponse = try await sendJSON(method, path, body, query: query)
    }

    // MARK: Generic collection CRUD

    public func configList<T: Decodable>(_ collection: ConfigCollection) async throws -> [T] {
        try await get("/api/v1/\(collection.rawValue)")
    }

    public func configCreate(_ collection: ConfigCollection, _ body: SettingsJSON,
                             query: [URLQueryItem] = []) async throws {
        try await sendJSON("POST", "/api/v1/\(collection.rawValue)", body, query: query)
    }

    public func configUpdate(_ collection: ConfigCollection, id: Int, _ body: SettingsJSON,
                             query: [URLQueryItem] = []) async throws {
        try await sendJSON("PUT", "/api/v1/\(collection.rawValue)/\(id)", body, query: query)
    }

    public func configDelete(_ collection: ConfigCollection, id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/\(collection.rawValue)/\(id)")
    }

    /// `POST /{collection}/{id}/test`: probe a saved row.
    public func configTest(_ collection: ConfigCollection, id: Int) async throws -> ConnectionTestResult {
        try await sendJSON("POST", "/api/v1/\(collection.rawValue)/\(id)/test")
    }

    /// `POST /{collection}/test`: probe an unsaved form (nothing is written).
    public func configTestUnsaved(_ collection: ConfigCollection, _ body: SettingsJSON) async throws -> ConnectionTestResult {
        try await sendJSON("POST", "/api/v1/\(collection.rawValue)/test", body)
    }

    // MARK: Root folders

    public func rootFolderDetails() async throws -> [RootFolderInfo] {
        try await configList(.rootFolders)
    }

    /// `PUT /api/v1/config/add-defaults` with only the changed slots.
    public func saveAddDefaults(_ slots: [AddDefaultSlot]) async throws {
        let defaults: [SettingsJSON] = slots.map {
            ["profile_kind": .string($0.profileKind), "tier": .string($0.tier.rawValue),
             "quality_profile_id": .optional($0.qualityProfileId), "root_folder_id": .optional($0.rootFolderId)]
        }
        let _: [AddDefaultSlot] = try await sendJSON("PUT", "/api/v1/config/add-defaults", ["defaults": .array(defaults)])
    }

    // MARK: Indexers

    public func indexerStats(range: String) async throws -> IndexerStatsResponse {
        try await get("/api/v1/indexers/stats", query: [URLQueryItem(name: "range", value: range)])
    }

    public func testAllIndexers() async throws -> IndexerTestAllResult {
        try await sendJSON("POST", "/api/v1/searchindexers/test-all")
    }

    // MARK: Connect

    public func arrWebhooks() async throws -> [ArrWebhookGroup] {
        try await get("/api/v1/arr-webhooks")
    }

    public func deleteArrWebhook(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/arr-webhooks/\(id)")
    }

    // MARK: Notifications

    public func notificationPreferences() async throws -> NotificationPreferences {
        try await get("/api/v1/notifications/preferences")
    }

    public func setNotificationPreference(event: String, enabled: Bool) async throws -> NotificationPreferences {
        try await sendJSON("PUT", "/api/v1/notifications/preferences",
                           ["preferences": [["event_kind": .string(event), "enabled": .bool(enabled)]]])
    }

    public func pushSubscriptions() async throws -> [PushSubscriptionInfo] {
        try await get("/api/v1/notifications/webpush/subscriptions")
    }

    public func webPushSettings() async throws -> WebPushSettings {
        try await get("/api/v1/notifications/webpush/settings")
    }

    public func updateWebPushSettings(_ body: SettingsJSON) async throws -> WebPushSettings {
        try await sendJSON("PUT", "/api/v1/notifications/webpush/settings", body)
    }

    public func testPush() async throws -> PushTestResult {
        try await sendJSON("POST", "/api/v1/notifications/webpush/test")
    }

    public func rotateVapidKeys() async throws -> VapidRotateResult {
        try await sendJSON("POST", "/api/v1/notifications/webpush/vapid/rotate")
    }

    // MARK: Connections

    public func instances() async throws -> [VirtualInstance] {
        try await get("/api/v1/instances")
    }

    public func updateInstance(id: Int, _ body: SettingsJSON) async throws {
        try await sendJSON("PATCH", "/api/v1/instances/\(id)", body)
    }

    public func deleteInstance(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/instances/\(id)")
    }

    public func revealInstanceKey(id: Int) async throws -> InstanceKeyReveal {
        try await get("/api/v1/instances/\(id)/reveal-key")
    }

    public func regenerateInstanceKey(id: Int) async throws -> InstanceKeyReveal {
        try await sendJSON("POST", "/api/v1/instances/\(id)/regenerate-key")
    }

    public func apiTokens() async throws -> [ApiTokenInfo] {
        try await get("/api/v1/tokens")
    }

    /// Mints a personal token; `expiresAt` is an ISO-8601 instant or nil for "never".
    public func mintApiToken(name: String, expiresAt: String?) async throws -> TokenMint {
        try await sendJSON("POST", "/api/v1/tokens", ["name": .string(name), "expires_at": .optional(expiresAt)])
    }

    public func revokeApiToken(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/tokens/\(id)")
    }

    // MARK: Public access

    public func demoStatus() async throws -> DemoStatus {
        try await get("/api/v1/demo")
    }

    public func updateDemo(_ body: SettingsJSON) async throws -> DemoStatus {
        try await sendJSON("PUT", "/api/v1/demo", body)
    }

    /// `POST /api/v1/demo/{seed|reset|wipe}`.
    public func demoAction(_ action: String) async throws {
        try await sendJSON("POST", "/api/v1/demo/\(action)")
    }

    // MARK: System

    public func systemTasks() async throws -> [SystemTask] {
        try await get("/api/v1/system/tasks")
    }

    public func systemCommands() async throws -> [SystemCommand] {
        try await get("/api/v1/system/commands")
    }

    @discardableResult
    public func runSystemTask(name: String) async throws -> SystemCommand {
        try await sendJSON("POST", "/api/v1/system/tasks/\(name)/run")
    }

    public func databaseBackend() async throws -> DatabaseBackendInfo {
        try await get("/api/v1/migrate/postgres/backend")
    }

    // MARK: Backup

    public func backupConfig() async throws -> BackupConfig {
        try await get("/api/v1/system/backups/config")
    }

    public func updateBackupConfig(_ body: SettingsJSON) async throws -> BackupConfig {
        try await sendJSON("PUT", "/api/v1/system/backups/config", body)
    }

    public func backups() async throws -> [BackupRecord] {
        try await get("/api/v1/system/backups")
    }

    public func createBackup() async throws -> BackupCreateResult {
        try await sendJSON("POST", "/api/v1/system/backups")
    }

    public func deleteBackup(id: String) async throws {
        try await sendJSON("DELETE", "/api/v1/system/backups/\(id)")
    }

    /// The archive's bytes (`GET …/{id}/download`), for the share sheet.
    public func downloadBackup(id: String) async throws -> Data {
        try await downloadRaw("/api/v1/system/backups/\(id)/download")
    }

    /// The whole log buffer as text (`GET /api/v1/system/logs/download`).
    public func downloadLogs() async throws -> Data {
        try await downloadRaw("/api/v1/system/logs/download")
    }

    func downloadRaw(_ path: String) async throws -> Data {
        var req = request(method: "GET", path: path, query: [])
        req.timeoutInterval = 300
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, body: String(decoding: data.prefix(500), as: UTF8.self))
        }
        return data
    }

    // MARK: Logs

    /// Newest-first log records; `since` is the high-water `ts` already shown.
    public func systemLogs(since: Double?, limit: Int = 2000) async throws -> [LogRecord] {
        var query = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let since { query.append(URLQueryItem(name: "since", value: String(since))) }
        return try await get("/api/v1/system/logs", query: query)
    }
}
