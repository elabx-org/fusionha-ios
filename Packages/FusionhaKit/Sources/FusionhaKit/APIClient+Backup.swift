import Foundation

extension APIClient {
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

    /// The archive's bytes, for the share sheet. A backup that holds the secret
    /// key needs the password again (0.4.188): pass it and the download goes
    /// through `POST …/{id}/download`, which re-authenticates and is audited.
    /// Without one, the plain GET is refused for such a backup with 403
    /// `reauth_required`.
    public func downloadBackup(id: String, password: String? = nil) async throws -> Data {
        let path = "/api/v1/system/backups/\(id)/download"
        guard let password else { return try await downloadRaw(path) }
        var req = request(method: "POST", path: path, query: [])
        req.timeoutInterval = 300
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["password": password])
        let (data, response) = try await session.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.http(status: status, body: String(decoding: data.prefix(8192), as: UTF8.self))
        }
        return data
    }
}
