import Foundation

/// One copy's facts inside a staged keep-old replacement (`CopyFactsRead`).
public struct IssueCopyFacts: Decodable, Sendable, Hashable {
    public let fileId: Int
    public let release: String?
    public let quality: String?
    public let size: Double?
    public let video: String?
    public let audioLanguages: [String]?
    public let subtitleLanguages: [String]?
    /// alive · dead · …
    public let verdict: String?
    public let verdictSummary: String?
    public let checkedAt: String?

    public init(fileId: Int, release: String? = nil, quality: String? = nil, size: Double? = 0, video: String? = nil,
                audioLanguages: [String]? = [], subtitleLanguages: [String]? = [], verdict: String? = nil,
                verdictSummary: String? = "", checkedAt: String? = nil) {
        self.fileId = fileId
        self.release = release
        self.quality = quality
        self.size = size
        self.video = video
        self.audioLanguages = audioLanguages
        self.subtitleLanguages = subtitleLanguages
        self.verdict = verdict
        self.verdictSummary = verdictSummary
        self.checkedAt = checkedAt
    }
}

/// A held keep-old replacement a manager compares (`StagedCopyRead`).
public struct IssueStagedCopy: Decodable, Sendable, Hashable {
    public struct Stuck: Decodable, Sendable, Hashable {
        /// no_root · swap_published · swap_stuck
        public let reason: String
        public let rootName: String?
        public init(reason: String, rootName: String? = nil) {
            self.reason = reason
            self.rootName = rootName
        }
    }
    public let old: IssueCopyFacts?
    public let new: IssueCopyFacts
    /// verifying · held · unknown
    public let state: String
    /// dead · language · admin_regrab
    public let kind: String
    public let stuck: Stuck?

    public init(old: IssueCopyFacts?, new: IssueCopyFacts, state: String, kind: String, stuck: Stuck? = nil) {
        self.old = old
        self.new = new
        self.state = state
        self.kind = kind
        self.stuck = stuck
    }
}

/// The client a report's checks ran against (managers only).
public struct IssueClient: Decodable, Sendable, Hashable {
    public let id: Int
    public let name: String
    public let fileChecks: Bool?
}

/// Arbitrary JSON (a report's diagnosis), read as `JSONValue`.
public struct IssueJSON: Decodable, Sendable, Hashable {
    public let value: JSONValue

    public init(_ value: JSONValue) { self.value = value }

    struct Key: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    public init(from decoder: Decoder) throws {
        if let keyed = try? decoder.container(keyedBy: Key.self) {
            var out: [String: JSONValue] = [:]
            for k in keyed.allKeys { out[k.stringValue] = (try? keyed.decode(IssueJSON.self, forKey: k))?.value ?? .null }
            value = .object(out)
            return
        }
        if var list = try? decoder.unkeyedContainer() {
            var out: [JSONValue] = []
            while !list.isAtEnd { out.append((try? list.decode(IssueJSON.self))?.value ?? .null) }
            value = .array(out)
            return
        }
        let single = try decoder.singleValueContainer()
        if single.decodeNil() { value = .null }
        else if let b = try? single.decode(Bool.self) { value = .bool(b) }
        else if let n = try? single.decode(Double.self) { value = .number(n) }
        else if let s = try? single.decode(String.self) { value = .string(s) }
        else { value = .null }
    }
}

/// One row of the managers' threads list (`ThreadItemRead`).
public struct ThreadItem: Decodable, Sendable, Hashable, Identifiable {
    /// request · issue
    public let type: String
    public let rawId: Int
    public let lastEventAt: String?
    public let title: String?
    public let year: Int?
    public let poster: String?
    public let request: MediaRequest?
    public let issue: MediaIssue?
    public let linkedPendingRequestId: Int?

    public var id: String { "\(type):\(rawId)" }

    enum CodingKeys: String, CodingKey {
        case type, rawId = "id", lastEventAt, title, year, poster, request, issue, linkedPendingRequestId
    }
}

public struct ThreadPage: Decodable, Sendable {
    public let items: [ThreadItem]
    public let nextCursor: String?
}

/// The History strip's read (`IssueFixGrabsRead`).
public struct IssueFixGrabs: Decodable, Sendable, Hashable {
    public struct Group: Decodable, Sendable, Hashable {
        /// autofix · selfservice
        public let trigger: String
        /// grabbed · imported · failed
        public let status: String
        public let labels: [String]
        public let grabbedAt: String?
    }
    public let mediaItemId: Int
    public let title: String?
    public let groups: [Group]
}

struct StagedConfirmBody: Encodable { let oldFileId: Int?; let stagedFileId: Int }
struct StagedActionBody: Encodable { let action: String; let confirm: StagedConfirmBody }
struct IssueAudienceMessageBody: Encodable { let body: String; let audienceUserId: Int?; let everyone: Bool? }

extension APIClient {
    /// `GET /threads?view=admin`: request and issue threads by last activity.
    public func adminThreads(type: String? = nil, state: String? = nil, limit: Int = 50, cursor: String? = nil) async throws -> ThreadPage {
        var query = [URLQueryItem(name: "view", value: "admin"), URLQueryItem(name: "limit", value: String(limit))]
        if let type { query.append(URLQueryItem(name: "type", value: type)) }
        if let state { query.append(URLQueryItem(name: "state", value: state)) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await get("/api/v1/threads", query: query)
    }

    public func issueFixGrabs(id: Int) async throws -> IssueFixGrabs {
        try await get("/api/v1/issues/\(id)/fix-grabs")
    }

    /// Use or discard a staged copy, confirming the snapshot the dialog showed.
    public func stagedAction(issueId: Int, reportId: Int, use: Bool, oldFileId: Int?, stagedFileId: Int) async throws {
        let body = StagedActionBody(action: use ? "use_new_copy" : "discard_new_copy",
                                    confirm: StagedConfirmBody(oldFileId: oldFileId, stagedFileId: stagedFileId))
        let _: EmptyResponse = try await send("POST", "/api/v1/issues/\(issueId)/reports/\(reportId)/actions", body: body)
    }

    /// A manager's reply to one reporter, or thread-wide to everyone.
    @discardableResult
    public func postIssueMessage(id: Int, body: String, audienceUserId: Int?, everyone: Bool) async throws -> RequestThreadEvent {
        try await send("POST", "/api/v1/issues/\(id)/messages",
                       body: IssueAudienceMessageBody(body: body, audienceUserId: everyone ? nil : audienceUserId, everyone: everyone ? true : nil))
    }
}

extension APIError {
    /// The `detail.reason` of a typed refusal (e.g. a `swap_refused`), else nil.
    public var reason: String? {
        guard case .http(_, let body) = self,
              let object = try? JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let detail = object["detail"] as? [String: Any] else { return nil }
        return detail["reason"] as? String
    }
}
