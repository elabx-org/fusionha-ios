import Foundation

/// What approving a season-scoped series request does (web `scope-format.ts`),
/// worded only as far as the backend guarantees it.
public enum RequestScope {
    public static let later = "seasons that air later follow · other seasons stay off"

    /// The requested tiers the title already holds, split by whether approve
    /// would widen them (an unmonitored existing version is left alone).
    public struct Existing: Sendable, Hashable {
        public let monitored: [QualityTier]
        public let unmonitored: [QualityTier]
        public init(monitored: [QualityTier], unmonitored: [QualityTier]) {
            self.monitored = monitored
            self.unmonitored = unmonitored
        }
    }

    public struct Copy: Sendable, Hashable {
        /// "Monitors", "Adds", "Requested", or "" when the line leads with a sentence.
        public let verb: String
        public let head: String
        public let tail: String
        /// "Seasons that air later follow" is a real claim (a version is created).
        public let later: Bool

        /// The bold lead ("Adds Seasons 1–2").
        public var lead: String { [verb, head].filter { !$0.isEmpty }.joined(separator: " ") }
        public var text: String { lead + tail }
    }

    static func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : String(n) }

    /// "1–3, 5" from a set of numbers.
    static func runs(_ nums: [Int], _ fmt: (Int) -> String = { String($0) }) -> String {
        let sorted = Array(Set(nums)).sorted()
        var parts: [String] = []
        var i = 0
        while i < sorted.count {
            var j = i
            while j + 1 < sorted.count && sorted[j + 1] == sorted[j] + 1 { j += 1 }
            parts.append(j > i ? "\(fmt(sorted[i]))–\(fmt(sorted[j]))" : fmt(sorted[i]))
            i = j + 1
        }
        return parts.joined(separator: ", ")
    }

    /// Season → first wanted episode, for seasons asked by episode only.
    static func episodeStarts(_ r: MediaRequest) -> [(season: Int, episode: Int)] {
        let whole = Set(r.seasons ?? [])
        var starts: [Int: Int] = [:]
        for e in r.episodes ?? [] where !whole.contains(e.season) {
            starts[e.season] = min(starts[e.season] ?? e.episode, e.episode)
        }
        return starts.keys.sorted().map { ($0, starts[$0]!) }
    }

    public static func isScoped(_ r: MediaRequest) -> Bool {
        r.kind != .movie && (!(r.seasons ?? []).isEmpty || !(r.episodes ?? []).isEmpty)
    }

    /// "Seasons 1–2", "Season 4 from E5", "Specials"; nil when not season-scoped.
    public static func head(_ r: MediaRequest, fromEpisode: Bool = true) -> String? {
        guard isScoped(r) else { return nil }
        let seasons = r.seasons ?? []
        var parts: [String] = []
        if seasons.contains(0) { parts.append("Specials") }
        let real = seasons.filter { $0 > 0 }
        if !real.isEmpty { parts.append("\(real.count > 1 ? "Seasons" : "Season") \(runs(real))") }
        let eps = episodeStarts(r).map { s in
            s.season == 0 ? "Specials" : (fromEpisode ? "Season \(s.season) from E\(s.episode)" : "Season \(s.season)")
        }
        return ([parts.joined(separator: ", ")] + eps).filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The board chip: "S01–S02", "S01, S03", "S04·E5+", "Specials".
    public static func chip(_ r: MediaRequest) -> String? {
        guard isScoped(r) else { return nil }
        let seasons = r.seasons ?? []
        var parts: [String] = []
        if seasons.contains(0) { parts.append("Specials") }
        let real = seasons.filter { $0 > 0 }
        if !real.isEmpty { parts.append(runs(real) { "S\(pad($0))" }) }
        for s in episodeStarts(r) { parts.append(s.season == 0 ? "Specials" : "S\(pad(s.season))·E\(s.episode)+") }
        return parts.joined(separator: ", ")
    }

    static func names(_ tiers: [QualityTier]) -> String { tiers.map(\.chipLabel).joined(separator: " + ") }

    /// The scope line; `existing == nil` while triage hasn't loaded.
    public static func copy(_ r: MediaRequest, existing: Existing?, requested: [QualityTier]? = nil) -> Copy? {
        guard isScoped(r) else { return nil }
        guard let existing else {
            return Copy(verb: "Requested", head: head(r, fromEpisode: false) ?? "", tail: "", later: false)
        }
        let (monitored, unmonitored) = (existing.monitored, existing.unmonitored)
        if monitored.isEmpty && unmonitored.isEmpty {
            return Copy(verb: "Monitors", head: head(r) ?? "", tail: " · \(later)", later: true)
        }
        let held = monitored + unmonitored
        let fresh = (requested ?? held).filter { !held.contains($0) }
        let many = unmonitored.count > 1
        let off = "\(names(unmonitored)) \(many ? "are" : "is") unmonitored — approving won't change \(many ? "them" : "it")"
        var extras: [String] = []
        if !monitored.isEmpty && !unmonitored.isEmpty { extras.append(off) }
        if !fresh.isEmpty { extras.append("new \(names(fresh)) version: \(later)") }
        let tail = extras.map { " · \($0)" }.joined()
        if monitored.isEmpty { return Copy(verb: "", head: off, tail: tail, later: !fresh.isEmpty) }
        return Copy(verb: "Adds", head: head(r, fromEpisode: false) ?? "",
                    tail: " to the existing \(names(monitored)) version\(tail)", later: !fresh.isEmpty)
    }

    /// The requested tiers that already have a version; nil until triage loads.
    public static func existing(_ r: MediaRequest, triage: RequestTriage?) -> Existing? {
        guard let triage else { return nil }
        var monitored: [QualityTier] = []
        var unmonitored: [QualityTier] = []
        for t in r.tiers {
            guard let v = triage.versions.first(where: { $0.tier == t && $0.existing == true }) else { continue }
            if v.monitored == false { unmonitored.append(t) } else { monitored.append(t) }
        }
        return Existing(monitored: monitored, unmonitored: unmonitored)
    }
}
