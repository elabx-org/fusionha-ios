import Foundation

/// The Rules lane's "Plex watchlist checks" and "Letterboxd & list checks"
/// cards (fusionha 0.4.209 / 0.4.213; the web's `watchlist-checks.ts` and
/// `letterboxd-checks.ts`). The server clamps every value too.
public enum SourceChecksCopy {
    public static let intervalKey = "plex_watchlist_interval_minutes"
    public static let maxNewKey = "request_source_max_new_per_sync"
    public static let diaryKey = "letterboxd_rss_interval_hours"
    public static let listsKey = "request_list_sync_interval_hours"

    public static let intervalRange = 5...1440
    public static let maxNewRange = 1...50
    public static let hoursRange = 1...168
    public static let presets = [5, 10, 30, 60, 360, 1440]

    public static func presetLabel(_ m: Int) -> String {
        if m == 1440 { return "Daily" }
        return m >= 60 ? "\(m / 60) h" : "\(m) min"
    }

    /// "every 10 minutes", "every hour", "every 6 hours", "once a day".
    public static func humanInterval(_ m: Int) -> String {
        if m >= 1440 { return "once a day" }
        if m % 60 == 0 { return m == 60 ? "every hour" : "every \(m / 60) hours" }
        return "every \(m) minutes"
    }

    public static func hoursWord(_ h: Int) -> String { "\(h) hour\(h == 1 ? "" : "s")" }

    public static func estimateLine(people: Int, minutes: Int) -> String {
        let perMinute = String(format: "%.2f", Double(people) / Double(max(1, minutes)))
        return "With \(people) \(people == 1 ? "person" : "people") opted in, each is read \(humanInterval(minutes)): about \(perMinute) plex.tv lookups a minute in total."
    }

    public static func letterboxdEstimateLine(people: Int, sources: Int, diaryHours: Int) -> String {
        let perHour = String(format: "%.2f", Double(people) / Double(max(1, diaryHours)))
        return "With \(people) \(people == 1 ? "person" : "people") connected and \(sources) linked source\(sources == 1 ? "" : "s"): about \(perHour) diary reads an hour, plus at most one Letterboxd page every 2 seconds (20 pages per list)."
    }

    public static let adminOnly = "Only an admin can change these"
}
