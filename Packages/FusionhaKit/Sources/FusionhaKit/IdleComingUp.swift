import Foundation

// MARK: - Coming up next (web `idle-derive.ts` → `deriveComingUp`)
//
// Monitored, still-wanted airings in the next 48 hours from the shared calendar
// feed, one row per title per day (two episodes the same day fold into a range),
// grouped by day. What already sits on disk and what airs later go to the footer.

public struct ComingRow: Sendable, Hashable, Identifiable {
    public let key: String
    public let itemId: Int
    public let title: String
    public let posterUrl: String?
    public let isMovie: Bool
    /// `S02E03`, `S13E07–E08`, or the movie's release type.
    public let se: String
    public let episodeTitle: String
    public let air: Date
    /// Monitored tiers still wanted, HD first: one rail each.
    public let tiers: [QualityTier]
    public let premiere: Bool
    public let count: Int
    /// The very next airing: the row that carries the "next up" wash.
    public let next: Bool
    public var id: String { key }
}

public struct ComingDay: Sendable, Hashable, Identifiable {
    public let key: String
    public let day: Date
    public var count: Int
    public var rows: [ComingRow]
    public var id: String { key }
}

public struct ComingAside: Sendable, Hashable, Identifiable {
    public let key: String
    public let title: String
    public let se: String
    public let tiers: [QualityTier]
    public let note: String?
    public var id: String { key }
}

public struct ComingUp: Sendable, Hashable {
    public let days: [ComingDay]
    public let episodes: Int
    public let titles: Int
    /// Airing in the window but every monitored version is already on disk.
    public let already: [ComingAside]
    /// Wanted, but after the window (or a theatrical release, never grabbed).
    public let later: [ComingAside]
    public var rows: [ComingRow] { days.flatMap(\.rows) }
}

public enum IdleComingUp {
    public static let window: TimeInterval = 48 * 3600
    static let laterLimit = 3
    static let tierOrder: [QualityTier] = [.hd, .uhd]

    private struct Pick { let e: CalendarEntry; let at: Date; let tiers: [QualityTier] }
    private struct Bucket { var entries: [CalendarEntry]; var at: Date; var tiers: Set<QualityTier>; let order: Int }

    /// The airing instant: `air_datetime` (UTC), else local midnight of `date`.
    public static func airDate(_ e: CalendarEntry, calendar: Calendar = .current) -> Date? {
        if let precise = e.airDatetime, let d = ServerTime.parse(precise) { return d }
        let parts = e.date.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// True when the instant falls in the coming 48 h (after now, at most now + 48 h).
    public static func inWindow(_ at: Date, now: Date) -> Bool {
        at > now && at <= now.addingTimeInterval(window)
    }

    public static func derive(_ entries: [CalendarEntry], now: Date, calendar: Calendar = .current) -> ComingUp {
        var wanted: [Pick] = [], have: [Pick] = [], later: [Pick] = []
        for e in entries {
            guard let at = airDate(e, calendar: calendar), at > now else { continue }
            let want = tiers(e) { $0 != .downloaded }
            let theatrical = e.type == "movie" && e.releaseType == "theatrical"
            if !want.isEmpty && (!inWindow(at, now: now) || theatrical) {
                later.append(Pick(e: e, at: at, tiers: want))
            } else if !want.isEmpty {
                wanted.append(Pick(e: e, at: at, tiers: want))
            } else if inWindow(at, now: now) {
                let all = tiers(e) { _ in true }
                if !all.isEmpty { have.append(Pick(e: e, at: at, tiers: all)) }
            }
        }

        let rows = bucket(wanted, byDay: true, calendar: calendar).enumerated().map { i, kb -> ComingRow in
            let (key, b) = kb
            let first = b.entries[0]
            return ComingRow(
                key: key, itemId: first.itemId, title: first.title, posterUrl: first.posterUrl,
                isMovie: first.type == "movie", se: se(b.entries),
                episodeTitle: b.entries.compactMap(\.episodeTitle).filter { !$0.isEmpty }.joined(separator: " · "),
                air: b.at, tiers: tierOrder.filter { b.tiers.contains($0) },
                premiere: first.type == "episode" && b.entries.contains { $0.episodeNumber == 1 },
                count: b.entries.count, next: i == 0)
        }

        var days: [ComingDay] = []
        for row in rows {
            let k = dayKey(row.air, calendar)
            if let i = days.firstIndex(where: { $0.key == k }) {
                days[i].rows.append(row)
                days[i].count += row.count
            } else {
                days.append(ComingDay(key: k, day: row.air, count: row.count, rows: [row]))
            }
        }

        return ComingUp(days: days,
                        episodes: rows.reduce(0) { $0 + $1.count },
                        titles: Set(rows.map(\.itemId)).count,
                        already: aside(have, limit: nil, calendar: calendar),
                        later: aside(later, limit: laterLimit, calendar: calendar))
    }

    /// `S13E07–E08` for a contiguous run, `S02E02 · E05` otherwise.
    public static func episodeRange(season: Int, episodes: [Int]) -> String {
        let sorted = Array(Set(episodes)).sorted()
        let first = sorted.first ?? 0
        let last = sorted.last ?? first
        if last - first == sorted.count - 1 {
            return EpisodeCode.range(season: season, first: first, last: last, separator: "")
        }
        let head = EpisodeCode.episode(season: season, episode: first, separator: "")
        return ([head] + sorted.dropFirst().map { "E\(EpisodeCode.num($0))" }).joined(separator: " · ")
    }

    // MARK: Helpers

    private static func tiers(_ e: CalendarEntry, _ want: (EditionStatus) -> Bool) -> [QualityTier] {
        let set = Set(e.editions.filter { $0.monitored && want($0.status) }.map(\.tier))
        return tierOrder.filter { set.contains($0) }
    }

    private static func dayKey(_ d: Date, _ calendar: Calendar) -> String { IdleTime.isoDay(d, calendar) }

    /// Buckets by title (and day), soonest first; ties keep feed order (JS sort is stable).
    private static func bucket(_ list: [Pick], byDay: Bool, calendar: Calendar) -> [(String, Bucket)] {
        var buckets: [String: Bucket] = [:]
        for p in list {
            let key = byDay ? "\(p.e.itemId)|\(dayKey(p.at, calendar))" : "\(p.e.itemId)"
            var b = buckets[key] ?? Bucket(entries: [], at: p.at, tiers: [], order: buckets.count)
            b.entries.append(p.e)
            b.at = min(b.at, p.at)
            b.tiers.formUnion(p.tiers)
            buckets[key] = b
        }
        return buckets.sorted { $0.value.at != $1.value.at ? $0.value.at < $1.value.at : $0.value.order < $1.value.order }
            .map { ($0.key, $0.value) }
    }

    private static func se(_ entries: [CalendarEntry]) -> String {
        guard let first = entries.first else { return "Release" }
        if first.type == "movie" { return first.releaseType ?? "Release" }
        return episodeRange(season: first.seasonNumber ?? 0, episodes: entries.map { $0.episodeNumber ?? 0 })
    }

    private static func aside(_ list: [Pick], limit: Int?, calendar: Calendar) -> [ComingAside] {
        let all = bucket(list, byDay: false, calendar: calendar)
        return all.prefix(limit ?? all.count).map { key, b in
            let first = b.entries[0]
            let movie = first.type == "movie"
            return ComingAside(key: key, title: first.title, se: movie ? "" : se(b.entries),
                               tiers: tierOrder.filter { b.tiers.contains($0) },
                               note: movie ? first.releaseType : nil)
        }
    }
}
