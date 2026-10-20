import Foundation

// Pure Add title v2 logic, ported line by line from the web
// (frontend/src/components/library/add/*.ts and lib/title-year.ts) so the iOS
// sheet shows the same counts, sentences and dates.

// MARK: - Vocabulary

public enum AddVocab {
    /// `MONITOR_OPTIONS`: Sonarr's ten series monitor modes, in its order.
    public static let monitorOptions: [(value: String, label: String)] = [
        ("all", "All"), ("future", "Future"), ("missing", "Missing"), ("existing", "Existing"),
        ("recent", "Recent"), ("pilot", "Pilot"), ("firstSeason", "First Season"),
        ("lastSeason", "Last Season"), ("monitorSpecials", "Monitor Specials"), ("none", "None"),
    ]

    public static func monitorLabel(_ value: String) -> String {
        monitorOptions.first { $0.value == value }?.label ?? value
    }

    /// `MIN_AVAIL_LABEL`.
    public static func minAvailLabel(_ value: String) -> String {
        switch value {
        case "announced": return "Announced"
        case "inCinemas": return "In Cinemas"
        case "released": return "Released"
        default: return value
        }
    }

    /// `TIER_LABEL`.
    public static func tierLabel(_ tier: QualityTier) -> String { tier == .hd ? "HD·1080p" : "UHD·4K" }

    /// A Standard (or blank) edition is the default cut and is never sent.
    public static func isStandardEdition(_ edition: String?) -> Bool {
        guard let edition else { return true }
        let trimmed = edition.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.lowercased() == "standard"
    }

    /// `lastAddedSummary`: "HD + 4K · monitor Future".
    public static func lastAddedSummary(_ last: LastAdded, isSeries: Bool) -> String {
        let tiers = last.versions.map { $0.tier == .uhd ? "4K" : "HD" }.joined(separator: " + ")
        var parts: [String] = []
        if !tiers.isEmpty { parts.append(tiers) }
        if isSeries {
            if let monitor = last.monitor { parts.append("monitor \(monitorLabel(monitor))") }
        } else if let min = last.minimumAvailability, !min.isEmpty {
            parts.append("grab when \(minAvailLabel(min))")
        }
        if isSeries, let type = last.seriesType, type != "standard", !type.isEmpty { parts.append(type) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Title + year  (lib/title-year.ts)

public enum TitleYear {
    /// `["Monster", 2022]` for `"Monster (2022)"`; `[title, nil]` otherwise.
    public static func splitTrailingYear(_ title: String) -> (String, Int?) {
        guard let regex = try? NSRegularExpression(pattern: #"^(.*\S)\s*\(((?:18|19|20)[0-9]{2})\)\s*$"#),
              let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
              let bare = Range(match.range(at: 1), in: title),
              let year = Range(match.range(at: 2), in: title) else { return (title, nil) }
        return (String(title[bare]), Int(title[year]))
    }

    /// `Title (Year)`: unchanged when the title already ends in a year.
    public static func titleWithYear(_ title: String, _ year: Int?) -> String {
        if splitTrailingYear(title).1 != nil { return title.trimmingCharacters(in: .whitespaces) }
        if let year { return "\(title) (\(year))" }
        return title
    }

    /// The bare title plus the year to show beside it.
    public static func display(_ title: String, _ year: Int?) -> (title: String, year: Int?) {
        let (bare, embedded) = splitTrailingYear(title)
        return (bare, year ?? embedded)
    }
}

// MARK: - Monitor preview  (monitor-preview.ts)

/// One season's counts, as the preview sends them.
public struct SeasonCounts: Sendable, Hashable {
    public let seasonNumber: Int
    public let episodeCount: Int
    public let airedCount: Int?
    public let recentCount: Int?

    public init(seasonNumber: Int, episodeCount: Int, airedCount: Int?, recentCount: Int?) {
        self.seasonNumber = seasonNumber
        self.episodeCount = episodeCount
        self.airedCount = airedCount
        self.recentCount = recentCount
    }
}

public struct MonitorPreview: Sendable, Hashable {
    public struct SeasonLit: Sendable, Hashable {
        public let seasonNumber: Int
        /// Lit episode indexes (0-based, air order).
        public let lit: [Int]
    }

    public let perSeason: [SeasonLit]
    public let newEpisodes: Bool
    public let count: Int
    public let seasonsTouched: Int
    public let exact: Bool

    private static let dateDriven: Set<String> = ["future", "existing", "recent"]
    private static let watchesNew: Set<String> = ["all", "missing", "future", "existing", "recent", "lastSeason", "monitorSpecials"]

    /// A mirror of the backend's `_episode_monitored` at add time, worked on season counts.
    public static func compute(_ seasons: [SeasonCounts], mode: String) -> MonitorPreview {
        let positive = seasons.map(\.seasonNumber).filter { $0 > 0 }
        let first = positive.min()
        let last = seasons.map(\.seasonNumber).max()
        let airedKnown = seasons.allSatisfy { $0.airedCount != nil }
        let exact = airedKnown || !dateDriven.contains(mode)
        let per: [SeasonLit] = seasons.map { s in
            let n = max(0, s.episodeCount)
            let aired = min(n, max(0, s.airedCount ?? 0))
            let recent = min(aired, max(0, s.recentCount ?? 0))
            let regular = s.seasonNumber > 0
            var lit: [Int] = []
            switch mode {
            case "none":
                break
            case "all", "missing":
                if regular { lit = Array(0..<n) }
            case "future", "existing":
                if airedKnown { lit = Array(aired..<max(aired, n)) }
            case "recent":
                if airedKnown { lit = Array((aired - recent)..<max(aired - recent, n)) }
            case "pilot":
                if s.seasonNumber == first && n > 0 { lit = [0] }
            case "firstSeason":
                if let first, s.seasonNumber == first { lit = Array(0..<n) }
            case "lastSeason":
                if s.seasonNumber == last { lit = Array(0..<n) }
            case "monitorSpecials":
                lit = Array(0..<n)
            default:
                if regular { lit = Array(0..<n) }
            }
            return SeasonLit(seasonNumber: s.seasonNumber, lit: lit)
        }
        return MonitorPreview(perSeason: per, newEpisodes: watchesNew.contains(mode),
                              count: per.reduce(0) { $0 + $1.lit.count },
                              seasonsTouched: per.filter { !$0.lit.isEmpty }.count, exact: exact)
    }

    func replacing(_ per: [SeasonLit]) -> MonitorPreview {
        MonitorPreview(perSeason: per, newEpisodes: newEpisodes, count: per.reduce(0) { $0 + $1.lit.count },
                       seasonsTouched: per.filter { !$0.lit.isEmpty }.count, exact: exact)
    }
}

// MARK: - Season slider  (season-from.ts)

/// Season number → first monitored episode NUMBER (nil = none of the season).
public typealias SeasonFrom = [Int: Int?]

public enum SeasonSlider {
    /// The preview with each customised season re-lit from its start.
    public static func apply(_ seasons: [SeasonCounts], _ preview: MonitorPreview, _ from: SeasonFrom) -> MonitorPreview {
        if from.isEmpty { return preview }
        let per: [MonitorPreview.SeasonLit] = preview.perSeason.enumerated().map { i, s in
            guard let start = from[s.seasonNumber] else { return s }
            let n = max(0, i < seasons.count ? seasons[i].episodeCount : 0)
            let lit: [Int]
            if let start {
                let lo = max(0, start - 1)
                lit = lo < n ? Array(lo..<n) : []
            } else {
                lit = []
            }
            return MonitorPreview.SeasonLit(seasonNumber: s.seasonNumber, lit: lit)
        }
        return preview.replacing(per)
    }

    /// The first custom action builds on All.
    public static func materialise(_ seasons: [SeasonCounts], mode: String) -> SeasonFrom {
        let current = MonitorPreview.compute(seasons, mode: mode).perSeason
        let all = MonitorPreview.compute(seasons, mode: "all").perSeason
        var out: SeasonFrom = [:]
        for (i, s) in current.enumerated() {
            let base = i < all.count ? all[i].lit : []
            if s.lit == base { continue }
            let value: Int? = s.lit.isEmpty ? nil : (s.lit.min() ?? 0) + 1
            out.updateValue(value, forKey: s.seasonNumber)
        }
        return out
    }

    /// A fully lit season goes off (nil), anything else fully on (1).
    public static func toggled(litCount: Int, episodeCount: Int) -> Int? {
        episodeCount > 0 && litCount >= episodeCount ? nil : 1
    }

    /// A committed slide: 0-based first lit position → episode number, nil when nothing.
    public static func start(from0: Int, episodeCount: Int) -> Int? {
        from0 >= episodeCount ? nil : max(0, from0) + 1
    }

    /// The add payload's `season_monitor_from`, or nil when nothing is custom.
    public static func payload(_ from: SeasonFrom) -> [SeasonStart]? {
        if from.isEmpty { return nil }
        return from.keys.sorted().map { SeasonStart(seasonNumber: $0, fromEpisode: from[$0] ?? nil) }
    }

    /// The 0-based first lit episode for a drag at `ratio` across the bar.
    public static func from(ratio: Double, episodeCount: Int) -> Int {
        Int((min(1, max(0, ratio)) * Double(episodeCount)).rounded())
    }

    /// The bubble over the finger while sliding.
    public static func bubble(from: Int, episodeCount: Int) -> String {
        let n = episodeCount - from
        if n <= 0 { return "None" }
        if from == 0 { return "Whole season · \(n)" }
        return "From E\(from + 1) · \(n) \(n == 1 ? "episode" : "episodes")"
    }
}
