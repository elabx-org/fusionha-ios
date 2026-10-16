import Foundation

extension APIClient {
    // MARK: Manual Import (`/api/v1/manualimport/*`)

    /// Seeds a scan pre-scoped to held downloads (the queue rescue). One id goes
    /// through `POST /rescue/{id}`; several merge into one scan via `POST /rescue`.
    /// Each row still commits to its own source download.
    public func manualImportRescue(downloadIds: [Int]) async throws -> ManualImportScan {
        if downloadIds.count == 1, let id = downloadIds.first {
            return try await manualImportCall("POST", "/api/v1/manualimport/rescue/\(id)")
        }
        return try await manualImportCall("POST", "/api/v1/manualimport/rescue",
                                          ["download_ids": .ints(downloadIds)])
    }

    /// Scans a folder on the server (synchronous: the rows come back whole).
    public func manualImportScan(path: String) async throws -> ManualImportScan {
        try await manualImportCall("POST", "/api/v1/manualimport/scan", ["path": .string(path)])
    }

    /// One directory's subfolders, for the folder picker.
    public func manualImportBrowse(path: String?) async throws -> ManualImportBrowse {
        try await get("/api/v1/manualimport/browse", query: path.map { [URLQueryItem(name: "path", value: $0)] } ?? [])
    }

    public func manualImportScan(id: Int) async throws -> ManualImportScan {
        try await get("/api/v1/manualimport/scan/\(id)")
    }

    /// Fills the rows whose probe outlived the scan's budget.
    public func manualImportProbe(scanId: Int) async throws -> ManualImportScan {
        try await manualImportCall("POST", "/api/v1/manualimport/scan/\(scanId)/probe")
    }

    /// A partial per-row override: only the keys sent apply, and an explicit
    /// `null` clears (the edition, the episode). Returns the whole scan.
    public func manualImportOverride(scanId: Int, rowId: Int,
                                     _ fields: [String: SettingsJSON]) async throws -> ManualImportScan {
        var body = fields
        body["row_id"] = .int(rowId)
        return try await manualImportCall("POST", "/api/v1/manualimport/scan/\(scanId)/override", .object(body))
    }

    /// Imports the rows in place. A batch holding a row the server would refuse
    /// is rejected whole (422 `invalid_rows`); otherwise each row has its result.
    /// `finish`: per held download, how to end it when this commit decides its
    /// last open row (the server finishes it through the guarded path).
    public func manualImportCommit(scanId: Int, rowIds: [Int], mode: ManualImportMode,
                                   finish: [Int: FinishDisposition] = [:]) async throws -> ManualImportCommitResult {
        var body: [String: SettingsJSON] = [
            "scan_id": .int(scanId), "row_ids": .ints(rowIds), "import_mode": .string(mode.rawValue),
        ]
        if !finish.isEmpty {
            body["finish_disposition"] = .object(Dictionary(uniqueKeysWithValues: finish.map { (String($0.key), .string($0.value.rawValue)) }))
        }
        return try await manualImportCall("POST", "/api/v1/manualimport/commit", .object(body))
    }

    /// Ends a held download once its rows are decided: remove, remove + blocklist
    /// (both admin), or leave (only clears the hold).
    public func finishRescue(downloadId: Int, disposition: FinishDisposition) async throws -> FinishRescueResult {
        try await sendJSON("POST", "/api/v1/queue/\(downloadId)/finish-rescue", ["disposition": .string(disposition.rawValue)])
    }

    /// Scans, probes and commits read and link files on the server, so they get
    /// the long timeout the web waits out.
    private func manualImportCall<T: Decodable>(_ method: String, _ path: String,
                                                _ body: SettingsJSON? = nil) async throws -> T {
        var req = request(method: method, path: path, query: [])
        req.timeoutInterval = 180
        if let body {
            req.httpBody = try Self.jsonBodyEncoder.encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await perform(req)
    }
}

extension APIError {
    /// The rows a commit refused (`{"detail": {"invalid_rows": [...]}}`), or nil.
    public var invalidRowCount: Int? {
        guard case .http(422, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let detail = object["detail"] as? [String: Any],
              let rows = detail["invalid_rows"] as? [Any] else { return nil }
        return rows.count
    }
}

/// `GET /manualimport/browse`: a folder, its parent and its subfolders.
public struct ManualImportBrowse: Decodable, Sendable {
    public struct Entry: Decodable, Sendable, Hashable, Identifiable {
        public let name: String
        public let path: String
        public var id: String { path }
    }

    public let path: String
    public let parent: String?
    public let entries: [Entry]

    /// `/`, `downloads`, `complete` with the path each one opens.
    public var crumbs: [Entry] {
        var out = [Entry(name: "/", path: "/")]
        var cur = ""
        for part in path.split(separator: "/") {
            cur += "/\(part)"
            out.append(Entry(name: String(part), path: cur))
        }
        return out
    }
}
