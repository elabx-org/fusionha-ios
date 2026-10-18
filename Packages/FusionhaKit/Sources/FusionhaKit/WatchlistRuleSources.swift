import Foundation

/// The "Watchlists & lists" rule's source classes (`WATCHLIST_APPROVE`
/// `params.sources`, fusionha 0.4.213; the web's `rule-format.ts`, mirroring
/// `services/request_rule_sources.py`). The order is the editor's.
public enum RuleSource: String, CaseIterable, Sendable, Hashable {
    case plexWatchlist = "plex_watchlist"
    case plexLists = "plex_lists"
    case letterboxdDiary = "letterboxd_diary"
    case letterboxdWatchlist = "letterboxd_watchlist"
    case linked

    public var label: String {
        switch self {
        case .plexWatchlist: return "Plex watchlist"
        case .plexLists: return "Plex lists"
        case .letterboxdDiary: return "Letterboxd diary"
        case .letterboxdWatchlist: return "My Letterboxd watchlist"
        case .linked: return "Linked lists & followed watchlists"
        }
    }

    /// Known keys in editor order; unknown ones are dropped.
    public static func ordered(_ raw: [String]) -> [RuleSource] {
        let set = Set(raw)
        return allCases.filter { set.contains($0.rawValue) }
    }

    /// A stored rule's sources, read like the server: `sources` wins (`[]` =
    /// all), a legacy `plex_source` maps to its Plex classes (unknown = none),
    /// neither = all.
    public static func of(_ params: RequestRule.Params) -> [RuleSource] {
        if let raw = params.sources {
            let chosen = ordered(raw)
            return chosen.isEmpty ? allCases : chosen
        }
        if let legacy = params.plexSource {
            switch legacy {
            case "watchlist": return [.plexWatchlist]
            case "lists": return [.plexLists]
            case "both": return [.plexWatchlist, .plexLists]
            default: return []
            }
        }
        return allCases
    }

    /// "All automatic sources" or the comma list.
    public static func words(_ sources: [RuleSource]) -> String {
        let chosen = ordered(sources.map(\.rawValue))
        if chosen.count == allCases.count { return "All automatic sources" }
        return chosen.isEmpty ? "None selected" : chosen.map(\.label).joined(separator: ", ")
    }

    /// The editor's "Reads as" line.
    public static func sentence(_ sources: [RuleSource], tier: QualityTier?, roleName: String?) -> String {
        let all = ordered(sources.map(\.rawValue)).count == allCases.count
        let what = all ? "automatic watchlist and list" : words(sources)
        let version: String
        switch tier {
        case .none: version = "every version"
        case .some(let t): version = t == .uhd ? "UHD·4K" : "HD·1080p"
        }
        return "Approve \(what) requests for \(version) from \(roleName ?? "everyone")"
    }

    public static let note = "Matches only requests created automatically from the sources ticked: Plex watchlists and lists, a person’s Letterboxd diary, their own Letterboxd watchlist (follow or CSV), and any list or watchlist they linked. Manual requests are untouched. Guards win, and quota still applies."
}
