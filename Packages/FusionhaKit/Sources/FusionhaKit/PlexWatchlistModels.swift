import Foundation

// MARK: - Plex watchlist & lists (fusionha requests revamp phase 9)

/// `GET /api/v1/me/plex-watchlist`: the signed-in user's Plex watchlist card.
/// Every field decodes leniently, so a newer server never breaks the screen.
public struct PlexWatchlistRead: Decodable, Sendable, Hashable {
    public let eligible: Bool
    /// The effective `auto_request_plex_watchlist` grant.
    public let granted: Bool
    /// `not_plex_user`, `not_granted`, `ineligible`, `disabled`, `needs_sign_in`,
    /// `token_invalid`, `error`, or nil. Unknown values read as `error`.
    public let reason: String?
    /// The watchlist itself (lists have their own switches).
    public let enabled: Bool
    /// Display only; `PENDING` means checking.
    public let status: String?
    public let lastCheckedAt: String?
    public let lastSuccessAt: String?
    public let nextCheckAt: String?
    /// A user-safe sentence.
    public let lastError: String?
    public let alsoUhd: Bool
    public let alsoUhdAllowed: Bool
    public let itemCount: Int?
    /// REQUESTED + JOINED on the watchlist.
    public let requestedCount: Int
    public let seenCount: Int
    public let baselineCount: Int
    public let waitingCount: Int
    /// Distinct requests across every Plex source.
    public let requestedTotal: Int
    /// Set while Sync now is in its one-minute cooldown.
    public let syncAvailableAt: String?
    /// For 24 h after the first check of a newly turned-on watchlist.
    public let firstCheck: PlexWatchlistFirstCheck?
    public let lists: PlexListsRead
    /// 0.4.215: the watchlist's running pass and ledger counts (nil from older servers).
    public let sync: SourceSync?
    public let counts: SourceCounts?

    enum CodingKeys: String, CodingKey {
        case eligible, granted, reason, enabled, status, lastCheckedAt, lastSuccessAt, nextCheckAt, lastError
        case options, alsoUhdAllowed, itemCount, requestedCount, seenCount, baselineCount, waitingCount
        case requestedTotal, syncAvailableAt, firstCheck, lists, sync, counts
    }

    private struct Options: Decodable { let alsoUhd: Bool? }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eligible = c.orDefault(.eligible, false)
        granted = c.orDefault(.granted, false)
        reason = c.lenient(.reason)
        enabled = c.orDefault(.enabled, false)
        status = c.lenient(.status)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        lastSuccessAt = c.lenient(.lastSuccessAt)
        nextCheckAt = c.lenient(.nextCheckAt)
        lastError = c.lenient(.lastError)
        let options: Options? = c.lenient(.options)
        alsoUhd = options?.alsoUhd ?? false
        alsoUhdAllowed = c.orDefault(.alsoUhdAllowed, false)
        itemCount = c.lenient(.itemCount)
        requestedCount = c.orDefault(.requestedCount, 0)
        seenCount = c.orDefault(.seenCount, 0)
        baselineCount = c.orDefault(.baselineCount, 0)
        waitingCount = c.orDefault(.waitingCount, 0)
        requestedTotal = c.orDefault(.requestedTotal, 0)
        syncAvailableAt = c.lenient(.syncAvailableAt)
        firstCheck = c.lenient(.firstCheck)
        lists = c.orDefault(.lists, PlexListsRead(state: "unknown", sources: []))
        sync = c.lenient(.sync)
        counts = c.lenient(.counts)
    }
}

/// `first_check`: what the first check after turning the watchlist on did.
public struct PlexWatchlistFirstCheck: Decodable, Sendable, Hashable {
    /// `NEW` (only new additions) or `EXISTING` (also what was already on it).
    public let baseline: String
    public let baselineCount: Int
    public let requestedCount: Int
    public let remaining: Int

    enum CodingKeys: String, CodingKey { case baseline, baselineCount, requestedCount, remaining }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseline = c.orDefault(.baseline, "NEW")
        baselineCount = c.orDefault(.baselineCount, 0)
        requestedCount = c.orDefault(.requestedCount, 0)
        remaining = c.orDefault(.remaining, 0)
    }
}

/// `lists`: the user's own Plex lists. `state` ∈ `ok`, `loading`, `empty`,
/// `managed`, `error`, `unknown`.
public struct PlexListsRead: Decodable, Sendable, Hashable {
    public let state: String
    public let sources: [PlexListSource]

    public init(state: String, sources: [PlexListSource]) {
        self.state = state
        self.sources = sources
    }

    enum CodingKeys: String, CodingKey { case state, sources }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = c.orDefault(.state, "unknown")
        sources = c.orDefault(.sources, [PlexListSource]())
    }
}

/// One Plex list with its own switch.
public struct PlexListSource: Decodable, Sendable, Hashable, Identifiable {
    public let listId: String
    public let name: String
    /// `PUBLIC`, `PLEX_USERS`, `FRIENDS_OF_FRIENDS`, `FRIENDS`, `PRIVATE`, or nil.
    public let visibility: String?
    public let itemCount: Int?
    public let enabled: Bool
    public let baseline: String?
    public let lastCheckedAt: String?
    public let requestedCount: Int
    /// Plex deleted the list: offer Remove (cancels nothing).
    public let deleted: Bool
    public let error: String?
    public let sync: SourceSync?
    public let counts: SourceCounts?

    public var id: String { listId }

    enum CodingKeys: String, CodingKey {
        case listId, name, visibility, itemCount, enabled, baseline, lastCheckedAt, requestedCount, deleted, error
        case sync, counts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        listId = c.orDefault(.listId, "")
        name = c.orDefault(.name, "Plex list")
        visibility = c.lenient(.visibility)
        itemCount = c.lenient(.itemCount)
        enabled = c.orDefault(.enabled, false)
        baseline = c.lenient(.baseline)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        requestedCount = c.orDefault(.requestedCount, 0)
        deleted = c.orDefault(.deleted, false)
        error = c.lenient(.error)
        sync = c.lenient(.sync)
        counts = c.lenient(.counts)
    }
}
