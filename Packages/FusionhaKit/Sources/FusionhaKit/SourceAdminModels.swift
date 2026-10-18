import Foundation

// Admin, read-only: what one person's automatic request sources have done
// (fusionha 0.4.209 Plex watchlist & lists, 0.4.213 Letterboxd;
// `GET /users/{id}/plex-watchlist`, `GET /users/{id}/request-sources`, the
// Users-list summaries and the approver stats). The web's
// `WatchlistStatusDialog` and `LetterboxdStatusDialog`.

/// The ledger's outcome counts. The decoder camel-cases dictionary keys
/// (`SKIPPED_POLICY` → `skippedPolicy`), so lookups compare letters only.
public struct SourceOutcomes: Decodable, Sendable, Hashable {
    public let counts: [String: Int]

    public init(_ counts: [String: Int]) {
        var normal: [String: Int] = [:]
        for (k, v) in counts { normal[Self.normal(k)] = v }
        self.counts = normal
    }

    public init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode([String: Int].self))
    }

    private static func normal(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: "").lowercased()
    }

    /// `REQUESTED`, `SKIPPED_POLICY`, …
    public subscript(_ key: String) -> Int { counts[Self.normal(key)] ?? 0 }

    public var total: Int { counts.values.reduce(0, +) }
}

/// One of the latest ledger rows.
public struct SourceLedgerRow: Decodable, Sendable, Hashable {
    public let title: String?
    public let year: Int?
    public let outcome: String
    public let firstSeenAt: String?
}

// MARK: Plex watchlist & lists

public struct PlexWatchlistAdmin: Decodable, Sendable {
    public struct Source: Decodable, Sendable, Hashable {
        /// PLEX_WATCHLIST · PLEX_LIST
        public let kind: String
        public let listId: String?
        public let name: String
        public let visibility: String?
        public let enabled: Bool
        public let lastCheckedAt: String?
        public let requestedCount: Int
        public let errorCount: Int?
        public let lastError: String?
        /// A list past the 50-page read cap: only the first part is checked.
        public let truncated: Bool?
    }

    public let reason: String?
    public let lastCheckedAt: String?
    public let nextCheckAt: String?
    public let lastError: String?
    public let requestedTotal: Int?
    public let paused: Bool?
    public let consecutiveFailures: Int?
    /// The token itself is never sent.
    public let plexTokenSet: Bool?
    public let outcomes: SourceOutcomes?
    public let recent: [SourceLedgerRow]?
    public let sources: [Source]?
}

/// `GET /users/plex-watchlist/summary`: one row per user.
public struct PlexWatchlistSummaryRow: Decodable, Sendable, Hashable {
    /// healthy · checking · needs_sign_in · token_invalid · error · paused ·
    /// allowed_off · not_allowed · plex_only · ineligible
    public let userId: Int
    public let state: String
    public let sourceCount: Int
    public let requestedCount: Int
    public let lastCheckedAt: String?
}

// MARK: Letterboxd

public struct LetterboxdAdmin: Decodable, Sendable {
    public struct Me: Decodable, Sendable {
        public struct Diary: Decodable, Sendable {
            public let enabled: Bool
            public let lastCheckedAt: String?
            public let nextCheckAt: String?
        }
        public let username: String?
        public let status: String?
        public let profileError: String?
        public let reason: String?
        public let diary: Diary?
        public let canLinkLists: Bool?
        public let maxLinkedLists: Int?
        public let linkedCount: Int?
    }

    public struct Source: Decodable, Sendable, Hashable, Identifiable {
        public let id: Int
        /// LETTERBOXD_RSS · _WATCHLIST · _LIST · _CSV
        public let kind: String
        public let label: String?
        public let owner: String?
        public let isSelf: Bool?
        public let enabled: Bool
        /// PENDING · OK · DEGRADED · BLOCKED · PRIVATE · ERROR · INELIGIBLE
        public let status: String
        public let lastCheckedAt: String?
        public let lastError: String?
        public let requestedCount: Int
    }

    public let me: Me
    public let sources: [Source]
    public let consecutiveFailures: Int?
    public let outcomes: SourceOutcomes?
    public let recent: [SourceLedgerRow]?
    public let flaresolverrConfigured: Bool?
}

/// `GET /users/letterboxd/summary`: one row per user.
public struct LetterboxdSummaryRow: Decodable, Sendable, Hashable {
    public let userId: Int
    public let username: String?
    /// not_connected · healthy · attention · cant_read · not_allowed
    public let state: String
    public let diaryEnabled: Bool
    public let lastCheckedAt: String?
    public let requestedCount: Int
    public let linkedCount: Int
    public let maxLinkedLists: Int?
    public let blockedCount: Int
    public let degradedCount: Int
    public let consecutiveFailures: Int?
}

// MARK: Stats and FlareSolverr

/// `GET /requests/watchlist-stats`: people with a Plex source turned on.
public struct WatchlistStats: Decodable, Sendable {
    public let optedInUsers: Int
}

/// `GET /requests/letterboxd-stats`.
public struct LetterboxdStats: Decodable, Sendable {
    public let connectedUsers: Int
    public let linkedSources: Int
}

/// `POST /settings/test-flaresolverr`: `reason` ∈ unreachable · timeout ·
/// failed · not_configured when `ok` is false.
public struct FlareSolverrTest: Decodable, Sendable, Hashable {
    public let ok: Bool
    public let elapsedMs: Int?
    public let error: String?
    public let reason: String?

    public init(ok: Bool, elapsedMs: Int? = nil, error: String? = nil, reason: String? = nil) {
        self.ok = ok
        self.elapsedMs = elapsedMs
        self.error = error
        self.reason = reason
    }
}

extension APIClient {
    public func adminPlexWatchlist(userId: Int) async throws -> PlexWatchlistAdmin {
        try await get("/api/v1/users/\(userId)/plex-watchlist")
    }

    /// Pauses (token cleared) or resumes a person's watchlist.
    public func setPlexWatchlistPaused(userId: Int, _ paused: Bool) async throws {
        try await sendJSON("PATCH", "/api/v1/users/\(userId)/plex-watchlist", .object(["paused": .bool(paused)]))
    }

    public func plexWatchlistSummary() async throws -> [PlexWatchlistSummaryRow] {
        try await get("/api/v1/users/plex-watchlist/summary")
    }

    public func adminLetterboxd(userId: Int) async throws -> LetterboxdAdmin {
        try await get("/api/v1/users/\(userId)/request-sources")
    }

    public func letterboxdSummary() async throws -> [LetterboxdSummaryRow] {
        try await get("/api/v1/users/letterboxd/summary")
    }

    public func watchlistStats() async throws -> WatchlistStats { try await get("/api/v1/requests/watchlist-stats") }
    public func letterboxdStats() async throws -> LetterboxdStats { try await get("/api/v1/requests/letterboxd-stats") }

    /// Tests the SAVED address only (no body), so it can't probe other hosts.
    public func testFlareSolverr() async throws -> FlareSolverrTest {
        try await sendJSON("POST", "/api/v1/settings/test-flaresolverr")
    }
}
