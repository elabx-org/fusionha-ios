import Foundation

/// Admin import lists (fusionha 0.4.237, phase 10b slice 3; `integrations.manage`).
/// Same routes and bodies as the web's `lib/api/import-lists.ts` and
/// `import-list-ledger.ts`. None of these removes a title a list added.
extension APIClient {
    static let importLists = "/api/v1/import-lists"

    public func importLists() async throws -> [ImportList] {
        try await get(Self.importLists)
    }

    /// 409 `already_exists` / `provider_unavailable`; 422 `duplicate_tier`,
    /// `invalid_root_folder`, `invalid_quality_profile`, `interval_too_short {min_hours}`.
    public func createImportList(_ draft: ImportListDraft) async throws -> ImportList {
        try await sendSlow("POST", Self.importLists, draft.createBody)
    }

    public func updateImportList(_ id: Int, _ patch: SettingsJSON) async throws -> ImportList {
        try await sendJSON("PATCH", "\(Self.importLists)/\(id)", patch)
    }

    /// Removes the list's records and runs, never library items (204).
    public func deleteImportList(_ id: Int) async throws {
        try await sendJSON("DELETE", "\(Self.importLists)/\(id)")
    }

    /// 202; once a minute (429 `rate_limited`), 409 `disabled`.
    public func syncImportList(_ id: Int) async throws {
        try await sendJSON("POST", "\(Self.importLists)/\(id)/sync")
    }

    /// Reads the address and says what a save would do. Nothing is written.
    public func previewImportList(url: String, mediaKind: ImportListMediaKind) async throws -> ImportListPreview {
        try await sendSlow("POST", "\(Self.importLists)/preview",
                           .object(["url": .string(url), "media_kind": .string(mediaKind.rawValue)]))
    }

    // MARK: Runs and the unmatched review

    /// The last 30, newest first.
    public func importListRuns(_ id: Int) async throws -> [ImportListRun] {
        try await get("\(Self.importLists)/\(id)/runs")
    }

    public func importListRunItems(_ runId: Int) async throws -> [ImportListItem] {
        try await get("\(Self.importLists)/runs/\(runId)/items")
    }

    public func importListUnmatched(_ id: Int) async throws -> [ImportListItem] {
        try await get("\(Self.importLists)/\(id)/unmatched")
    }

    /// "Add it": the picked TMDB title goes through the list's add path.
    /// 409 `already_decided`, 422 `wrong_kind`.
    public func resolveImportListItem(_ id: Int, itemId: Int, tmdbId: Int, kind: MediaKind) async throws -> ImportListItem {
        try await sendJSON("POST", "\(Self.importLists)/\(id)/items/\(itemId)/resolve",
                           .object(["tmdb_id": .int(tmdbId), "kind": .string(kind.rawValue)]))
    }

    /// `everywhere` also excludes the title on every other list (422 `needs_match`).
    public func ignoreImportListItem(_ id: Int, itemId: Int, everywhere: Bool) async throws -> ImportListItem {
        try await sendJSON("POST", "\(Self.importLists)/\(id)/items/\(itemId)/ignore",
                           .object(["everywhere": .bool(everywhere)]))
    }

    // MARK: Exclusions

    public func importListExclusions(listId: Int? = nil) async throws -> [ImportListExclusion] {
        try await get("\(Self.importLists)/exclusions", query: listId.map { [URLQueryItem(name: "list_id", value: String($0))] } ?? [])
    }

    /// `list_id` nil = every list.
    public func addImportListExclusion(tmdbId: Int, kind: MediaKind, title: String?, year: Int?,
                                       listId: Int?) async throws -> ImportListExclusion {
        try await sendJSON("POST", "\(Self.importLists)/exclusions", .object([
            "tmdb_id": .int(tmdbId), "kind": .string(kind.rawValue),
            "title": title.map { .string($0) } ?? .null, "year": year.map { .int($0) } ?? .null,
            "list_id": listId.map { .int($0) } ?? .null,
        ]))
    }

    public func removeImportListExclusion(_ id: String) async throws {
        try await sendJSON("DELETE", "\(Self.importLists)/exclusions/\(id)")
    }

    // MARK: Rollup

    /// Activity › Tasks "Import lists" (admin).
    public func importListsSummary() async throws -> ImportListsSummary {
        try await get("/api/v1/system/import-lists/summary")
    }
}
