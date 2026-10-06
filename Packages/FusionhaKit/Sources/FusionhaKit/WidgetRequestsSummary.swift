import Foundation

public struct WidgetRequestRow: Codable, Sendable, Hashable {
    public let id: Int
    public let tmdbId: Int
    public let kind: MediaKind
    public let mediaItemId: Int?
    public let tiers: [QualityTier]
    /// `Seasons 1–2`, `Season 3`, nil for a movie or the whole series.
    public let seasons: String?
    public let userId: Int?
    public let requestedAt: String?

    public init(id: Int, tmdbId: Int, kind: MediaKind, mediaItemId: Int?, tiers: [QualityTier], seasons: String?,
                userId: Int?, requestedAt: String?) {
        self.id = id
        self.tmdbId = tmdbId
        self.kind = kind
        self.mediaItemId = mediaItemId
        self.tiers = tiers
        self.seasons = seasons
        self.userId = userId
        self.requestedAt = requestedAt
    }
}

public struct WidgetIssueRow: Codable, Sendable, Hashable {
    public let id: Int
    public let mediaItemId: Int
    /// `Audio · S02E05`.
    public let label: String
    public let description: String?
    public let createdAt: String?

    public init(id: Int, mediaItemId: Int, label: String, description: String?, createdAt: String?) {
        self.id = id
        self.mediaItemId = mediaItemId
        self.label = label
        self.description = description
        self.createdAt = createdAt
    }
}

/// The Requests & issues page: pending / in progress / open-issue counts, the
/// newest pending requests and the newest open issue.
public struct WidgetRequestsSummary: Codable, Sendable, Hashable {
    public var pending = 0
    /// Approved, not yet available.
    public var inProgress = 0
    public var openIssues = 0
    public var newest: [WidgetRequestRow] = []
    public var issue: WidgetIssueRow?

    public init() {}

    public init(requests: [MediaRequest], openIssues issues: [MediaIssue], limit: Int = 3) {
        pending = requests.filter { $0.status == "pending" }.count
        inProgress = requests.filter { $0.status == "approved" }.count
        openIssues = issues.filter { $0.status == "open" }.count
        newest = requests
            .filter { $0.status == "pending" }
            .enumerated()
            .sorted { a, b in Self.newer(a.element.requestedAt, b.element.requestedAt, a.offset, b.offset) }
            .prefix(limit)
            .map { row in
                let r = row.element
                var tiers = r.editions ?? []
                if tiers.isEmpty { tiers = [r.tier] }
                return WidgetRequestRow(id: r.id, tmdbId: r.tmdbId, kind: r.kind, mediaItemId: r.mediaItemId,
                                        tiers: Array(Set(tiers)).sorted { $0 == .hd && $1 == .uhd },
                                        seasons: Self.seasonsLabel(r.seasons ?? []), userId: r.userId,
                                        requestedAt: r.requestedAt)
            }
        issue = issues
            .filter { $0.status == "open" }
            .enumerated()
            .sorted { a, b in Self.newer(a.element.createdAt, b.element.createdAt, a.offset, b.offset) }
            .first
            .map { row in
                let i = row.element
                let label = i.scope == "item" ? i.typeLabel : "\(i.typeLabel) · \(i.scopeLabel)"
                return WidgetIssueRow(id: i.id, mediaItemId: i.mediaItemId, label: label,
                                      description: i.description, createdAt: i.createdAt)
            }
    }

    /// `Season 3`, `Seasons 1–2`, `Seasons 1, 3, 5`; nil when none.
    public static func seasonsLabel(_ seasons: [Int]) -> String? {
        let s = Array(Set(seasons)).sorted()
        guard let first = s.first, let last = s.last else { return nil }
        if s.count == 1 { return first == 0 ? "Specials" : "Season \(first)" }
        if last - first == s.count - 1 { return "Seasons \(first)–\(last)" }
        return "Seasons " + s.map(String.init).joined(separator: ", ")
    }

    private static func newer(_ a: String?, _ b: String?, _ ia: Int, _ ib: Int) -> Bool {
        let x = a.flatMap(CalendarMath.parseUTC), y = b.flatMap(CalendarMath.parseUTC)
        switch (x, y) {
        case let (x?, y?): return x == y ? ia < ib : x > y
        case (.some, .none): return true
        case (.none, .some): return false
        case (.none, .none): return ia < ib
        }
    }
}

/// `GET /api/v1/users` reduced to what the widget shows: id → display name.
public struct WidgetUserName: Decodable, Sendable, Hashable {
    public let id: Int
    public let username: String

    /// The Plex name for a mangled `name (plex:…)` account.
    public var display: String {
        username.replacingOccurrences(of: #"\s*\(plex:[^)]+\)\s*$"#, with: "",
                                      options: [.regularExpression, .caseInsensitive])
    }
}

extension APIClient {
    /// `GET /api/v1/users` (user managers only): the requesters' names.
    public func widgetUserNames() async throws -> [Int: String] {
        let users: [WidgetUserName] = try await get("/api/v1/users")
        return Dictionary(users.map { ($0.id, $0.display) }, uniquingKeysWith: { a, _ in a })
    }
}

/// `GET /api/v1/library/{id}` reduced to its title, so a widget row can name
/// an issue's title without building the whole item detail.
struct WidgetTitleOnly: Decodable, Sendable {
    let title: String
}

extension APIClient {
    public func widgetItemTitle(id: Int) async throws -> String {
        let item: WidgetTitleOnly = try await get("/api/v1/library/\(id)")
        return item.title
    }
}
