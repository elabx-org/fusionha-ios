import Foundation

// What an import list did and what it will not do (fusionha 0.4.237):
// a run's items, the unmatched review, exclusions and the Tasks rollup.

/// `GET /import-lists/runs/{run_id}/items` and `/{id}/unmatched` (`ImportListItemRead`).
public struct ImportListItem: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let listId: Int
    public let externalKey: String
    public let tmdbId: Int?
    public let kind: String?
    public let title: String?
    public let year: Int?
    /// `ADDED`, `QUEUED`, `OWNED`, `EXCLUDED`, `IGNORED`, `UNMATCHED`, `SKIPPED_KIND`.
    public let outcome: String
    /// `no_match`, `ambiguous` or `no_year`.
    public let unmatchedReason: String?
    public let mediaItemId: Int?

    enum CodingKeys: String, CodingKey {
        case id, listId, externalKey, tmdbId, kind, title, year, outcome, unmatchedReason, mediaItemId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        listId = c.orDefault(.listId, 0)
        externalKey = c.orDefault(.externalKey, "")
        tmdbId = c.lenient(.tmdbId)
        kind = c.lenient(.kind)
        title = c.lenient(.title)
        year = c.lenient(.year)
        outcome = c.orDefault(.outcome, "UNMATCHED")
        unmatchedReason = c.lenient(.unmatchedReason)
        mediaItemId = c.lenient(.mediaItemId)
    }

    /// "Sinners (2025)", or "Untitled".
    public var label: String { ImportListCopy.titleWithYear(title, year) }
}

/// `GET /import-lists/exclusions`: a title import lists never add. Ids are
/// strings (`all-<n>` / `list-<n>`); `scope` is `all` or `list`.
public struct ImportListExclusion: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let scope: String
    public let listId: Int?
    public let tmdbId: Int?
    /// `movie` or `series`.
    public let kind: String
    public let title: String?
    public let year: Int?
    public let createdAt: String?

    enum CodingKeys: String, CodingKey { case id, scope, listId, tmdbId, kind, title, year, createdAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        scope = c.orDefault(.scope, "all")
        listId = c.lenient(.listId)
        tmdbId = c.lenient(.tmdbId)
        kind = c.orDefault(.kind, "movie")
        title = c.lenient(.title)
        year = c.lenient(.year)
        createdAt = c.lenient(.createdAt)
    }

    public var everyList: Bool { scope == "all" }
}

/// One list of the Tasks card (`ImportListsSummaryList`).
public struct ImportListsSummaryRow: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
    public let provider: String
    public let mediaKind: String
    /// `running`, `error` or `idle`.
    public let state: String
    public let counts: ImportListRunCounts
    public let itemCount: Int?
    public let lastCheckedAt: String?
    public let nextCheckAt: String?
    public let lastError: String?

    enum CodingKeys: String, CodingKey {
        case id, name, provider, mediaKind, state, counts, itemCount, lastCheckedAt, nextCheckAt, lastError
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = c.orDefault(.name, "Import list")
        provider = c.orDefault(.provider, "MDBLIST")
        mediaKind = c.orDefault(.mediaKind, "movie")
        state = c.orDefault(.state, "idle")
        counts = c.orDefault(.counts, ImportListRunCounts())
        itemCount = c.lenient(.itemCount)
        lastCheckedAt = c.lenient(.lastCheckedAt)
        nextCheckAt = c.lenient(.nextCheckAt)
        lastError = c.lenient(.lastError)
    }
}

/// `GET /api/v1/system/import-lists/summary`: Activity › Tasks "Import lists".
public struct ImportListsSummary: Decodable, Sendable, Hashable {
    public let running: Bool
    public let checked: Int
    public let total: Int
    public let nextRunAt: String?
    public let lists: [ImportListsSummaryRow]
    public let today: Today
    public let jobs: [SummaryJob]

    public struct Today: Decodable, Sendable, Hashable {
        public var added = 0, owned = 0, excluded = 0, errors = 0

        public init() {}

        enum CodingKeys: String, CodingKey { case added, owned, excluded, errors }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            added = c.orDefault(.added, 0)
            owned = c.orDefault(.owned, 0)
            excluded = c.orDefault(.excluded, 0)
            errors = c.orDefault(.errors, 0)
        }
    }

    enum CodingKeys: String, CodingKey { case running, checked, total, nextRunAt, lists, today, jobs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        running = c.orDefault(.running, false)
        checked = c.orDefault(.checked, 0)
        total = c.orDefault(.total, 0)
        nextRunAt = c.lenient(.nextRunAt)
        lists = c.orDefault(.lists, [ImportListsSummaryRow]())
        today = c.orDefault(.today, Today())
        jobs = c.orDefault(.jobs, [SummaryJob]())
    }
}
