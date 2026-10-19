import Foundation

// MARK: - Letterboxd and linked sources (fusionha requests revamp phase 10a)

/// `GET /api/v1/me/letterboxd`: the signed-in user's Letterboxd card.
public struct LetterboxdRead: Decodable, Sendable, Hashable {
    /// nil until a profile is connected.
    public let username: String?
    /// `not_connected`, `OK`, `PENDING`, `ERROR`, `INELIGIBLE`.
    public let status: String
    /// `profile_not_found`, `profile_private`, `unavailable`, or nil.
    public let profileError: String?
    /// `not_granted`, `ineligible`, or nil.
    public let reason: String?
    public let diary: LetterboxdDiary?
    public let alsoUhdAllowed: Bool
    public let watchlistFollow: LetterboxdWatchlistFollow
    public let canLinkLists: Bool
    public let maxLinkedLists: Int
    public let linkedCount: Int
    public let syncAvailableAt: String?

    enum CodingKeys: String, CodingKey {
        case username, status, profileError, reason, diary, alsoUhdAllowed, watchlistFollow
        case canLinkLists, maxLinkedLists, linkedCount, syncAvailableAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        username = c.lenient(.username)
        status = c.orDefault(.status, "not_connected")
        profileError = c.lenient(.profileError)
        reason = c.lenient(.reason)
        diary = c.lenient(.diary)
        alsoUhdAllowed = c.orDefault(.alsoUhdAllowed, false)
        watchlistFollow = c.orDefault(.watchlistFollow, LetterboxdWatchlistFollow.off)
        canLinkLists = c.orDefault(.canLinkLists, false)
        maxLinkedLists = c.orDefault(.maxLinkedLists, 5)
        linkedCount = c.orDefault(.linkedCount, 0)
        syncAvailableAt = c.lenient(.syncAvailableAt)
    }
}

/// `diary`: the RSS diary source.
public struct LetterboxdDiary: Decodable, Sendable, Hashable {
    public let enabled: Bool
    public let requestRewatches: Bool
    public let alsoUhd: Bool
    public let requestedCount: Int
    public let lastCheckedAt: String?
    public let nextCheckAt: String?
    public let baseline: String?
    /// 0.4.215: the running pass and the ledger counts (nil from older servers).
    public let sync: SourceSync?
    public let counts: SourceCounts?

    enum CodingKeys: String, CodingKey {
        case enabled, requestRewatches, alsoUhd, requestedCount, lastCheckedAt, nextCheckAt, baseline, sync, counts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = c.orDefault(.enabled, false)
        requestRewatches = c.orDefault(.requestRewatches, false)
        alsoUhd = c.orDefault(.alsoUhd, false)
        requestedCount = c.orDefault(.requestedCount, 0)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        nextCheckAt = c.lenient(.nextCheckAt)
        baseline = c.lenient(.baseline)
        sync = c.lenient(.sync)
        counts = c.lenient(.counts)
    }
}

/// `watchlist_follow`: following the person's own public watchlist.
public struct LetterboxdWatchlistFollow: Decodable, Sendable, Hashable {
    public let enabled: Bool
    public let status: String?
    public let requestedCount: Int
    public let lastCheckedAt: String?
    public let lastError: String?
    public let sourceId: Int?
    public let truncated: Bool
    public let itemCount: Int?
    public let nextCheckAt: String?
    public let sync: SourceSync?
    public let counts: SourceCounts?

    static let off = LetterboxdWatchlistFollow()

    private init() {
        enabled = false
        status = nil
        requestedCount = 0
        lastCheckedAt = nil
        lastError = nil
        sourceId = nil
        truncated = false
        itemCount = nil
        nextCheckAt = nil
        sync = nil
        counts = nil
    }

    enum CodingKeys: String, CodingKey {
        case enabled, status, requestedCount, lastCheckedAt, lastError, sourceId, truncated, itemCount
        case nextCheckAt, sync, counts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = c.orDefault(.enabled, false)
        status = c.lenient(.status)
        requestedCount = c.orDefault(.requestedCount, 0)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        lastError = c.lenient(.lastError)
        sourceId = c.lenient(.sourceId)
        truncated = c.orDefault(.truncated, false)
        itemCount = c.lenient(.itemCount)
        nextCheckAt = c.lenient(.nextCheckAt)
        sync = c.lenient(.sync)
        counts = c.lenient(.counts)
    }
}

/// `GET /api/v1/me/request-sources` rows (`LbSourceRead`).
public struct LbSource: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    /// `LETTERBOXD_RSS`, `LETTERBOXD_WATCHLIST`, `LETTERBOXD_LIST`, `LETTERBOXD_CSV`.
    public let kind: String
    public let label: String?
    public let url: String?
    /// The Letterboxd username of the list or watchlist.
    public let owner: String?
    public let isSelf: Bool
    public let enabled: Bool
    /// `PENDING`, `OK`, `DEGRADED`, `BLOCKED`, `PRIVATE`, `ERROR`, `INELIGIBLE`.
    public let status: String?
    public let lastCheckedAt: String?
    public let nextCheckAt: String?
    public let retryAt: String?
    public let lastError: String?
    public let viaFlaresolverr: Bool
    public let requestedCount: Int
    public let itemCount: Int?
    public let baseline: String?
    public let truncated: Bool
    public let sync: SourceSync?
    public let counts: SourceCounts?

    enum CodingKeys: String, CodingKey {
        case id, kind, label, url, owner, isSelf, enabled, status, lastCheckedAt, nextCheckAt, retryAt
        case lastError, viaFlaresolverr, requestedCount, itemCount, baseline, truncated, sync, counts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        kind = c.orDefault(.kind, "")
        label = c.lenient(.label)
        url = c.lenient(.url)
        owner = c.lenient(.owner)
        isSelf = c.orDefault(.isSelf, false)
        enabled = c.orDefault(.enabled, false)
        status = c.lenient(.status)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        nextCheckAt = c.lenient(.nextCheckAt)
        retryAt = c.lenient(.retryAt)
        lastError = c.lenient(.lastError)
        viaFlaresolverr = c.orDefault(.viaFlaresolverr, false)
        requestedCount = c.orDefault(.requestedCount, 0)
        itemCount = c.lenient(.itemCount)
        baseline = c.lenient(.baseline)
        truncated = c.orDefault(.truncated, false)
        sync = c.lenient(.sync)
        counts = c.lenient(.counts)
    }

    public var isList: Bool { kind == "LETTERBOXD_LIST" }

    /// A list, or someone else's watchlist: these count toward `max_linked_lists`.
    public var isLinked: Bool { isList || (kind == "LETTERBOXD_WATCHLIST" && !isSelf) }

    /// `@owner · List name` or `@owner · watchlist` (web `sourceTitle`).
    public var title: String {
        let who = "@\(owner ?? "")"
        return isList ? "\(who) · \(label ?? "List")" : "\(who) · watchlist"
    }
}

/// `POST /me/letterboxd/sync` and `/me/request-sources/{id}/sync` (202).
public struct LbSyncResult: Decodable, Sendable {
    public let queued: [Int]?
    public let syncAvailableAt: String?
}

/// `POST /me/request-sources/preview`: the first page of a list or watchlist.
public struct LbSourcePreview: Decodable, Sendable, Hashable {
    public let title: String?
    public let owner: String?
    public let itemCount: Int?
    /// At most 25.
    public let items: [LbPreviewItem]

    enum CodingKeys: String, CodingKey { case title, owner, itemCount, items }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.lenient(.title)
        owner = c.lenient(.owner)
        itemCount = c.lenient(.itemCount)
        items = c.orDefault(.items, [LbPreviewItem]())
    }
}

public struct LbPreviewItem: Decodable, Sendable, Hashable {
    public let title: String
    public let year: Int?
    public let inLibrary: Bool

    enum CodingKeys: String, CodingKey { case title, year, inLibrary }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.orDefault(.title, "")
        year = c.lenient(.year)
        inLibrary = c.orDefault(.inLibrary, false)
    }
}

/// What to add: a list by address, or someone's watchlist by username.
public enum LbSourceTarget: Sendable, Hashable {
    case list(url: String)
    case watchlist(username: String)

    public var kind: String {
        switch self {
        case .list: return "list"
        case .watchlist: return "watchlist"
        }
    }
}
