import Foundation

/// One line on a request thread (`GET /requests/{id}/events`): a MESSAGE
/// bubble or a SYSTEM line.
public struct RequestThreadEvent: Decodable, Sendable, Hashable, Identifiable {
    /// The few `data` keys a request line carries; anything else is ignored.
    public struct LineData: Decodable, Sendable, Hashable {
        public let tiers: [String]?
        public let tier: String?
        public let via: String?
        public let rule: String?
        /// Issue lines: the report a verdict belongs to, and a rescan marker's action.
        public let reportId: Int?
        public let action: String?
        /// `created` lines: the automatic source kind (absent for a manual
        /// request) and `again` on a "Request again" (0.4.209).
        public let source: String?
        public let again: Bool?

        public init(tiers: [String]? = nil, tier: String? = nil, via: String? = nil, rule: String? = nil,
                    reportId: Int? = nil, action: String? = nil, source: String? = nil, again: Bool? = nil) {
            self.tiers = tiers
            self.tier = tier
            self.via = via
            self.rule = rule
            self.reportId = reportId
            self.action = action
            self.source = source
            self.again = again
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            tiers = try? c.decodeIfPresent([String].self, forKey: .tiers)
            tier = try? c.decodeIfPresent(String.self, forKey: .tier)
            via = try? c.decodeIfPresent(String.self, forKey: .via)
            rule = try? c.decodeIfPresent(String.self, forKey: .rule)
            reportId = try? c.decodeIfPresent(Int.self, forKey: .reportId)
            action = try? c.decodeIfPresent(String.self, forKey: .action)
            source = try? c.decodeIfPresent(String.self, forKey: .source)
            again = try? c.decodeIfPresent(Bool.self, forKey: .again)
        }

        enum CodingKeys: String, CodingKey { case tiers, tier, via, rule, reportId, action, source, again }
    }

    public let id: Int
    public let kind: String
    public let eventType: String
    public let actor: RequestPerson?
    public let actorKind: String?
    public let body: String?
    public let data: LineData?
    public let createdAt: String
    public let mine: Bool?

    public init(id: Int, kind: String, eventType: String, actor: RequestPerson? = nil, actorKind: String? = nil,
                body: String? = nil, data: LineData? = nil, createdAt: String = "", mine: Bool? = false) {
        self.id = id
        self.kind = kind
        self.eventType = eventType
        self.actor = actor
        self.actorKind = actorKind
        self.body = body
        self.data = data
        self.createdAt = createdAt
        self.mine = mine
    }

    public var isMessage: Bool { kind == "MESSAGE" }
    public var isMine: Bool { mine == true }
}

/// The thread's words (web `thread-format.ts`).
public enum RequestThreadFormat {
    static let tierNames = ["HD_1080P": "HD·1080p", "UHD_2160P": "UHD·4K"]

    static func names(_ data: RequestThreadEvent.LineData?) -> String {
        (data?.tiers ?? []).map { tierNames[$0] ?? $0 }.joined(separator: " and ")
    }

    static func tierValue(_ data: RequestThreadEvent.LineData?) -> String {
        guard let raw = data?.tier else { return "" }
        return QualityTier(rawValue: raw)?.chipLabel ?? tierNames[raw] ?? raw
    }

    /// One line for a SYSTEM event. `source` is the request's projected
    /// source: its list label and Letterboxd owner name the `created` line.
    public static func systemLine(_ e: RequestThreadEvent, source: RequestSource? = nil) -> String {
        let who = e.actor?.displayName
        switch e.eventType {
        case "created": return createdLine(e, who: who, label: source?.label, owner: source?.owner)
        case "version_added": return "\(who ?? "Someone") added \(names(e.data))".trimmed
        case "joined":
            let tiers = names(e.data)
            return "\(e.isMine ? "You" : (who ?? "Someone")) joined\(tiers.isEmpty ? "" : " · \(tiers)")"
        case "promoted": return "Your quota reset · sent for approval"
        case "approved":
            if e.data?.via == "ADMIN" { return "Approved by \(who ?? "an admin")" }
            return e.data?.via == "RULE" ? "Auto-approved by a rule" : "Auto-approved"
        case "held":
            if let rule = e.data?.rule, !rule.isEmpty { return "Held for review · \(rule)" }
            return "Held for review"
        case "declined": return "Declined by \(who ?? "an admin")"
        case "deferred": return "Marked “not available yet” by \(who ?? "an admin")"
        case "withdrawn": return "Withdrawn by \(who ?? "the requester")"
        case "grabbed": return "Grabbed \(tierValue(e.data))".trimmed
        case "imported": return "Imported \(tierValue(e.data))".trimmed
        case "available": return "Available in your library"
        default:
            if let body = e.body?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty { return body }
            return e.eventType.replacingOccurrences(of: "_", with: " ")
        }
    }

    /// The caption under a message bubble; a joiner's view says who it was for.
    public static func messageMeta(_ e: RequestThreadEvent, joinedView: Bool = false) -> String {
        let who = e.isMine ? "You" : (e.actor?.displayName ?? "fusionha")
        if e.eventType == "broadcast" { return "\(who) · to \(joinedView ? "everyone who asked" : "everyone")" }
        return joinedView && !e.isMine ? "\(who) · to you" : who
    }

    /// The composer's placeholder.
    public static func placeholder(_ request: MediaRequest, isOwner: Bool, joinedView: Bool) -> String {
        isOwner || joinedView ? "Message the admins…" : "Message \(request.requester?.displayName ?? "the requester")…"
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}

struct ThreadMessageBody: Encodable { let body: String }
struct ThreadReadBody: Encodable { let lastEventId: Int }
struct ThreadReadResult: Decodable { let advanced: Bool }

extension APIClient {
    public func requestDetail(id: Int) async throws -> MediaRequest {
        try await get("/api/v1/requests/\(id)")
    }

    /// The thread's lines after `afterId` (read-only; never moves the marker).
    public func requestEvents(id: Int, afterId: Int = 0) async throws -> [RequestThreadEvent] {
        try await get("/api/v1/requests/\(id)/events", query: [URLQueryItem(name: "after_id", value: String(afterId))])
    }

    @discardableResult
    public func postRequestMessage(id: Int, body: String) async throws -> RequestThreadEvent {
        try await send("POST", "/api/v1/requests/\(id)/messages", body: ThreadMessageBody(body: body))
    }

    public func markRequestRead(id: Int, lastEventId: Int) async throws {
        let _: ThreadReadResult = try await send("POST", "/api/v1/requests/\(id)/read", body: ThreadReadBody(lastEventId: lastEventId))
    }
}
