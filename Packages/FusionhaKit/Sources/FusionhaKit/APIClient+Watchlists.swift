import Foundation

/// The signed-in user's automatic request sources (Account › Watchlists &
/// lists): the Plex watchlist & lists (phase 9) and Letterboxd (phase 10a).
/// Same routes and bodies as the web's `lib/api/plex-watchlist.ts` and
/// `lib/api/letterboxd.ts`.
extension APIClient {
    // MARK: Plex watchlist & lists

    public func plexWatchlist() async throws -> PlexWatchlistRead {
        try await get("/api/v1/me/plex-watchlist")
    }

    /// `PUT /me/plex-watchlist` with only the fields given. `requestExisting`
    /// only matters when turning on.
    public func updatePlexWatchlist(enabled: Bool? = nil, requestExisting: Bool? = nil,
                                    alsoUhd: Bool? = nil) async throws -> PlexWatchlistRead {
        var body: [String: SettingsJSON] = [:]
        if let enabled { body["enabled"] = .bool(enabled) }
        if let requestExisting { body["request_existing"] = .bool(requestExisting) }
        if let alsoUhd { body["also_uhd"] = .bool(alsoUhd) }
        return try await sendJSON("PUT", "/api/v1/me/plex-watchlist", .object(body))
    }

    /// Turns one Plex list on or off (409 `list_deleted`).
    public func setPlexList(listId: String, enabled: Bool, requestExisting: Bool? = nil) async throws -> PlexWatchlistRead {
        var body: [String: SettingsJSON] = ["enabled": .bool(enabled)]
        if let requestExisting { body["request_existing"] = .bool(requestExisting) }
        return try await sendJSON("PUT", "/api/v1/me/plex-watchlist/sources/\(listId)", .object(body))
    }

    /// Removes a list Plex deleted (409 `not_deleted` otherwise). Cancels nothing.
    public func removePlexList(listId: String) async throws {
        try await sendJSON("DELETE", "/api/v1/me/plex-watchlist/sources/\(listId)")
    }

    /// Checks every enabled source now (202). Once a minute: a second call is
    /// 429 `rate_limited` with `sync_available_at` (`APIError.retryAt`).
    public func syncPlexWatchlist() async throws -> PlexWatchlistRead {
        try await sendJSON("POST", "/api/v1/me/plex-watchlist/sync")
    }

    // MARK: Letterboxd profile

    public func letterboxd() async throws -> LetterboxdRead {
        try await get("/api/v1/me/letterboxd")
    }

    /// `PUT /me/letterboxd`: connects or updates the profile. A new username
    /// (or one with a `profile_error`) is checked before the answer, so this
    /// can take a while; a second probing PUT within 30 s is 429.
    public func updateLetterboxd(username: String, diaryEnabled: Bool? = nil, baseline: String? = nil,
                                 requestRewatches: Bool? = nil, alsoUhd: Bool? = nil) async throws -> LetterboxdRead {
        var body: [String: SettingsJSON] = ["username": .string(username)]
        if let diaryEnabled { body["diary_enabled"] = .bool(diaryEnabled) }
        if let baseline { body["baseline"] = .string(baseline) }
        if let requestRewatches { body["request_rewatches"] = .bool(requestRewatches) }
        if let alsoUhd { body["also_uhd"] = .bool(alsoUhd) }
        return try await sendSlow("PUT", "/api/v1/me/letterboxd", .object(body))
    }

    /// Removes the diary and own-watchlist sources; linked sources and requests stay.
    public func disconnectLetterboxd() async throws {
        try await sendJSON("DELETE", "/api/v1/me/letterboxd")
    }

    /// Follows (or stops following) the person's own public watchlist.
    public func followLetterboxdWatchlist(enabled: Bool, baseline: String? = nil) async throws -> LetterboxdRead {
        var body: [String: SettingsJSON] = ["enabled": .bool(enabled)]
        if let baseline { body["baseline"] = .string(baseline) }
        return try await sendJSON("PUT", "/api/v1/me/letterboxd/watchlist", .object(body))
    }

    /// Every Letterboxd source of the caller (202); 429 with `sync_available_at`.
    public func syncLetterboxd() async throws -> LbSyncResult {
        try await sendJSON("POST", "/api/v1/me/letterboxd/sync")
    }

    // MARK: Linked sources

    public func requestSources() async throws -> [LbSource] {
        try await get("/api/v1/me/request-sources")
    }

    /// Reads the first page (≤ 25 films). Once per 30 s (429 `retry_after`).
    public func previewRequestSource(_ target: LbSourceTarget) async throws -> LbSourcePreview {
        try await sendSlow("POST", "/api/v1/me/request-sources/preview", .object(Self.targetBody(target)))
    }

    /// Links a list or someone's watchlist (201). 409 `limit_reached`,
    /// `already_linked`, `use_watchlist_follow`.
    public func addRequestSource(_ target: LbSourceTarget, enabled: Bool = true,
                                 requestExisting: Bool = false) async throws -> LbSource {
        var body = Self.targetBody(target)
        body["enabled"] = .bool(enabled)
        body["request_existing"] = .bool(requestExisting)
        return try await sendSlow("POST", "/api/v1/me/request-sources", .object(body))
    }

    public func updateRequestSource(id: Int, enabled: Bool? = nil, label: String? = nil) async throws -> LbSource {
        var body: [String: SettingsJSON] = [:]
        if let enabled { body["enabled"] = .bool(enabled) }
        if let label { body["label"] = .string(label) }
        return try await sendJSON("PATCH", "/api/v1/me/request-sources/\(id)", .object(body))
    }

    /// Removing never cancels a request.
    public func deleteRequestSource(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/me/request-sources/\(id)")
    }

    public func syncRequestSource(id: Int) async throws -> LbSyncResult {
        try await sendJSON("POST", "/api/v1/me/request-sources/\(id)/sync")
    }

    // MARK: Helpers

    static func targetBody(_ target: LbSourceTarget) -> [String: SettingsJSON] {
        switch target {
        case .list(let url): return ["kind": "list", "url": .string(url)]
        case .watchlist(let username): return ["kind": "watchlist", "username": .string(username)]
        }
    }

    /// `sendJSON` with a minute's timeout: these calls read Letterboxd before
    /// they answer (and may first wait for a free slot).
    func sendSlow<T: Decodable>(_ method: String, _ path: String, _ body: SettingsJSON) async throws -> T {
        var req = request(method: method, path: path, query: [])
        req.httpBody = try Self.jsonBodyEncoder.encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        return try await perform(req)
    }
}
