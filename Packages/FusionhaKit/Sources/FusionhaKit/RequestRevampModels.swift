import Foundation

// The requests revamp's read shapes (fusionha phases 1–7): who asked and who
// decided, where a request came from, each version's live lifecycle, the
// private thread, demand ("Me too") and the weekly quota.

public struct RequestPerson: Decodable, Sendable, Hashable {
    public let id: Int?
    public let displayName: String
    public let avatar: String?
    public let role: String?
}

/// "Approved by Elmer", or an automatic approval (`auto`, with its rule), or
/// a version an admin is already searching for (`watch`).
public struct RequestApprovedBy: Decodable, Sendable, Hashable {
    public let kind: String
    public let id: Int?
    public let displayName: String?
    public let avatar: String?
    public let rule: String?
}

public struct RequestSource: Decodable, Sendable, Hashable {
    /// MANUAL, PLEX_WATCHLIST, PLEX_LIST, LIST_FEED, LETTERBOXD_LIST / _RSS /
    /// _WATCHLIST / _CSV, …
    public let kind: String
    /// A list's name; only the owner and approvers get it (a joiner sees null).
    public let label: String?
    /// The Letterboxd username of a list or watchlist (0.4.213).
    public let owner: String?
    public let sourceId: Int?
    /// A "Request again" of a withdrawn automatic request (0.4.209).
    public let requestedAgain: Bool?

    public init(kind: String, label: String? = nil, owner: String? = nil, sourceId: Int? = nil, requestedAgain: Bool? = nil) {
        self.kind = kind
        self.label = label
        self.owner = owner
        self.sourceId = sourceId
        self.requestedAgain = requestedAgain
    }
}

public struct RequestLifecycleEntry: Decodable, Sendable, Hashable {
    public enum Step: String, Decodable, Sendable, Hashable {
        case requested, approved, searching, downloading, available, unreleased
        case declined, deferred, withdrawn, removed, paused

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Step(rawValue: raw) ?? .requested
        }
    }
    public let tier: QualityTier
    public let edition: String?
    public let step: Step
    public let progressPct: Int?
    public let nextRetryAt: String?
    /// The release day (`YYYY-MM-DD`) of an unreleased version.
    public let availableFrom: String?
    public let needsManualImport: Bool
    public let importing: Bool
    /// The download client's time left while downloading (0.4.216); nil when unknown.
    public let etaSeconds: Int?
    /// The release quality being downloaded ("WEBDL-1080p"), only while downloading (0.4.217).
    public let quality: String?

    public init(tier: QualityTier, edition: String? = nil, step: Step, progressPct: Int? = nil, nextRetryAt: String? = nil,
                availableFrom: String? = nil, needsManualImport: Bool = false, importing: Bool = false, etaSeconds: Int? = nil,
                quality: String? = nil) {
        self.tier = tier
        self.edition = edition
        self.step = step
        self.progressPct = progressPct
        self.nextRetryAt = nextRetryAt
        self.availableFrom = availableFrom
        self.needsManualImport = needsManualImport
        self.importing = importing
        self.etaSeconds = etaSeconds
        self.quality = quality
    }
}

public struct RequestThreadSummary: Decodable, Sendable, Hashable {
    public let unread: Int
    public let lastEventAt: String?
}

public struct RequestDemand: Decodable, Sendable, Hashable {
    public let count: Int
    public let joinedByMe: Bool
}

/// A request held by a rule (low or unknown free space).
public struct RequestHeld: Decodable, Sendable, Hashable {
    public let ruleId: Int
    public let label: String
    public let reason: String
}

/// `GET /api/v1/requests/counts`.
public struct RequestCounts: Decodable, Sendable, Hashable {
    public let inbox: Int
    public let waiting: Int
    public let active: Int
    public let available: Int
    public let declined: Int
    public let all: Int
    /// One bucket per automatic source over the caller's scope (MANUAL left
    /// out); nil from a server before 0.4.209.
    public let bySource: [RequestSourceCount]?
}

/// `GET /api/v1/requests/quota`: nil `limit` means unlimited.
public struct RequestQuota: Decodable, Sendable, Hashable {
    public let used: Int
    public let limit: Int?
    public let autoUsed: Int
    public let autoLimit: Int?
    public let resetsAt: String
    public let waiting: Int
}

/// One page of `GET /api/v1/requests` and the `X-Next-Cursor` for the next.
public struct RequestPage: Sendable {
    public let items: [MediaRequest]
    public let nextCursor: String?
}

extension APIClient {
    /// The requests list (`view` mine/all, `filter` active/available/declined/
    /// all/…, `sort` requested/last_event/title), cursor-paged.
    public func requestsPage(view: String, filter: String?, sort: String = "last_event", limit: Int = 30,
                             cursor: String? = nil, extra: [URLQueryItem] = []) async throws -> RequestPage {
        var query = [URLQueryItem(name: "view", value: view), URLQueryItem(name: "sort", value: sort),
                     URLQueryItem(name: "limit", value: String(limit))]
        if let filter { query.append(URLQueryItem(name: "filter", value: filter)) }
        query += extra
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let (body, response) = try await self.data(for: request(method: "GET", path: "/api/v1/requests", query: query))
        let items = try Self.decoder.decode([MediaRequest].self, from: body)
        let next = response.value(forHTTPHeaderField: "X-Next-Cursor").flatMap { $0.isEmpty ? nil : $0 }
        return RequestPage(items: items, nextCursor: next)
    }

    public func requestCounts(view: String, extra: [URLQueryItem] = []) async throws -> RequestCounts {
        try await get("/api/v1/requests/counts", query: [URLQueryItem(name: "view", value: view)] + extra)
    }

    public func requestQuota() async throws -> RequestQuota {
        try await get("/api/v1/requests/quota")
    }

    /// Plex deep links for fulfilled requests, by request id (only the ones Plex can open).
    public func requestPlexLinks(ids: [Int]) async throws -> [Int: String] {
        guard !ids.isEmpty else { return [:] }
        let raw: [String: String] = try await get("/api/v1/requests/plex-links",
                                                  query: ids.map { URLQueryItem(name: "ids", value: String($0)) })
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in Int(k).map { ($0, v) } })
    }

    /// A joiner leaves a request (the owner's request stays).
    public func leaveRequest(id: Int) async throws {
        let _: EmptyResponse = try await send("DELETE", "/api/v1/requests/\(id)/join", body: Optional<String>.none)
    }
}
