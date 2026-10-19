import Foundation

// The approver's Rules and Insights (fusionha revamp phase 5, A3 / A4), from
// the web's `components/requests/{rules,insights}` and
// `api/schemas_request_{rules,insights}.py`.

public struct RequestRule: Decodable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Decodable, Sendable, CaseIterable {
        case approveTier = "APPROVE_TIER", approveRating = "APPROVE_RATING"
        case watchlistApprove = "WATCHLIST_APPROVE", guardFreeSpace = "GUARD_FREE_SPACE"

        public var label: String {
            switch self {
            case .approveTier: return "Approve a version"
            case .approveRating: return "Approve by TMDB rating"
            case .watchlistApprove: return "Watchlists & lists"
            case .guardFreeSpace: return "Hold when space is low"
            }
        }
        public var isGuard: Bool { self == .guardFreeSpace }
        /// The kinds the editor offers (the watchlist kind since 0.4.209).
        public static let editable: [Kind] = [.approveTier, .approveRating, .watchlistApprove, .guardFreeSpace]
    }

    public struct Params: Decodable, Sendable, Hashable {
        public let minRating: Double?
        public let minFreeGb: Double?
        /// `WATCHLIST_APPROVE` (0.4.213): the source classes it approves; `[]` = all.
        public let sources: [String]?
        /// The 0.4.209 shape (`watchlist` / `lists` / `both`), still read.
        public let plexSource: String?

        public init(minRating: Double? = nil, minFreeGb: Double? = nil, sources: [String]? = nil, plexSource: String? = nil) {
            self.minRating = minRating
            self.minFreeGb = minFreeGb
            self.sources = sources
            self.plexSource = plexSource
        }
    }

    public let id: Int
    public let position: Int
    public let kind: Kind
    public let enabled: Bool
    /// Built in: can only be turned on or off.
    public let locked: Bool
    /// nil = everyone.
    public let roleId: Int?
    public let roleName: String?
    /// nil = every version.
    public let tier: QualityTier?
    public let params: Params
    /// The server's sentence for the rule.
    public let label: String
    public let fired7D: Int?

    enum CodingKeys: String, CodingKey {
        case id, position, kind, enabled, locked, roleId, roleName, tier, params, label
        case fired7D, fired7d
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        kind = try c.decode(Kind.self, forKey: .kind)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        locked = try c.decodeIfPresent(Bool.self, forKey: .locked) ?? false
        roleId = try c.decodeIfPresent(Int.self, forKey: .roleId)
        roleName = try c.decodeIfPresent(String.self, forKey: .roleName)
        tier = try c.decodeIfPresent(QualityTier.self, forKey: .tier)
        params = try c.decodeIfPresent(Params.self, forKey: .params) ?? Params()
        label = try c.decode(String.self, forKey: .label)
        // `fired_7d` arrives as `fired7D` under convertFromSnakeCase.
        fired7D = try c.decodeIfPresent(Int.self, forKey: .fired7D) ?? c.decodeIfPresent(Int.self, forKey: .fired7d)
    }

    /// "Approved 4 in the last 7 days" / "Held 2 …" / "Not triggered …".
    public var firedLine: String {
        guard let n = fired7D, n > 0 else { return "Not triggered in the last 7 days" }
        return "\(kind.isGuard ? "Held" : "Approved") \(n) in the last 7 days"
    }
}

/// The editor's draft: `tier` / `roleId` nil = every version / everyone.
public struct RequestRuleDraft: Equatable, Sendable {
    public var kind: RequestRule.Kind
    public var tier: QualityTier?
    public var roleId: Int?
    public var minRating: Double
    public var minFreeGb: Double
    /// `WATCHLIST_APPROVE` only; the editor refuses an empty set.
    public var sources: [RuleSource]

    public init(kind: RequestRule.Kind = .approveTier, tier: QualityTier? = .hd, roleId: Int? = nil,
                minRating: Double = 7, minFreeGb: Double = 500, sources: [RuleSource] = RuleSource.allCases) {
        self.kind = kind
        self.tier = tier
        self.roleId = roleId
        self.minRating = minRating
        self.minFreeGb = minFreeGb
        self.sources = sources
    }

    public init(_ rule: RequestRule) {
        let sources = rule.kind == .watchlistApprove ? RuleSource.of(rule.params) : RuleSource.allCases
        self.init(kind: rule.kind, tier: rule.tier, roleId: rule.roleId,
                  minRating: rule.params.minRating ?? 7, minFreeGb: rule.params.minFreeGb ?? 500, sources: sources)
    }

    /// Save is refused for a watchlist rule with no source ticked.
    public var isValid: Bool { kind != .watchlistApprove || !sources.isEmpty }

    private var params: SettingsJSON {
        switch kind {
        case .approveRating: return .object(["min_rating": .double(minRating)])
        case .guardFreeSpace: return .object(["min_free_gb": .double(minFreeGb)])
        case .watchlistApprove: return .object(["sources": .array(sources.map { .string($0.rawValue) })])
        default: return .object([:])
        }
    }

    private static func optional(_ v: Int?) -> SettingsJSON { v.map { .int($0) } ?? .null }

    /// Guards are global (the editor hides version and audience).
    public var createBody: SettingsJSON {
        .object([
            "kind": .string(kind.rawValue), "enabled": .bool(true), "params": params,
            "tier": kind.isGuard ? .null : (tier.map { .string($0.rawValue) } ?? .null),
            "role_id": kind.isGuard ? .null : Self.optional(roleId),
        ])
    }

    /// Only what changed, so an untouched scope is never amplification-checked.
    public func patchBody(from before: RequestRuleDraft) -> SettingsJSON {
        var out: [String: SettingsJSON] = [:]
        if !kind.isGuard, tier != before.tier { out["tier"] = tier.map { .string($0.rawValue) } ?? .null }
        if !kind.isGuard, roleId != before.roleId { out["role_id"] = Self.optional(roleId) }
        if minRating != before.minRating || minFreeGb != before.minFreeGb || sources != before.sources { out["params"] = params }
        return .object(out)
    }
}

/// One user's week on the quota card; `limit` nil = unlimited.
public struct UserQuota: Decodable, Sendable, Hashable, Identifiable {
    public let person: RequestPerson
    public let used: Int
    public let limit: Int?
    /// `user`, `role` or `default`.
    public let source: String
    public let waiting: Int?
    public let atLimit: Bool?
    public var id: String { "\(person.id ?? -1)-\(person.displayName)" }

    public var sourceLabel: String {
        switch source {
        case "user": return "Their own override"
        case "role": return person.role.map { "Role \($0)" } ?? "Their role"
        default: return "Default"
        }
    }

    /// At-limit people first, then the server's order.
    public static func sorted(_ rows: [UserQuota]) -> [UserQuota] {
        rows.enumerated().sorted { a, b in
            let x = a.element.atLimit == true, y = b.element.atLimit == true
            return x != y ? x : a.offset < b.offset
        }.map(\.element)
    }
}

public struct RequestInsights: Decodable, Sendable {
    public struct Week: Decodable, Sendable { public let weekStart: String; public let requests: Int; public let medianHoursToAvailable: Double? }
    public struct Day: Decodable, Sendable { public let day: String; public let admin: Int; public let auto: Int; public let declined: Int }
    public struct Requester: Decodable, Sendable { public let person: RequestPerson; public let requests: Int }
    public struct Wanted: Decodable, Sendable { public let tmdbId: Int; public let kind: String; public let title: String?; public let year: Int?; public let poster: String?; public let people: Int }
    public struct Reason: Decodable, Sendable { public let reason: String; public let count: Int }

    public let weekly: [Week]
    public let requestsThisWeek: Int
    public let requestsChangePct: Double?
    public let medianHoursToAvailable: Double?
    public let typicalApprovalHours: Double?
    public let approvalRate: Double?
    public let autoShare: Double?
    public let perDay: [Day]
    public let topRequesters: [Requester]
    public let mostWanted: [Wanted]
    public let declineReasons: [Reason]
    /// The window the cards cover (0.4.216): "last 12 weeks".
    public let weeks: Int?
    public let windowStart: String?

    /// "last 12 weeks", or nil on an older server.
    public var windowLabel: String? { weeks.map { "last \($0) week\($0 == 1 ? "" : "s")" } }

    /// "2d 4h" / "3h 12m" / "40m"; "—" with nothing to measure.
    public static func hours(_ h: Double?) -> String {
        guard let h else { return "—" }
        let total = Int((h * 60).rounded())
        let days = total / 1440, hours = (total % 1440) / 60, minutes = total % 60
        if days > 0 { return "\(days)d \(hours)h" }
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    public static func percent(_ r: Double?) -> String { r.map { "\(Int(($0 * 100).rounded()))%" } ?? "—" }

    /// "+12%" / "−8%".
    public static func signed(_ pct: Double) -> String {
        let n = Int(pct.rounded())
        return n >= 0 ? "+\(n)%" : "−\(abs(n))%"
    }

    public static func reasonLabel(_ raw: String) -> String {
        RequestReason(rawValue: raw)?.title ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

/// A role, for the rule editor's audience picker.
public struct RoleSummary: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let name: String
}

public enum RequestRuleOrder {
    /// The full id order after moving approve rule `id` one step among the
    /// approve rules (guards keep their slots); nil at either end.
    public static func moved(_ rules: [RequestRule], id: Int, by dir: Int) -> [Int]? {
        let approve = rules.filter { !$0.kind.isGuard }
        guard let at = approve.firstIndex(where: { $0.id == id }), approve.indices.contains(at + dir) else { return nil }
        var ids = rules.map(\.id)
        guard let i = ids.firstIndex(of: id), let j = ids.firstIndex(of: approve[at + dir].id) else { return nil }
        ids.swapAt(i, j)
        return ids
    }
}

extension APIClient {
    public func requestRules() async throws -> [RequestRule] { try await get("/api/v1/requests/rules") }

    public func createRequestRule(_ draft: RequestRuleDraft) async throws -> RequestRule {
        try await sendJSON("POST", "/api/v1/requests/rules", draft.createBody)
    }

    public func patchRequestRule(id: Int, _ body: SettingsJSON) async throws -> RequestRule {
        try await sendJSON("PATCH", "/api/v1/requests/rules/\(id)", body)
    }

    public func deleteRequestRule(id: Int) async throws {
        try await sendJSON("DELETE", "/api/v1/requests/rules/\(id)")
    }

    public func reorderRequestRules(_ ids: [Int]) async throws -> [RequestRule] {
        try await sendJSON("POST", "/api/v1/requests/rules/reorder", ["ids": .ints(ids)])
    }

    public func requestQuotas() async throws -> [UserQuota] { try await get("/api/v1/requests/quotas") }

    public func autoApprovedRequests(hours: Int = 24) async throws -> [MediaRequest] {
        try await get("/api/v1/requests/auto-approved", query: [URLQueryItem(name: "hours", value: String(hours))])
    }

    public func requestInsights(weeks: Int = 12) async throws -> RequestInsights {
        try await get("/api/v1/requests/insights", query: [URLQueryItem(name: "weeks", value: String(weeks))])
    }

    public func roleSummaries() async throws -> [RoleSummary] { try await get("/api/v1/roles") }
}
