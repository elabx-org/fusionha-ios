import Foundation

// The item actions rail's dialogs (HeroActionRail → RenamePanel,
// EditionAliasesDialog, NumberingFixDialog). Same paths, query keys and
// bodies as the web app's lib/api/detail.ts and lib/api/edition-aliases.ts.
extension APIClient {
    // MARK: Rename

    /// `GET /api/v1/library/{id}/rename?version_id=&season=&include_blocked=1`.
    /// Blocked rows are always requested so a refused file is shown, not dropped.
    public func renamePreview(itemId: Int, versionId: Int? = nil, season: Int? = nil) async throws -> [RenamePreviewRow] {
        try await get("/api/v1/library/\(itemId)/rename", query: Self.renamePreviewQuery(versionId: versionId, season: season))
    }

    static func renamePreviewQuery(versionId: Int?, season: Int?) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        if let versionId { query.append(URLQueryItem(name: "version_id", value: String(versionId))) }
        if let season { query.append(URLQueryItem(name: "season", value: String(season))) }
        query.append(URLQueryItem(name: "include_blocked", value: "1"))
        return query
    }

    /// `POST /api/v1/library/{id}/rename`: `{}` for the whole title, else `version_id` / `season`.
    public func applyRename(itemId: Int, versionId: Int? = nil, season: Int? = nil) async throws -> RenameApplyResult {
        try await send("POST", "/api/v1/library/\(itemId)/rename", body: RenameApplyBody(versionId: versionId, season: season))
    }

    // MARK: Edition aliases

    public func editionAliases(itemId: Int) async throws -> [EditionAlias] {
        try await get("/api/v1/library/\(itemId)/edition-aliases")
    }

    public func addEditionAlias(itemId: Int, _ body: EditionAliasCreate) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/library/\(itemId)/edition-aliases", body: body)
    }

    public func deleteEditionAlias(itemId: Int, aliasId: Int) async throws {
        let _: EmptyResponse = try await send("DELETE", "/api/v1/library/\(itemId)/edition-aliases/\(aliasId)",
                                              body: Optional<String>.none)
    }

    // MARK: Episode numbering

    /// Dispatches the fix as a background run; poll `commandRun(id:)` for its summary.
    public func applyNumbering(itemId: Int, source: String?, expectedHash: String) async throws -> NumberingApplyDispatch {
        try await send("POST", "/api/v1/library/\(itemId)/numbering/apply",
                       body: NumberingApplyBody(source: source, expectedHash: expectedHash))
    }
}
