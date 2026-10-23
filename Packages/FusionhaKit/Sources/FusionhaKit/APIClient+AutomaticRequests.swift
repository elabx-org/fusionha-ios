import Foundation

/// Watchlists & lists (fusionha 0.4.226, requests revamp phase 10b slice 1):
/// the summary, Sync all, pause, the baseline, the unmatched review and the
/// admin's remembered matches. Same routes and bodies as the web's
/// `lib/api/automatic-requests.ts`, `unmatched.ts` and `list-matches.ts`.
/// Every `{id}` is a stable source id (`letterboxd-diary`, `list-38`, …).
extension APIClient {
    public func automaticRequestsSummary() async throws -> AutoSummary {
        try await get("/api/v1/me/automatic-requests/summary")
    }

    /// Checks every enabled source now (paused ones are left out). 429
    /// `rate_limited` with `sync_available_at` when nothing could be queued.
    public func syncAutomaticRequests() async throws -> AutoSyncResult {
        try await sendJSON("POST", "/api/v1/me/automatic-requests/sync")
    }

    /// Pause or resume one source (204). 403 when resuming a Plex watchlist an
    /// admin paused.
    public func pauseRequestSource(_ sourceId: String, paused: Bool) async throws {
        try await sendJSON("PUT", Self.sourcePath(sourceId, "pause"), .object(["paused": .bool(paused)]))
    }

    /// "What was on it when you started": `new` or `existing` (204).
    public func setRequestSourceBaseline(_ sourceId: String, baseline: String) async throws {
        try await sendJSON("PUT", Self.sourcePath(sourceId, "baseline"), .object(["baseline": .string(baseline)]))
    }

    /// Up to 100 titles the source couldn't match, oldest first.
    public func unmatchedItems(_ sourceId: String) async throws -> [UnmatchedItem] {
        try await get(Self.sourcePath(sourceId, "unmatched"))
    }

    /// Requests the picked TMDB title for one unmatched row and remembers the
    /// pick for everyone. A 202 (`queued`) means saved for the next check.
    public func resolveUnmatched(_ sourceId: String, itemId: Int, tmdbId: Int, kind: MediaKind) async throws -> ResolveResult {
        var req = request(method: "POST", path: Self.sourcePath(sourceId, "items/\(itemId)/resolve"), query: [])
        let body: SettingsJSON = .object(["tmdb_id": .int(tmdbId), "kind": .string(kind.rawValue)])
        req.httpBody = try Self.jsonBodyEncoder.encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await self.data(for: req)
        var result = try Self.decoder.decode(ResolveResult.self, from: data)
        result.queued = response.statusCode == 202
        return result
    }

    /// Stops the source offering the title again (204). Works while paused.
    public func ignoreUnmatched(_ sourceId: String, itemId: Int) async throws {
        try await sendJSON("POST", Self.sourcePath(sourceId, "items/\(itemId)/ignore"))
    }

    // MARK: Remembered matches (admin)

    public func listMatches() async throws -> [ListMatch] {
        try await get("/api/v1/list-matches")
    }

    /// The key goes in the body (a Plex key holds `/` and `:`). 204.
    public func forgetListMatch(provider: String, externalKey: String) async throws {
        try await sendJSON("POST", "/api/v1/list-matches/forget",
                           .object(["provider": .string(provider), "external_key": .string(externalKey)]))
    }

    static func sourcePath(_ sourceId: String, _ tail: String) -> String {
        "/api/v1/me/request-sources/\(sourceId)/\(tail)"
    }
}
