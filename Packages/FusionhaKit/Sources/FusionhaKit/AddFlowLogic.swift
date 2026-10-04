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

// MARK: - Sentences  (add-summary.ts, MonitorStrip's `sentence`)

public struct SummaryPart: Sendable, Hashable {
    public let text: String
    public let strong: Bool
    public init(_ text: String, strong: Bool = false) {
        self.text = text
        self.strong = strong
    }
}

public enum AddSentence {
    public static let noVersion = "Turn on at least one version."

    public struct Monitor: Sendable {
        public let mode: String
        public let count: Int
        public let exact: Bool
        public init(mode: String, count: Int, exact: Bool) {
            self.mode = mode
            self.count = count
            self.exact = exact
        }
    }

    public static func versionName(_ tier: QualityTier, edition: String?) -> String {
        AddVocab.tierLabel(tier) + (AddVocab.isStandardEdition(edition) ? "" : " · \(edition ?? "")")
    }

    private static func monitorParts(_ m: Monitor) -> [SummaryPart] {
        if m.mode == "none" { return [SummaryPart("monitors nothing")] }
        if m.mode == "future" || m.mode == "existing" { return [SummaryPart("monitors new episodes only")] }
        if !m.exact { return [SummaryPart("monitors recent and new episodes")] }
        return [SummaryPart("monitors "), SummaryPart(String(m.count), strong: true),
                SummaryPart(m.count == 1 ? " episode" : " episodes")]
    }

    /// The footer's live sentence.
    public static func summary(isSeries: Bool, versions: [(QualityTier, String?)], searchNow: Bool,
                               monitor: Monitor?, monitorUhd: Monitor?,
                               stop: (label: String, dateText: String?)?) -> [SummaryPart] {
        if versions.isEmpty { return [SummaryPart(noVersion)] }
        var parts = [SummaryPart("Adds "),
                     SummaryPart(versions.map { versionName($0.0, edition: $0.1) }.joined(separator: " + "), strong: true)]
        if isSeries, let monitor {
            parts.append(SummaryPart(" · "))
            let hasHd = versions.contains { $0.0 == .hd }
            let hasUhd = versions.contains { $0.0 == .uhd }
            if let monitorUhd, hasHd, hasUhd {
                parts.append(SummaryPart("HD "))
                parts += monitorParts(monitor)
                parts.append(SummaryPart(" · 4K "))
                parts += monitorParts(monitorUhd)
            } else {
                parts += monitorParts(!hasHd && monitorUhd != nil ? monitorUhd! : monitor)
            }
        } else if !isSeries, let stop {
            parts.append(SummaryPart(" · grabs from "))
            parts.append(SummaryPart(stop.label.lowercased(), strong: true))
            if let date = stop.dateText { parts.append(SummaryPart(" (\(date))")) }
        }
        if searchNow { parts.append(SummaryPart(" · searches now")) }
        return parts
    }

    private static func eps(_ n: Int) -> String { "\(n) \(n == 1 ? "episode" : "episodes")" }

    /// MonitorStrip's count sentence under the season list.
    public static func monitor(_ mode: String, preview p: MonitorPreview?, seasons: [SeasonCounts]?) -> [SummaryPart] {
        let t = { (s: String) in SummaryPart(s) }
        let b = { (s: String) in SummaryPart(s, strong: true) }
        let positive = (seasons ?? []).map(\.seasonNumber).filter { $0 > 0 }
        let first = positive.min() ?? 1
        let last = (seasons ?? []).map(\.seasonNumber).max()
        if mode == "none" { return [t("Monitors "), b("nothing"), t(" — it’s added but never searched automatically")] }
        if mode == "pilot" { return [t("Monitors "), b("just the pilot"), t(" (S\(first)E1)")] }
        guard let p else {
            let rule: [String: String] = [
                "all": "every episode", "missing": "every missing episode", "existing": "only episodes you already have",
                "future": "only new episodes", "recent": "recent and new episodes", "pilot": "just the pilot",
                "firstSeason": "the first season", "lastSeason": "the latest season",
                "monitorSpecials": "everything, specials included", "none": "nothing",
            ]
            let tail = mode == "all" || mode == "missing" ? " and new ones · specials off" : ""
            return [t("Monitors "), b(rule[mode] ?? mode), t(tail)]
        }
        if !p.exact {
            return [t("Monitors "), b(mode == "recent" ? "recent and new episodes" : "only new episodes"),
                    t(" — exact count after adding")]
        }
        let n = p.count
        switch mode {
        case "all":
            return [t("Monitors "), b(eps(n)),
                    t(" across \(p.seasonsTouched) \(p.seasonsTouched == 1 ? "season" : "seasons") and every new one · specials off")]
        case "missing":
            return [t("Monitors "), b("\(n) missing \(n == 1 ? "episode" : "episodes")"), t(" (you have none yet) and new ones")]
        case "existing":
            return [t("Monitors "), b("only episodes you already have"),
                    t(n > 0 ? " — none yet, so just the \(eps(n)) still to air and new ones" : " — none yet, so only new ones")]
        case "future":
            return [t("Monitors "), b("only new episodes"),
                    t(n > 0 ? " from now on (\(eps(n)) announced) — nothing that has aired" : " from now on — nothing that has aired")]
        case "recent":
            return [t("Monitors "), b("the latest \(eps(n))"), t(" and new ones")]
        case "firstSeason":
            return [t("Monitors "), b("season \(first)"), t(" (\(eps(n)))")]
        case "lastSeason":
            return [t("Monitors "), b(last == 0 ? "the specials" : "season \(last ?? first)"), t(" (\(eps(n))) and new ones")]
        case "monitorSpecials":
            return [t("Monitors "), b("everything, specials included"), t(" (\(eps(n))) and new ones")]
        default:
            return [t("Monitors "), b(eps(n))]
        }
    }

    /// The count sentence once any season is customised.
    public static func custom(_ p: MonitorPreview, adjusted: Int) -> [SummaryPart] {
        let n = p.count
        return [SummaryPart("Custom · monitors "), SummaryPart(eps(n), strong: true),
                SummaryPart(" across \(p.seasonsTouched) \(p.seasonsTouched == 1 ? "season" : "seasons")"
                            + (p.newEpisodes ? " and every new one" : "")
                            + " · \(adjusted) \(adjusted == 1 ? "season" : "seasons") adjusted")]
    }
}

// MARK: - When to grab it  (timeline.ts)

public struct TimelineDates: Sendable, Hashable {
    public var releaseDate: String?
    public var inCinemas: String?
    public var digitalRelease: String?
    public var physicalRelease: String?
    public var estimateDate: String?
    public var estimateIsEstimated: Bool

    public init(releaseDate: String? = nil, inCinemas: String? = nil, digitalRelease: String? = nil,
                physicalRelease: String? = nil, estimateDate: String? = nil, estimateIsEstimated: Bool = false) {
        self.releaseDate = releaseDate
        self.inCinemas = inCinemas
        self.digitalRelease = digitalRelease
        self.physicalRelease = physicalRelease
        self.estimateDate = estimateDate
        self.estimateIsEstimated = estimateIsEstimated
    }
}

public struct TimelineStop: Sendable, Hashable {
    /// `announced` / `inCinemas` / `released` (the minimum-availability value).
    public let key: String
    public let label: String
    public let date: String?
    public let dateText: String?
    /// `dateText` without its "est. " prefix.
    public let dateBody: String?
    public let estimated: Bool
    public let when: String?
    /// 0–100 along the track.
    public let pos: Double
}

public struct ReleaseTimelineModel: Sendable, Hashable {
    public let stops: [TimelineStop]
    /// Today's position, 0–100, or nil when no stop is dated.
    public let today: Double?

    public static let stopPos: [String: Double] = ["announced": 12, "inCinemas": 50, "released": 88]
    static let todayEnd: Double = 96
    static let easeDays: Double = 180
    private static let utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// ISO date → UTC epoch day, or nil when malformed.
    public static func isoDay(_ iso: String?) -> Int? {
        guard let iso, iso.count >= 10 else { return nil }
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, parts[0].count == 4, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        guard let date = utc.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// The viewer's calendar day as an epoch day (matches `isoDay`).
    public static func localDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let iso = String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
        return isoDay(iso) ?? 0
    }

    /// `2026-12-18` → "18 Dec 2026"; estimated → "est. Dec 2026".
    public static func formatStopDate(_ iso: String, estimated: Bool = false) -> String {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), (1...12).contains(m), let d = Int(parts[2]) else { return iso }
        let my = "\(months[m - 1]) \(parts[0])"
        return estimated ? "est. \(my)" : "\(d) \(my)"
    }

    private static func plural(_ n: Int, _ unit: String) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }

    /// "right away" / "tomorrow" / "in 5 days" / "in 3 weeks" / "in ~6 months".
    public static func relativeUntil(_ days: Int, estimated: Bool = false) -> String {
        if days <= 0 { return estimated ? "any day now" : "right away" }
        let approx = estimated ? "~" : ""
        if days == 1 && !estimated { return "tomorrow" }
        if days < 14 { return "in \(approx)\(plural(days, "day"))" }
        if days < 60 { return "in \(approx)\(plural(Int((Double(days) / 7).rounded()), "week"))" }
        if days < 548 { return "in \(approx)\(plural(Int((Double(days) / 30.44).rounded()), "month"))" }
        return "in \(approx)\(plural(Int((Double(days) / 365.25).rounded()), "year"))"
    }

    private static func clamp(_ n: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, n)) }

    /// The stops either side of Today's position (nil = the track edge).
    public static func todayBounds(_ pos: Double) -> (lo: Double?, hi: Double?) {
        let at = stopPos.values.sorted()
        return (at.filter { $0 <= pos }.last, at.first { $0 > pos })
    }

    public static func build(_ dates: TimelineDates, today: Date = Date(), calendar: Calendar = .current) -> ReleaseTimelineModel {
        let cinemaRaw = isoDay(dates.inCinemas) != nil ? dates.inCinemas : dates.releaseDate
        let cinema = isoDay(cinemaRaw) != nil ? cinemaRaw : nil
        // Released: the grab gate's estimate, else the earlier home date.
        var released: String?
        var releasedEstimated = false
        if let est = dates.estimateDate, isoDay(est) != nil {
            released = est
            releasedEstimated = dates.estimateIsEstimated
        } else {
            released = [dates.digitalRelease, dates.physicalRelease].compactMap { $0 }
                .filter { isoDay($0) != nil }
                .min { (isoDay($0) ?? 0) < (isoDay($1) ?? 0) }
        }
        let cDay = isoDay(cinema)
        let rDay = isoDay(released)
        let tDay = localDay(today, calendar: calendar)
        var anchors: [(day: Int, pos: Double)] = []
        if let cDay { anchors.append((cDay, stopPos["inCinemas"]!)) }
        if let rDay { anchors.append((rDay, stopPos["released"]!)) }
        let nextAfterLast = rDay == nil && cDay != nil ? stopPos["released"]! : todayEnd
        let releasedText = released.map { formatStopDate($0, estimated: releasedEstimated) }

        var todayPos: Double?
        if let first = anchors.first, let last = anchors.last {
            if tDay < first.day {
                let f = clamp(1 - Double(first.day - tDay) / easeDays, 0.1, 0.9)
                todayPos = stopPos["announced"]! + (first.pos - stopPos["announced"]!) * f
            } else if tDay >= last.day {
                let f = clamp(Double(tDay - last.day) / easeDays, 0.1, 0.9)
                todayPos = last.pos + (nextAfterLast - last.pos) * f
            } else {
                todayPos = first.pos + Double(tDay - first.day) / Double(last.day - first.day) * (last.pos - first.pos)
            }
        }
        let cinemaText = cinema.map { formatStopDate($0) } ?? "date unknown"
        let stops = [
            TimelineStop(key: "announced", label: "Announced", date: nil, dateText: "now", dateBody: "now",
                         estimated: false, when: "right away", pos: stopPos["announced"]!),
            TimelineStop(key: "inCinemas", label: "In cinemas", date: cinema, dateText: cinemaText, dateBody: cinemaText,
                         estimated: false, when: cDay.map { relativeUntil($0 - tDay) }, pos: stopPos["inCinemas"]!),
            TimelineStop(key: "released", label: "Released", date: released, dateText: releasedText,
                         dateBody: releasedText.map { releasedEstimated && $0.hasPrefix("est. ") ? String($0.dropFirst(5)) : $0 },
                         estimated: released != nil && releasedEstimated,
                         when: rDay.map { relativeUntil($0 - tDay, estimated: releasedEstimated) }, pos: stopPos["released"]!),
        ]
        return ReleaseTimelineModel(stops: stops, today: todayPos)
    }

    /// A confirmed (not estimated) Released date is today or earlier.
    public func releasedOut(today: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let r = stops.first(where: { $0.key == "released" }), !r.estimated,
              let day = Self.isoDay(r.date) else { return false }
        return day <= Self.localDay(today, calendar: calendar)
    }

    /// Whether an ISO date is today or earlier in the viewer's calendar.
    public static func isPast(_ iso: String, today: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let day = isoDay(iso) else { return false }
        return day <= localDay(today, calendar: calendar)
    }

    /// "Starts searching at **in cinemas** · 18 Dec 2026 · in 3 months".
    public static func caption(_ stop: TimelineStop) -> [SummaryPart] {
        var parts = [SummaryPart("Starts searching at "), SummaryPart(stop.label.lowercased(), strong: true)]
        if stop.key != "announced", let text = stop.dateText { parts.append(SummaryPart(" · \(text)")) }
        if let when = stop.when { parts.append(SummaryPart(" · \(when)")) }
        return parts
    }

    /// "Why?" — when searching starts, and why.
    public static func grabNote(_ stop: TimelineStop, today: Date = Date(), calendar: Calendar = .current) -> [SummaryPart] {
        let t = { (s: String) in SummaryPart(s) }
        let b = { (s: String) in SummaryPart(s, strong: true) }
        if stop.key == "announced" {
            return [t("Searches "), b("right away"), t(". Early releases are often fakes or cam copies.")]
        }
        if stop.key == "inCinemas" {
            let tail = " Expect cinema-quality copies first."
            guard let date = stop.date else {
                return [t("Starts searching "), b("when it opens in cinemas"), t(" (date unknown).\(tail)")]
            }
            if isPast(date, today: today, calendar: calendar) {
                return [t("Searches "), b("right away"), t(". It’s been in cinemas since \(stop.dateText ?? "").")]
            }
            return [t("Starts searching "), b(stop.dateText ?? ""), t(", when it opens in cinemas.\(tail)")]
        }
        if let date = stop.date, !stop.estimated, isPast(date, today: today, calendar: calendar) {
            return [t("Searches "), b("right away"), t(". It’s out for home since \(stop.dateText ?? "").")]
        }
        return [t("Starts searching when it’s "), b("released for home"),
                t(" (digital or disc, \(stop.dateText ?? "date unknown")). The usual choice for good copies.")]
    }
}
