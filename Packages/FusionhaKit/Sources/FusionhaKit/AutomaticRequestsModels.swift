import Foundation

// MARK: - Automatic requests summary (fusionha 0.4.226, requests revamp phase 10b slice 1)

/// A source's one state word (ruling Q5). When several apply the server picks
/// the first of `gone`, `not_allowed`, `paused`, `off`, `syncing`, … An
/// unknown word reads as `retrying`.
public enum AutoSourceState: String, Sendable, Hashable, CaseIterable {
    case healthy, checking, syncing
    case partlyWorking = "partly_working"
    case notPublic = "not_public"
    case blocked, retrying
    case needsSignIn = "needs_sign_in"
    case notAllowed = "not_allowed"
    case paused, off, gone
    case notConnected = "not_connected"

    public init(wire: String?) {
        self = wire.flatMap(AutoSourceState.init(rawValue:)) ?? .retrying
    }
}

/// Which group a source sits in on the page. Unknown reads as `lists`.
public enum AutoSourceGroup: String, Sendable, Hashable, CaseIterable {
    case letterboxd, plex, lists
}

/// One source in page order (`AutoSourceRead`).
public struct AutoSource: Decodable, Sendable, Hashable, Identifiable {
    /// The stable id: `letterboxd-diary`, `letterboxd-watchlist`,
    /// `plex-watchlist` or `list-<row id>`.
    public let sourceId: String
    public let group: AutoSourceGroup
    public let state: AutoSourceState
    public let needsReview: Int
    /// The person paused it themselves and may resume it. False for an
    /// admin's pause and for a Plex list that only follows its watchlist's.
    public let paused: Bool

    public var id: String { sourceId }

    enum CodingKeys: String, CodingKey { case sourceId, group, state, needsReview, paused }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceId = try c.decode(String.self, forKey: .sourceId)
        group = AutoSourceGroup(rawValue: c.orDefault(.group, "lists")) ?? .lists
        state = AutoSourceState(wire: c.lenient(.state))
        needsReview = c.orDefault(.needsReview, 0)
        paused = c.orDefault(.paused, false)
    }

    public init(sourceId: String, group: AutoSourceGroup, state: AutoSourceState, needsReview: Int = 0, paused: Bool = false) {
        self.sourceId = sourceId
        self.group = group
        self.state = state
        self.needsReview = needsReview
        self.paused = paused
    }

    /// Paused by someone else (an admin, or the Plex watchlist a list
    /// follows): there is nothing for the person to resume.
    public var pausedByOthers: Bool { state == .paused && !paused }
}

/// `syncing`: the running passes summed.
public struct AutoSyncing: Decodable, Sendable, Hashable {
    public let done: Int
    public let total: Int
    /// Titles requested since the earliest running pass started.
    public let requested: Int

    enum CodingKeys: String, CodingKey { case done, total, requested }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        done = c.orDefault(.done, 0)
        total = c.orDefault(.total, 0)
        requested = c.orDefault(.requested, 0)
    }
}

/// `GET /api/v1/me/automatic-requests/summary`: one read for the Account
/// row, the page's source list and its default selection.
public struct AutoSummary: Decodable, Sendable, Hashable {
    public let requestedLast7d: Int
    public let needsReview: Int
    public let syncing: AutoSyncing?
    public let sources: [AutoSource]
    /// The first source with titles to review, else the first listed.
    public let defaultSourceId: String?

    enum CodingKeys: String, CodingKey { case requestedLast7d, needsReview, syncing, sources, defaultSourceId }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requestedLast7d = c.orDefault(.requestedLast7d, 0)
        needsReview = c.orDefault(.needsReview, 0)
        syncing = c.lenient(.syncing)
        sources = c.orDefault(.sources, [AutoSource]())
        defaultSourceId = c.lenient(.defaultSourceId)
    }

    public func source(_ id: String?) -> AutoSource? {
        guard let id else { return nil }
        return sources.first { $0.sourceId == id }
    }
}

/// `POST /me/automatic-requests/sync` (202): the stable ids queued.
public struct AutoSyncResult: Decodable, Sendable, Hashable {
    public let queued: [String]
    public let syncAvailableAt: String?

    enum CodingKeys: String, CodingKey { case queued, syncAvailableAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        queued = c.orDefault(.queued, [String]())
        syncAvailableAt = c.lenient(.syncAvailableAt)
    }
}

// MARK: - Unmatched review

/// `GET /me/request-sources/{id}/unmatched`: a title the source saw but could
/// not turn into a TMDB match.
public struct UnmatchedItem: Decodable, Sendable, Hashable, Identifiable {
    public let itemId: Int
    public let title: String
    public let year: Int?
    /// The Letterboxd film page, or nil.
    public let sourceUrl: String?
    /// `no_tmdb_link`, `not_found` or `ambiguous`.
    public let reason: String
    /// The search text to prefill (empty when the source gave no title).
    public let query: String

    public var id: Int { itemId }

    enum CodingKeys: String, CodingKey { case itemId, title, year, sourceUrl, reason, query }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try c.decode(Int.self, forKey: .itemId)
        title = c.orDefault(.title, "Untitled item")
        year = c.lenient(.year)
        sourceUrl = c.lenient(.sourceUrl)
        reason = c.orDefault(.reason, "not_found")
        query = c.orDefault(.query, "")
    }

    /// "Primal (2019)".
    public var label: String { year.map { "\(title) (\($0))" } ?? title }
}

/// `POST …/items/{item_id}/resolve`: 200 `{outcome, request_id}`, or 202
/// `{outcome: "QUEUED"}` when the choice is saved for the next check.
public struct ResolveResult: Decodable, Sendable, Hashable {
    /// `REQUESTED`, `JOINED`, `WAITING`, `OWNED`, `SKIPPED_POLICY` or `QUEUED`.
    public let outcome: String
    public let requestId: Int?
    /// The answer was a 202.
    public var queued = false

    enum CodingKeys: String, CodingKey { case outcome, requestId }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        outcome = c.orDefault(.outcome, "QUEUED")
        requestId = c.lenient(.requestId)
    }
}

// MARK: - Remembered matches (admin)

/// `GET /api/v1/list-matches`: a pick made in a resolve, shared by everyone.
public struct ListMatch: Decodable, Sendable, Hashable, Identifiable {
    /// `LETTERBOXD` or `PLEX`.
    public let provider: String
    public let externalKey: String
    /// The Letterboxd film page; nil for Plex.
    public let entryUrl: String?
    public let tmdbId: Int
    /// `movie` or `series`.
    public let kind: String
    public let title: String?
    public let year: Int?
    /// A username, or nil once that user is deleted.
    public let resolvedBy: String?
    public let resolvedAt: String?

    public var id: String { "\(provider):\(externalKey)" }

    enum CodingKeys: String, CodingKey {
        case provider, externalKey, entryUrl, tmdbId, kind, title, year, resolvedBy, resolvedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = c.orDefault(.provider, "LETTERBOXD")
        externalKey = try c.decode(String.self, forKey: .externalKey)
        entryUrl = c.lenient(.entryUrl)
        tmdbId = c.orDefault(.tmdbId, 0)
        kind = c.orDefault(.kind, "movie")
        title = c.lenient(.title)
        year = c.lenient(.year)
        resolvedBy = c.lenient(.resolvedBy)
        resolvedAt = c.lenient(.resolvedAt)
    }

    public var isPlex: Bool { provider == "PLEX" }
}
