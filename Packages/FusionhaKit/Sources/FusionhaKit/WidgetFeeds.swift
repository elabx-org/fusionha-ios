import Foundation

// Pure selection logic for the home-screen widgets ("Up next", "Recently added",
// and the Downloads widget's idle state). The widgets read the same endpoints as
// the Calendar (`GET /api/v1/calendar`) and Activity › History
// (`GET /api/v1/history`) screens; this file only picks and labels rows.

extension APIClient {
    /// `GET /api/v1/history?event_type=imported`: the newest imports first.
    public func recentImports(pageSize: Int = 30) async throws -> HistoryPage {
        try await get("/api/v1/history", query: [
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
            URLQueryItem(name: "event_type", value: "imported"),
        ])
    }
}

/// One edition of an "Up next" row: its tier and unaired-aware calendar status.
public struct UpNextEdition: Sendable, Hashable {
    public let tier: QualityTier
    public let status: CalendarStatusKey

    public init(tier: QualityTier, status: CalendarStatusKey) {
        self.tier = tier
        self.status = status
    }
}

/// The next airing episode(s) or release of one title.
public struct UpNextItem: Sendable, Hashable {
    public let itemId: Int
    public let title: String
    /// `S1·E5`, `#28`, `Digital`, or `S1·E1 +7` for a same-day drop.
    public let code: String
    public let episodeTitle: String?
    /// The air instant, or local midnight for a date-only entry.
    public let airDate: Date
    public let hasTime: Bool
    public let isMovie: Bool
    public let isAnime: Bool
    public let posterUrl: String?
    public let editions: [UpNextEdition]

    public init(itemId: Int, title: String, code: String, episodeTitle: String?, airDate: Date, hasTime: Bool,
                isMovie: Bool, isAnime: Bool, posterUrl: String?, editions: [UpNextEdition]) {
        self.itemId = itemId
        self.title = title
        self.code = code
        self.episodeTitle = episodeTitle
        self.airDate = airDate
        self.hasTime = hasTime
        self.isMovie = isMovie
        self.isAnime = isAnime
        self.posterUrl = posterUrl
        self.editions = editions
    }
}

/// One recently imported title (its newest imports grouped).
public struct RecentImport: Sendable, Hashable {
    public let itemId: Int?
    public let title: String
    /// Distinct tiers imported, newest first (HD and 4K can both land).
    public let tiers: [QualityTier]
    public let importedAt: Date?
    public let posterUrl: String?
    /// How many import events were grouped (e.g. a few episodes).
    public let count: Int

    public init(itemId: Int?, title: String, tiers: [QualityTier], importedAt: Date?, posterUrl: String?, count: Int) {
        self.itemId = itemId
        self.title = title
        self.tiers = tiers
        self.importedAt = importedAt
        self.posterUrl = posterUrl
        self.count = count
    }
}

extension CalendarStatusKey {
    /// The matching `EditionStatus`, so widget chips colour through `EditionStatus.color`.
    public var editionStatus: EditionStatus {
        switch self {
        case .downloaded: return .downloaded
        case .downloading: return .downloading
        case .missing: return .missing
        case .unaired: return .unaired
        }
    }
}

/// Where a widget tap lands: `fusionha://item/{id}` or a tab
/// (`fusionha://activity`, `calendar`, `library`).
public enum WidgetRoute: Sendable, Hashable {
    case item(Int)
    case activity
    case calendar
    case library

    public var url: URL {
        switch self {
        case .item(let id): return URL(string: "fusionha://item/\(id)")!
        case .activity: return URL(string: "fusionha://activity")!
        case .calendar: return URL(string: "fusionha://calendar")!
        case .library: return URL(string: "fusionha://library")!
        }
    }

    /// The title's detail sheet, or `fallback` when the row has no usable id.
    /// Widget tiles always link somewhere so a tap never falls through to the
    /// widget's own URL (Activity on the Downloads widget).
    public static func item(_ id: Int?, fallback: WidgetRoute) -> WidgetRoute {
        guard let id, id > 0 else { return fallback }
        return .item(id)
    }

    /// The Downloads widget's whole-widget URL (anywhere outside a row link).
    /// Downloading → Activity. Idle small → the one title it shows. Idle
    /// medium/large → Library (Calendar when only Up next shows): idle shows no
    /// downloads, so Activity would be a surprising place to land.
    public static func downloads(idle: Bool, small: Bool, upNextIds: [Int], recentIds: [Int?]) -> WidgetRoute {
        guard idle else { return .activity }
        if small {
            if let next = upNextIds.first { return item(next, fallback: .calendar) }
            if let latest = recentIds.first { return item(latest, fallback: .library) }
            return .activity
        }
        if recentIds.isEmpty && !upNextIds.isEmpty { return .calendar }
        return .library
    }
}

public enum WidgetFeeds {
    /// Upcoming calendar entries (monitored, not yet aired), soonest first. Episodes
    /// of one title on the same local day collapse into one row (`S1·E1 +7`).
    public static func upNext(_ entries: [CalendarEntry], now: Date = Date(),
                              calendar: Calendar = .current, limit: Int) -> [UpNextItem] {
        let today = CalendarMath.iso(now, calendar)
        var upcoming: [(entry: CalendarEntry, at: Date, timed: Bool, day: String, offset: Int)] = []
        for (offset, entry) in entries.enumerated() where entry.editions.contains(where: \.monitored) {
            let day = entry.localDay(calendar)
            if let at = entry.airDatetimeInstant {
                guard at > now else { continue }
                upcoming.append((entry: entry, at: at, timed: true, day: day, offset: offset))
            } else {
                guard day >= today, let at = CalendarMath.date(day, calendar) else { continue }
                upcoming.append((entry: entry, at: at, timed: false, day: day, offset: offset))
            }
        }
        upcoming.sort { $0.at == $1.at ? $0.offset < $1.offset : $0.at < $1.at }

        var order: [String] = []
        var groups: [String: [(entry: CalendarEntry, at: Date, timed: Bool)]] = [:]
        for row in upcoming {
            let key = "\(row.entry.type)|\(row.entry.itemId)|\(row.day)"
            if groups[key] == nil {
                guard order.count < limit else { continue }
                order.append(key)
            }
            groups[key, default: []].append((entry: row.entry, at: row.at, timed: row.timed))
        }
        return order.compactMap { key -> UpNextItem? in
            guard let rows = groups[key], let first = rows.first else { return nil }
            let entry = first.entry
            let code = rows.count > 1 ? "\(entry.code) +\(rows.count - 1)" : entry.code
            // One pill per tier: a title can carry several editions in a tier
            // (e.g. Colour and Black & White HD), which would read as duplicates.
            var editions: [UpNextEdition] = []
            for edition in entry.editions where edition.monitored && !editions.contains(where: { $0.tier == edition.tier }) {
                editions.append(UpNextEdition(tier: edition.tier, status: entry.statusKey(for: edition, now: now)))
            }
            return UpNextItem(
                itemId: entry.itemId, title: entry.title, code: code,
                episodeTitle: rows.count > 1 ? nil : entry.episodeTitle,
                airDate: first.at, hasTime: first.timed, isMovie: entry.isMovie, isAnime: entry.isAnime,
                posterUrl: entry.posterUrl, editions: sortedTiers(editions))
        }
    }

    /// The newest imported titles, one row per title, newest first.
    public static func recentImports(_ history: [HistoryEntry], limit: Int) -> [RecentImport] {
        let imports = history
            .filter { $0.eventType.uppercased() == "IMPORTED" }
            .enumerated()
            .map { (offset: $0.offset, entry: $0.element, at: CalendarMath.parseUTC($0.element.createdAt)) }
            .sorted { a, b in
                switch (a.at, b.at) {
                case let (x?, y?): return x == y ? a.offset < b.offset : x > y
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return a.offset < b.offset
                }
            }
        var order: [String] = []
        var groups: [String: [(entry: HistoryEntry, at: Date?)]] = [:]
        for row in imports {
            guard let title = row.entry.itemTitle ?? row.entry.sourceTitle else { continue }
            let key = row.entry.mediaItemId.map { "id:\($0)" } ?? "title:\(title)"
            if groups[key] == nil {
                guard order.count < limit else { continue }
                order.append(key)
            }
            groups[key, default: []].append((entry: row.entry, at: row.at))
        }
        return order.compactMap { key -> RecentImport? in
            guard let rows = groups[key], let first = rows.first else { return nil }
            var tiers: [QualityTier] = []
            for row in rows { if let tier = row.entry.tier, !tiers.contains(tier) { tiers.append(tier) } }
            return RecentImport(
                // Any grouped row's id: a tombstoned first row must not leave
                // the tile without a link to its title.
                itemId: rows.lazy.compactMap { $0.entry.mediaItemId }.first,
                title: first.entry.itemTitle ?? first.entry.sourceTitle ?? "",
                tiers: tiers.sorted { $0 == .hd && $1 == .uhd },
                importedAt: first.at,
                posterUrl: rows.lazy.compactMap { $0.entry.posterUrl }.first,
                count: rows.count)
        }
    }

    /// `Today · 9:00 PM`, `Tomorrow`, `Thu · 9:00 PM`, `Oct 12`.
    public static func whenLabel(_ date: Date, hasTime: Bool, now: Date = Date(),
                                 calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        let day: String
        switch days {
        case 0: day = "Today"
        case 1: day = "Tomorrow"
        case 2...6: day = CalendarMath.dow[CalendarMath.weekday(date, calendar)]
        default:
            let c = calendar.dateComponents([.month, .day], from: date)
            day = "\(CalendarMath.monthNames[(c.month ?? 1) - 1].prefix(3)) \(c.day ?? 1)"
        }
        guard hasTime else { return day }
        return "\(day) · \(CalendarMath.clock(date, calendar.timeZone))"
    }

    /// `just now`, `12m ago`, `3h ago`, `2d ago`, `5w ago`.
    public static func agoLabel(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60))m ago"
        case ..<86_400: return "\(Int(seconds / 3600))h ago"
        case ..<(86_400 * 14): return "\(Int(seconds / 86_400))d ago"
        default: return "\(Int(seconds / (86_400 * 7)))w ago"
        }
    }

    /// HD before 4K, like the web's edition order.
    private static func sortedTiers(_ editions: [UpNextEdition]) -> [UpNextEdition] {
        editions.enumerated().sorted { a, b in
            let x = a.element.tier == .hd ? 0 : 1, y = b.element.tier == .hd ? 0 : 1
            return x == y ? a.offset < b.offset : x < y
        }.map { $0.element }
    }
}
