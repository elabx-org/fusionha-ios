import Foundation

// MARK: - Recently arrived (Home's second timeline page, owner 2026-11-09)

/// One title's imports on one day: a season pack, a new episode, an
/// upgrade or a second copy landing all count, unlike Recently added,
/// which only moves when a title joins the library.
public struct ArrivalRow: Sendable, Hashable, Identifiable {
    public let itemId: Int
    /// The local day it landed (start of day).
    public let day: Date
    /// The newest import of the group.
    public let latest: Date
    /// Season and episode numbers, newest first as they came in; empty for a movie.
    public let episodes: [EpisodeRef]
    /// The versions that received a file, HD before 4K.
    public let tiers: [QualityTier]
    public let imports: Int
    public var id: String { "\(itemId)-\(Int(day.timeIntervalSince1970))" }
}

public struct EpisodeRef: Sendable, Hashable {
    public let season: Int
    public let episode: Int
    public init(season: Int, episode: Int) {
        self.season = season
        self.episode = episode
    }
}

public enum RecentArrivals {
    /// History rows fetched per page (`event_type=imported`).
    public static let pageSize = 200

    /// Imports grouped per title per local day, newest first.
    public static func rows(_ history: [HistoryEntry], calendar: Calendar = .current) -> [ArrivalRow] {
        let dated = history
            .filter { $0.eventType.uppercased() == "IMPORTED" && $0.mediaItemId != nil }
            .compactMap { h in ServerTime.parse(h.createdAt).map { (h, $0) } }
            .sorted { $0.1 > $1.1 }
        var order: [String] = []
        var groups: [String: [(HistoryEntry, Date)]] = [:]
        for (h, at) in dated {
            let day = calendar.startOfDay(for: at)
            let key = "\(h.mediaItemId ?? 0)-\(Int(day.timeIntervalSince1970))"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append((h, at))
        }
        return order.compactMap { key in
            guard let g = groups[key], let head = g.first, let id = head.0.mediaItemId else { return nil }
            var seen = Set<EpisodeRef>()
            let episodes = g.compactMap { episode(in: $0.0) }.filter { seen.insert($0).inserted }
            let tiers = [QualityTier.hd, .uhd].filter { t in g.contains { $0.0.tier == t } }
            return ArrivalRow(itemId: id, day: calendar.startOfDay(for: head.1), latest: head.1,
                              episodes: episodes, tiers: tiers, imports: g.count)
        }
    }

    /// What landed: "S02E01", "S01E01–E06", "S02E02, E05", "7 episodes",
    /// or for a movie the copies ("4K copy", "HD and 4K copies").
    public static func what(_ row: ArrivalRow) -> String {
        guard !row.episodes.isEmpty else {
            switch row.tiers {
            case [.hd]: return "HD copy"
            case [.uhd]: return "4K copy"
            case [.hd, .uhd]: return "HD and 4K copies"
            default: return row.imports == 1 ? "1 file" : "\(row.imports) files"
            }
        }
        let seasons = Set(row.episodes.map(\.season))
        guard seasons.count == 1, let season = seasons.first else { return "\(row.episodes.count) episodes" }
        let numbers = row.episodes.map(\.episode).sorted()
        if numbers.count == 1 { return EpisodeCode.episode(season: season, episode: numbers[0], separator: "") }
        if let first = numbers.first, let last = numbers.last, last - first == numbers.count - 1 {
            return EpisodeCode.range(season: season, first: first, last: last, separator: "")
        }
        if numbers.count <= 3 {
            let head = EpisodeCode.episode(season: season, episode: numbers[0], separator: "")
            return ([head] + numbers.dropFirst().map { "E\(EpisodeCode.num($0))" }).joined(separator: ", ")
        }
        return "\(numbers.count) episodes · \(EpisodeCode.season(season))"
    }

    /// When: "Just now", "29 min ago", "3 h ago" today; else the time ("08:03").
    public static func when(_ row: ArrivalRow, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard calendar.isDate(row.latest, inSameDayAs: now) else {
            var style = Date.FormatStyle(date: .omitted, time: .shortened)
            style.timeZone = calendar.timeZone
            return row.latest.formatted(style)
        }
        let minutes = max(0, Int(now.timeIntervalSince(row.latest) / 60))
        if minutes < 1 { return "Just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        return "\(minutes / 60) h ago"
    }

    public static func note(_ row: ArrivalRow, now: Date = Date(), calendar: Calendar = .current) -> String {
        "\(what(row)) · \(when(row, now: now, calendar: calendar))"
    }

    /// The episode from the imported file's path (a pack's release name has
    /// only the season), else from the release name.
    static func episode(in h: HistoryEntry) -> EpisodeRef? {
        for text in [h.data?["relative_path"]?.text, h.sourceTitle] {
            guard let text, let ref = code(in: text) else { continue }
            return ref
        }
        return nil
    }

    private static let pattern = try? NSRegularExpression(pattern: #"S(\d{1,2})E(\d{1,3})"#, options: .caseInsensitive)

    private static func code(in text: String) -> EpisodeRef? {
        guard let m = pattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let sr = Range(m.range(at: 1), in: text), let er = Range(m.range(at: 2), in: text),
              let s = Int(text[sr]), let e = Int(text[er]) else { return nil }
        return EpisodeRef(season: s, episode: e)
    }
}
