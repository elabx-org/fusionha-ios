import Foundation

/// One version a report is about (`VersionRefRead`).
public struct IssueVersionRef: Decodable, Sendable, Hashable {
    public let id: Int?
    public let tier: QualityTier?
    public let edition: String?

    public init(id: Int? = nil, tier: QualityTier? = nil, edition: String? = nil) {
        self.id = id
        self.tier = tier
        self.edition = edition
    }
}

/// The reporter-safe summary of a check (`VerdictSummaryRead`).
public struct IssueVerdictSummary: Decodable, Sendable, Hashable {
    public let text: String
    public let missingPct: Double?
    /// `needs_decypharr`: the client can't check files.
    public let code: String?
    public let verified: Bool?

    public init(text: String, missingPct: Double? = nil, code: String? = nil, verified: Bool? = false) {
        self.text = text
        self.missingPct = missingPct
        self.code = code
        self.verified = verified
    }
}

/// One fix the viewer may be offered (`IssueChoiceRead`).
public struct IssueChoice: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let label: String
    public let sub: String?
    /// allowed · paused · not_enabled · no_access · rate_limited · admin_only
    public let permission: String?
    public let left: Int?
    public let dailyLimit: Int?

    public init(id: String, label: String, sub: String? = nil, permission: String? = "allowed",
                left: Int? = nil, dailyLimit: Int? = nil) {
        self.id = id
        self.label = label
        self.sub = sub
        self.permission = permission
        self.left = left
        self.dailyLimit = dailyLimit
    }

    public var allowed: Bool { (permission ?? "allowed") == "allowed" }
}

/// A keep-old fix's progress, in fixed reporter-safe sentences.
public struct IssueFixProgress: Decodable, Sendable, Hashable {
    public struct Step: Decodable, Sendable, Hashable {
        public let key: String
        public let label: String
        /// done · now · todo · fail
        public let state: String
        public let sub: String?

        public init(key: String, label: String, state: String, sub: String? = nil) {
            self.key = key
            self.label = label
            self.state = state
            self.sub = sub
        }
    }
    public let steps: [Step]
    public let keepsCurrent: Bool
    public let confirmer: String?

    public init(steps: [Step], keepsCurrent: Bool, confirmer: String? = nil) {
        self.steps = steps
        self.keepsCurrent = keepsCurrent
        self.confirmer = confirmer
    }
}

/// One per-version report inside an issue (`IssueReportRead`).
public struct IssueReport: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let problem: String
    public let version: IssueVersionRef
    public let scope: String?
    public let season: Int?
    public let episode: Int?
    /// OPEN · CHECKING · FIXING · AWAITING_USER · NEEDS_ADMIN · RESOLVED
    public let state: String
    public let verdictSummary: IssueVerdictSummary
    public let choices: [IssueChoice]
    public let resolution: String?
    public let createdAt: String?
    public let resolvedAt: String?
    public let mine: Bool?
    public let fileChecks: Bool?
    /// second_check · inconclusive · plays_fine · autofix_off · paused · kept · replacing · held · swapped
    public let situation: String?
    public let checkGeneration: Int?
    public let reporter: RequestPerson?
    public let fixProgress: IssueFixProgress?
    public let fixBusy: Bool?
    // Managers only.
    public let stagedCopy: IssueStagedCopy?
    public let guardState: String?
    public let diagnosis: IssueJSON?
    /// The diagnosis flattened to `{key, value}` rows (0.4.203).
    public var evidenceList: [IssueEvidenceItem]? = nil
    public let client: IssueClient?

    public init(id: Int, problem: String, version: IssueVersionRef = IssueVersionRef(), scope: String? = "item",
                season: Int? = nil, episode: Int? = nil, state: String, verdictSummary: IssueVerdictSummary,
                choices: [IssueChoice] = [], resolution: String? = nil, createdAt: String? = nil,
                resolvedAt: String? = nil, mine: Bool? = false, fileChecks: Bool? = false, situation: String? = nil,
                checkGeneration: Int? = 0, reporter: RequestPerson? = nil, fixProgress: IssueFixProgress? = nil,
                fixBusy: Bool? = false, stagedCopy: IssueStagedCopy? = nil, guardState: String? = nil,
                diagnosis: IssueJSON? = nil, client: IssueClient? = nil) {
        self.id = id
        self.problem = problem
        self.version = version
        self.scope = scope
        self.season = season
        self.episode = episode
        self.state = state
        self.verdictSummary = verdictSummary
        self.choices = choices
        self.resolution = resolution
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.mine = mine
        self.fileChecks = fileChecks
        self.situation = situation
        self.checkGeneration = checkGeneration
        self.reporter = reporter
        self.fixProgress = fixProgress
        self.fixBusy = fixBusy
        self.stagedCopy = stagedCopy
        self.guardState = guardState
        self.diagnosis = diagnosis
        self.client = client
    }
}

/// One manager Evidence row as the server words it.
public struct IssueEvidenceItem: Decodable, Sendable, Hashable {
    public let key: String
    public let value: String
}

/// `POST /api/v1/issues` (fusionha phase 6: a problem and a version).
public struct IssueReportBody: Encodable, Sendable {
    public let mediaItemId: Int
    public let problem: String
    public let versionId: Int?
    public let scope: String
    public let season: Int?
    public let episode: Int?
    public let description: String?

    public init(mediaItemId: Int, problem: String, versionId: Int?, scope: String, season: Int?, episode: Int?,
                description: String?) {
        self.mediaItemId = mediaItemId
        self.problem = problem
        self.versionId = versionId
        self.scope = scope
        self.season = season
        self.episode = episode
        self.description = description
    }
}

/// A filed report: `created` on 201, false when it joined an open issue.
public struct IssueFiled: Sendable {
    public let issue: MediaIssue
    public let created: Bool
}

/// One page of `GET /issues` and its next cursor.
public struct IssuePage: Sendable {
    public let items: [MediaIssue]
    public let nextCursor: String?
}

struct IssueActionBody: Encodable { let action: String }
struct IssueReopenBody: Encodable { let reportId: Int?; let note: String? }
struct IssueAskAdminBody: Encodable { let reportId: Int; let note: String? }
struct IssueMessageBody: Encodable { let body: String }
public struct IssueActionResult: Decodable, Sendable {
    public let issue: MediaIssue?
    public let requestId: Int?
}

extension APIClient {
    /// Keyset-paged issues: a reporter sees their own, a manager every one (`mine` narrows).
    public func issuesPage(mine: Bool = false, state: String? = nil, mediaItemId: Int? = nil, limit: Int = 50,
                           cursor: String? = nil) async throws -> IssuePage {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if mine { query.append(URLQueryItem(name: "mine", value: "true")) }
        if let state { query.append(URLQueryItem(name: "state", value: state)) }
        if let mediaItemId { query.append(URLQueryItem(name: "media_item_id", value: String(mediaItemId))) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        let (body, response) = try await self.data(for: request(method: "GET", path: "/api/v1/issues", query: query))
        let items = try Self.decoder.decode([MediaIssue].self, from: body)
        let next = response.value(forHTTPHeaderField: "X-Next-Cursor").flatMap { $0.isEmpty ? nil : $0 }
        return IssuePage(items: items, nextCursor: next)
    }

    public func issue(id: Int) async throws -> MediaIssue {
        try await get("/api/v1/issues/\(id)")
    }

    /// The versions of a title the caller may report on; a 404 `scope` reads as none.
    public func reportableVersions(mediaItemId: Int) async throws -> [IssueVersionRef] {
        do {
            return try await get("/api/v1/issues/versions", query: [URLQueryItem(name: "media_item_id", value: String(mediaItemId))])
        } catch let error as APIError where error.code == "scope" {
            return []
        }
    }

    public func fileIssue(_ body: IssueReportBody) async throws -> IssueFiled {
        var req = request(method: "POST", path: "/api/v1/issues", query: [])
        req.httpBody = try Self.encoder.encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await self.data(for: req)
        let issue = try Self.decoder.decode(MediaIssue.self, from: data)
        return IssueFiled(issue: issue, created: response.statusCode == 201)
    }

    public func issueEvents(id: Int, afterId: Int = 0) async throws -> [RequestThreadEvent] {
        try await get("/api/v1/issues/\(id)/events", query: afterId > 0 ? [URLQueryItem(name: "after_id", value: String(afterId))] : [])
    }

    @discardableResult
    public func postIssueMessage(id: Int, body: String) async throws -> RequestThreadEvent {
        try await send("POST", "/api/v1/issues/\(id)/messages", body: IssueMessageBody(body: body))
    }

    public func markIssueRead(id: Int, lastEventId: Int) async throws {
        let _: ThreadReadResult = try await send("POST", "/api/v1/issues/\(id)/read", body: ThreadReadBody(lastEventId: lastEventId))
    }

    @discardableResult
    public func issueAction(issueId: Int, reportId: Int, action: String) async throws -> IssueActionResult {
        try await send("POST", "/api/v1/issues/\(issueId)/reports/\(reportId)/actions", body: IssueActionBody(action: action))
    }

    public func reopenIssue(id: Int, reportId: Int?, note: String? = nil) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/issues/\(id)/reopen", body: IssueReopenBody(reportId: reportId, note: note))
    }

    public func askAdmin(issueId: Int, reportId: Int, note: String?) async throws {
        let _: EmptyResponse = try await send("POST", "/api/v1/issues/\(issueId)/ask-admin", body: IssueAskAdminBody(reportId: reportId, note: note))
    }
}
