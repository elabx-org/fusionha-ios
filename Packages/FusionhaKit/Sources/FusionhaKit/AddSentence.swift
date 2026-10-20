import Foundation

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
