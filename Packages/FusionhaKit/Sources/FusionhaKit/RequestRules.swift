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
            case .watchlistApprove: return "Plex watchlist"
            case .guardFreeSpace: return "Hold when space is low"
            }
        }
        public var isGuard: Bool { self == .guardFreeSpace }
        /// The kinds the editor offers (the watchlist kind comes with phase 9).
        public static let editable: [Kind] = [.approveTier, .approveRating, .guardFreeSpace]
    }

    public struct Params: Decodable, Sendable, Hashable {
        public let minRating: Double?
        public let minFreeGb: Double?
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
        params = try c.decodeIfPresent(Params.self, forKey: .params) ?? Params(minRating: nil, minFreeGb: nil)
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

    public init(kind: RequestRule.Kind = .approveTier, tier: QualityTier? = .hd, roleId: Int? = nil,
                minRating: Double = 7, minFreeGb: Double = 500) {
        self.kind = kind
        self.tier = tier
        self.roleId = roleId
        self.minRating = minRating
        self.minFreeGb = minFreeGb
    }

    public init(_ rule: RequestRule) {
        self.init(kind: rule.kind, tier: rule.tier, roleId: rule.roleId,
                  minRating: rule.params.minRating ?? 7, minFreeGb: rule.params.minFreeGb ?? 500)
    }

    private var params: SettingsJSON {
        switch kind {
        case .approveRating: return .object(["min_rating": .double(minRating)])
        case .guardFreeSpace: return .object(["min_free_gb": .double(minFreeGb)])
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
        if minRating != before.minRating || minFreeGb != before.minFreeGb { out["params"] = params }
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

// MARK: - Guardrails (Settings › Requests, phase 7 A9)

/// `GET /audit/autofix-stats` (admin): automatic fixes inside the window and the paused slots.
public struct AutofixStats: Decodable, Sendable {
    public struct Paused: Decodable, Sendable, Identifiable {
        public let reportId: Int
        public let issueId: Int
        public let title: String?
        public let season: Int?
        public let episode: Int?
        public let pausedAt: String?
        public let tier: QualityTier?
        public let edition: String?
        public let failures: Int
        public let windowDays: Int
        public var id: Int { reportId }

        /// "Andor · S02E04 · UHD·4K".
        public var line: String {
            var parts = [title ?? "Unknown title"]
            if let season, let episode { parts.append(String(format: "S%02dE%02d", season, episode)) }
            if let tier { parts.append(VersionLabel.text(tier: tier, edition: edition, multipleEditions: false) ?? tier.word) }
            return parts.joined(separator: " · ")
        }

        public var failuresLine: String {
            "\(failures) failed \(failures == 1 ? "fix" : "fixes") in \(windowDays) \(windowDays == 1 ? "day" : "days") · current copy kept"
        }
    }

    public let days: Int
    public let attempts: Int
    public let fixed: Int
    public let failed: Int
    public let waiting: Int
    public let successRate: Double?
    public let paused: [Paused]
}

/// The four Auto-fix limits, bounds mirroring the server's validation.
public struct GuardrailLimit: Sendable, Identifiable {
    public let key: String
    public let title: String
    public let sub: String
    public let range: ClosedRange<Int>
    public let fallback: Int
    public let unit: (Int) -> String
    public var id: String { key }

    public static let all: [GuardrailLimit] = [
        .init(key: "autofix_max_failures", title: "Failed fixes before pausing",
              sub: "Per episode or movie version, inside the window below. Reopens count too.", range: 1...10, fallback: 2, unit: { "\($0)" }),
        .init(key: "autofix_failure_window_days", title: "Pause window",
              sub: "How far back a failed fix still counts towards a pause.", range: 1...90, fallback: 7, unit: days),
        .init(key: "issue_reopen_window_days", title: "Reopen automatically for",
              sub: "A resolved report reopens if the same file is found dead again.", range: 1...365, fallback: 30, unit: days),
        .init(key: "selfservice_replace_daily_limit", title: "Language replacements per person",
              sub: "Each day. Searches and Plex rescans have their own limit.", range: 0...50, fallback: 3, unit: { $0 == 0 ? "Off" : "\($0) / day" }),
    ]

    private static func days(_ n: Int) -> String { "\(n) \(n == 1 ? "day" : "days")" }
}

extension APIClient {
    public func autofixStats(days: Int = 30) async throws -> AutofixStats {
        try await get("/api/v1/audit/autofix-stats", query: [URLQueryItem(name: "days", value: String(days))])
    }
}
