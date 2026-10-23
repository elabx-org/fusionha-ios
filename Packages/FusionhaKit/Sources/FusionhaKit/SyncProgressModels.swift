import Foundation

// MARK: - Sync progress (fusionha 0.4.215, approved mock `requests-sync-progress`)

/// `sync` (`SourceSyncRead`) on every Plex / Letterboxd source read: `running`
/// while a pass is in flight, `error` from the source's status. `checked` /
/// `total` / `startedAt` are set only while running; `total` stays nil until
/// the pass has read the source. Older servers send no block (nil).
public struct SourceSync: Decodable, Sendable, Hashable {
    /// `idle`, `running` or `error`; anything else reads as `idle`.
    public let state: String
    public let checked: Int?
    public let total: Int?
    public let startedAt: String?

    public init(state: String, checked: Int? = nil, total: Int? = nil, startedAt: String? = nil) {
        self.state = state
        self.checked = checked
        self.total = total
        self.startedAt = startedAt
    }

    enum CodingKeys: String, CodingKey { case state, checked, total, startedAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = c.orDefault(.state, "idle")
        checked = c.lenient(.checked)
        total = c.lenient(.total)
        startedAt = c.lenient(.startedAt)
    }

    public var isRunning: Bool { state == "running" }
}

/// `counts` (`SourceCountsRead`): the ledger outcomes of one source.
/// requested = REQUESTED + JOINED, owned = in the library, queued = over the
/// per-check cap, waiting = over the weekly quota, skipped = policy /
/// declined / withdrawn / ignored, unmatched = waiting for a review (its own
/// bucket since 0.4.226), baseline = noted on the first check.
public struct SourceCounts: Decodable, Sendable, Hashable {
    public let requested: Int
    public let owned: Int
    public let queued: Int
    public let waiting: Int
    public let skipped: Int
    public let unmatched: Int
    public let baseline: Int

    public static let empty = SourceCounts()

    public init(requested: Int = 0, owned: Int = 0, queued: Int = 0, waiting: Int = 0, skipped: Int = 0,
                unmatched: Int = 0, baseline: Int = 0) {
        self.requested = requested
        self.owned = owned
        self.queued = queued
        self.waiting = waiting
        self.skipped = skipped
        self.unmatched = unmatched
        self.baseline = baseline
    }

    enum CodingKeys: String, CodingKey { case requested, owned, queued, waiting, skipped, unmatched, baseline }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requested = c.orDefault(.requested, 0)
        owned = c.orDefault(.owned, 0)
        queued = c.orDefault(.queued, 0)
        waiting = c.orDefault(.waiting, 0)
        skipped = c.orDefault(.skipped, 0)
        unmatched = c.orDefault(.unmatched, 0)
        baseline = c.orDefault(.baseline, 0)
    }
}

/// `GET /api/v1/system/request-sources/summary` (admin): the cross-user rollup
/// behind Activity › Tasks › "Watchlists & lists". Sources come running
/// first, then error, then idle.
public struct RequestSourcesSummary: Decodable, Sendable, Hashable {
    public let runningSources: Int
    public let checked: Int
    public let total: Int
    public let nextRunAt: String?
    public let sources: [SummarySource]
    public let today: SummaryToday
    public let jobs: [SummaryJob]

    enum CodingKeys: String, CodingKey { case runningSources, checked, total, nextRunAt, sources, today, jobs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runningSources = c.orDefault(.runningSources, 0)
        checked = c.orDefault(.checked, 0)
        total = c.orDefault(.total, 0)
        nextRunAt = c.lenient(.nextRunAt)
        sources = c.orDefault(.sources, [SummarySource]())
        today = c.orDefault(.today, SummaryToday())
        jobs = c.orDefault(.jobs, [SummaryJob]())
    }
}

/// One enabled automatic source of any user (`SummarySourceRead`).
public struct SummarySource: Decodable, Sendable, Hashable, Identifiable {
    public let sourceId: Int
    public let userId: Int
    /// The fusionha username.
    public let owner: String
    /// `PLEX_WATCHLIST`, `PLEX_LIST`, `LETTERBOXD_WATCHLIST`, `LETTERBOXD_RSS`, `LETTERBOXD_LIST`.
    public let kind: String
    public let label: String?
    /// `idle`, `running` or `error`.
    public let state: String
    public let checked: Int?
    public let total: Int?
    public let startedAt: String?
    public let counts: SourceCounts
    public let lastCheckedAt: String?
    public let nextCheckAt: String?
    public let lastError: String?
    /// 0.4.226: the source's stable string id (`letterboxd-diary`, `list-38`, …).
    public let stableId: String?

    public var id: Int { sourceId }

    enum CodingKeys: String, CodingKey {
        case sourceId, userId, owner, kind, label, state, checked, total, startedAt, counts
        case lastCheckedAt, nextCheckAt, lastError, stableId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceId = try c.decode(Int.self, forKey: .sourceId)
        userId = c.orDefault(.userId, 0)
        owner = c.orDefault(.owner, "")
        kind = c.orDefault(.kind, "")
        label = c.lenient(.label)
        state = c.orDefault(.state, "idle")
        checked = c.lenient(.checked)
        total = c.lenient(.total)
        startedAt = c.lenient(.startedAt)
        counts = c.orDefault(.counts, SourceCounts.empty)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        nextCheckAt = c.lenient(.nextCheckAt)
        lastError = c.lenient(.lastError)
        stableId = c.lenient(.stableId)
    }

    /// The same shape as a source read's `sync`, for the shared bar and percent.
    public var sync: SourceSync { SourceSync(state: state, checked: checked, total: total, startedAt: startedAt) }
}

/// Ledger rows decided since 00:00 UTC; `errors` = sources in error checked today.
public struct SummaryToday: Decodable, Sendable, Hashable {
    public let requested: Int
    public let owned: Int
    public let skipped: Int
    public let errors: Int

    public init(requested: Int = 0, owned: Int = 0, skipped: Int = 0, errors: Int = 0) {
        self.requested = requested
        self.owned = owned
        self.skipped = skipped
        self.errors = errors
    }

    enum CodingKeys: String, CodingKey { case requested, owned, skipped, errors }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        requested = c.orDefault(.requested, 0)
        owned = c.orDefault(.owned, 0)
        skipped = c.orDefault(.skipped, 0)
        errors = c.orDefault(.errors, 0)
    }
}

/// One of the three background jobs behind the sources (`SummaryJobRead`).
public struct SummaryJob: Decodable, Sendable, Hashable {
    public let name: String
    public let lastRunAt: String?
    public let lastStatus: String?
    public let running: Bool
    public let nextRunAt: String?

    enum CodingKeys: String, CodingKey { case name, lastRunAt, lastStatus, running, nextRunAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.orDefault(.name, "")
        lastRunAt = c.lenient(.lastRunAt)
        lastStatus = c.lenient(.lastStatus)
        running = c.orDefault(.running, false)
        nextRunAt = c.lenient(.nextRunAt)
    }
}
