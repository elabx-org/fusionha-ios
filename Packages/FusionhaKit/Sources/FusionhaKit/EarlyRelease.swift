import Foundation

// MARK: - Early release  (fusionha 0.4.242–0.4.243, detail reads only)
//
// A movie's digital and/or physical stage PROVEN out before TMDB's listed
// date: corroborated home-media releases were spotted on the indexers. The
// detail item and each of its versions carry it; lists never show it (owner
// rule, same as the web). Every string the title page shows comes from
// `EarlyReleaseCopy`, a port of the web's `early-release-model.ts`, so the
// two clients never disagree.

public struct EarlyRelease: Decodable, Sendable, Hashable {
    /// "physical" (Blu-ray / remux, which also proves digital) or "digital".
    public let stage: String
    /// The day it was proven early, "YYYY-MM-DD".
    public let provenAt: String
    public let groups: Int?
    public let indexers: Int?
    public let releases: Int?
    /// Up to five corroborating releases, most indexers first.
    public let spotted: [EarlySpotted]?
    /// The earliest day an indexer says one was posted (0.4.243); nil when unknown.
    public let firstPostedAt: String?

    public init(stage: String, provenAt: String, groups: Int? = nil, indexers: Int? = nil,
                releases: Int? = nil, spotted: [EarlySpotted]? = nil, firstPostedAt: String? = nil) {
        self.stage = stage
        self.provenAt = provenAt
        self.groups = groups
        self.indexers = indexers
        self.releases = releases
        self.spotted = spotted
        self.firstPostedAt = firstPostedAt
    }
}

public struct EarlySpotted: Decodable, Sendable, Hashable, Identifiable {
    public let title: String
    public let indexers: Int
    public let size: Double?
    public var id: String { title }

    public init(title: String, indexers: Int, size: Double? = nil) {
        self.title = title
        self.indexers = indexers
        self.size = size
    }
}

public enum EarlyReleaseCopy {
    /// Does the proof cover this timeline step? Digital by either stage,
    /// Physical only by a physical proof, Cinema never.
    public static func covers(_ early: EarlyRelease?, kind: String) -> Bool {
        guard let early else { return false }
        if kind == "digital" { return true }
        return kind == "physical" && early.stage == "physical"
    }

    /// "7 Nov" (in the reader's locale); the year only when it differs from `ref`'s.
    public static func shortDate(_ iso: String, ref: String, locale: Locale = .current) -> String {
        guard let date = day(iso) else { return iso }
        var style = Date.FormatStyle(timeZone: utc).locale(locale).day().month(.abbreviated)
        if iso.prefix(4) != ref.prefix(4) { style = style.year() }
        return date.formatted(style)
    }

    /// "Out early · 7 Nov".
    public static func chip(_ early: EarlyRelease, locale: Locale = .current) -> String {
        "Out early · \(shortDate(early.provenAt, ref: early.provenAt, locale: locale))"
    }

    /// "Out early · 25 releases" ("Out early" once the evidence was pruned).
    public static func headline(_ early: EarlyRelease) -> String {
        let n = early.releases ?? 0
        return n > 0 ? "Out early · \(count(n, "release"))" : "Out early"
    }

    /// "Spotted on 11 indexers · 18 groups".
    public static func counts(_ early: EarlyRelease) -> String {
        "Spotted on \(count(early.indexers ?? 0, "indexer")) · \(count(early.groups ?? 0, "group"))"
    }

    /// "Spotted on 11 indexers · 18 groups, first posted 4 Nov. TMDB lists
    /// 17 Nov, but the movie is already out."
    public static func evidence(_ early: EarlyRelease, listed: String?, locale: Locale = .current) -> String {
        let when = early.firstPostedAt.map { "first posted \(shortDate($0, ref: early.provenAt, locale: locale))" }
            ?? "confirmed \(shortDate(early.provenAt, ref: early.provenAt, locale: locale))"
        let lists = listed.map { " TMDB lists \(shortDate($0, ref: early.provenAt, locale: locale)), but the movie is already out." }
            ?? " The movie is already out."
        return "\(counts(early)), \(when).\(lists)"
    }

    /// What was spotted, read from the release names: "UHD Blu-ray remux", "Blu-ray", "WEB-DL".
    public static func kinds(_ spotted: [EarlySpotted]) -> [String] {
        var out: [String] = []
        func add(_ k: String) { if !out.contains(k) { out.append(k) } }
        for s in spotted {
            let t = s.title
            let uhd = t.range(of: #"\b(2160p|uhd|4k)\b"#, options: [.regularExpression, .caseInsensitive]) != nil ? "UHD " : ""
            if t.range(of: #"\bremux\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                add("\(uhd)Blu-ray remux")
            } else if t.range(of: #"\b(blu-?ray|bdrip|brrip)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                add("\(uhd)Blu-ray")
            } else if t.range(of: #"\bweb[-. ]?(dl|rip)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                add("WEB-DL")
            }
        }
        return out
    }

    /// "UHD Blu-ray remux and UHD Blu-ray spotted on 11 indexers · 18 groups".
    public static func versionSummary(_ early: EarlyRelease) -> String {
        let k = kinds(early.spotted ?? [])
        let what = k.isEmpty ? count(max(early.releases ?? 0, 1), "release") : k.joined(separator: " and ")
        return "\(what) spotted on \(count(early.indexers ?? 0, "indexer")) · \(count(early.groups ?? 0, "group"))"
    }

    /// "7 indexers" (the size goes beside it, formatted by the app).
    public static func indexers(_ s: EarlySpotted) -> String { count(s.indexers, "indexer") }

    private static func count(_ n: Int, _ one: String) -> String { "\(n) \(n == 1 ? one : one + "s")" }

    private static let utc = TimeZone(identifier: "UTC")!

    static func day(_ iso: String) -> Date? {
        let parts = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
