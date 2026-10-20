import Foundation

// MARK: - Audit  (GET /api/v1/audit)

public struct AuditEntry: Decodable, Sendable, Identifiable, Hashable {
    public let id: Int
    public let actor: String
    public let action: String
    public let target: String?
    public let at: String
    // Readable rows (fusionha 0.4.158+): the server words them; legacy route rows leave these empty.
    /// AUTO_FIX · SELF_SERVICE · ADMIN · REQUEST, or nil for a legacy row.
    public let category: String?
    /// The verb without the title (line 1 carries the title) / with it.
    public let verb: String?
    public let verbFull: String?
    public let actorLabel: String?
    /// user · token · key · instance · system
    public let actorType: String?
    /// The exact `who` filter value.
    public let actorKey: String?
    public let actorAvatar: String?
    public let titleTarget: AuditTitleTarget?
    public let detail: [String]?
    public let ip: String?
    public let userAgent: String?
    public let sensitive: Bool?
    public let link: String?
}

/// What a readable audit row is about.
public struct AuditTitleTarget: Decodable, Sendable, Hashable {
    public let kind: String
    public let itemId: Int?
    public let title: String
    public let year: Int?
    public let posterUrl: String?
    public let tiers: [String]?
}

/// Per-category totals for the chips.
public struct AuditCounts: Decodable, Sendable {
    public let all: Int
    public let autoFix: Int?
    public let selfService: Int?
    public let admin: Int?
    public let request: Int?
    public let sensitive: Int?
    public let omittedLookups: Int?

    enum CodingKeys: String, CodingKey {
        case all, sensitive, omittedLookups
        // convertFromSnakeCase turns `AUTO_FIX` into `AUTOFix` (the first word keeps its case).
        case autoFix = "AUTOFix", selfService = "SELFService", admin = "ADMIN", request = "REQUEST"
    }

    public func count(_ category: String) -> Int? {
        switch category {
        case "AUTO_FIX": return autoFix
        case "SELF_SERVICE": return selfService
        case "ADMIN": return admin
        case "REQUEST": return request
        default: return nil
        }
    }
}

/// One Who-menu entry.
public struct AuditActor: Decodable, Sendable, Hashable, Identifiable {
    public let key: String
    public let label: String
    public let type: String
    public let count: Int
    public var id: String { key }
}

/// The audit filters (web `AuditFilterBar`).
public struct AuditFilter: Equatable, Sendable {
    public var category: String?
    public var who: String?
    /// 24h · 7d · 30d · all
    public var since: String = "all"
    public var sensitive = false
    public var query = ""

    public init() {}

    public static let categories: [(key: String, label: String)] = [
        ("AUTO_FIX", "Auto-fix"), ("SELF_SERVICE", "Self-service"), ("ADMIN", "Admin"), ("REQUEST", "Requests"),
    ]

    /// The `since` timestamp (ISO, UTC) for the window, or nil for all.
    public func sinceDate(now: Date = .now) -> String? {
        let hours: Double
        switch since {
        case "24h": hours = 24
        case "7d": hours = 24 * 7
        case "30d": hours = 24 * 30
        default: return nil
        }
        return ISO8601DateFormatter().string(from: now.addingTimeInterval(-hours * 3600))
    }

    func items(limit: Int?, beforeId: Int?) -> [URLQueryItem] {
        var out: [URLQueryItem] = []
        if let limit { out.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let beforeId { out.append(URLQueryItem(name: "before_id", value: String(beforeId))) }
        if let category { out.append(URLQueryItem(name: "category", value: category)) }
        if let who { out.append(URLQueryItem(name: "who", value: who)) }
        if let s = sinceDate() { out.append(URLQueryItem(name: "since", value: s)) }
        if sensitive { out.append(URLQueryItem(name: "sensitive", value: "true")) }
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty { out.append(URLQueryItem(name: "q", value: q)) }
        return out
    }
}
