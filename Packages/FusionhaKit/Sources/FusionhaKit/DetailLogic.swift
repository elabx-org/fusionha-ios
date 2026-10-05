import Foundation

// Pure logic behind the item detail page, ported from the web's
// components/detail/{detail-scope,episode-status,edition-display,EditionCoverage}.ts
// so it can be unit tested without UI.

// MARK: - Labels

extension QualityTier {
    public static let ordered: [QualityTier] = [.hd, .uhd]
    /// `TIER_SHORT`: `HD` / `4K`.
    public var tierShort: String { self == .hd ? "HD" : "4K" }
}

public enum DetailText {
    /// `qualityLabel` (lib/quality-labels.ts).
    public static func quality(_ code: String?) -> String {
        guard let code, !code.isEmpty else { return "—" }
        return qualityLabels[code] ?? code
    }

    private static let qualityLabels: [String: String] = [
        "REMUX_2160P": "Bluray-2160p Remux", "BLURAY_2160P": "Bluray-2160p", "WEBDL_2160P": "WEBDL-2160p",
        "WEBRIP_2160P": "WEBRip-2160p", "HDTV_2160P": "HDTV-2160p", "REMUX_1080P": "Bluray-1080p Remux",
        "BLURAY_1080P": "Bluray-1080p", "WEBDL_1080P": "WEBDL-1080p", "WEBRIP_1080P": "WEBRip-1080p",
        "RAWHD": "Raw-HD", "HDTV_1080P": "HDTV-1080p", "BLURAY_720P": "Bluray-720p", "WEBDL_720P": "WEBDL-720p",
        "WEBRIP_720P": "WEBRip-720p", "HDTV_720P": "HDTV-720p", "BLURAY_576P": "Bluray-576p",
        "BLURAY_480P": "Bluray-480p", "DVD": "DVD", "DVDR": "DVD-R", "WEBDL_480P": "WEBDL-480p",
        "WEBRIP_480P": "WEBRip-480p", "SDTV": "SDTV", "BRDISK": "BR-DISK", "DVDSCR": "DVDSCR",
        "REGIONAL": "REGIONAL", "TELECINE": "TELECINE", "TELESYNC": "TELESYNC", "CAM": "CAM",
        "WORKPRINT": "WORKPRINT", "UNKNOWN": "Unknown",
    ]

    /// The resolution half of a quality code: `BLURAY_1080P` → `1080p`.
    public static func resolution(_ code: String?) -> String? {
        guard let code else { return nil }
        for r in ["2160P", "1080P", "720P", "576P", "480P"] where code.hasSuffix(r) {
            return r.lowercased()
        }
        return nil
    }

    /// `formatBytes` (detail-format.ts): base 1024, ≥100 rounded, else one decimal.
    public static func bytes(_ value: Double?) -> String {
        guard let size = value, size.isFinite, size > 0 else { return "0 B" }
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        let exp = min(Int(floor(log(size) / log(1024))), units.count - 1)
        let v = size / pow(1024, Double(exp))
        if v >= 100 || exp == 0 { return "\(Int(v.rounded())) \(units[exp])" }
        let r = (v * 10).rounded() / 10
        let text = r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
        return "\(text) \(units[exp])"
    }

    /// Quality order, worst to best (the arrs' ranking), for "cutoff met".
    public static let qualityRank: [String] = [
        "WORKPRINT", "CAM", "TELESYNC", "TELECINE", "REGIONAL", "DVDSCR", "SDTV", "WEBDL_480P", "WEBRIP_480P",
        "DVDR", "DVD", "BLURAY_480P", "BLURAY_576P", "HDTV_720P", "WEBDL_720P", "WEBRIP_720P", "BLURAY_720P",
        "HDTV_1080P", "WEBDL_1080P", "WEBRIP_1080P", "BLURAY_1080P", "REMUX_1080P", "HDTV_2160P", "WEBDL_2160P",
        "WEBRIP_2160P", "BLURAY_2160P", "REMUX_2160P",
    ]

    /// Whether a file's quality meets a profile cutoff.
    public static func meetsCutoff(_ quality: String?, cutoff: String?) -> Bool {
        guard let quality, let cutoff,
              let q = qualityRank.firstIndex(of: quality), let c = qualityRank.firstIndex(of: cutoff) else { return false }
        return q >= c
    }

    /// `PROVIDER_SHORT`.
    public static func provider(_ key: String?) -> String {
        switch key?.lowercased() {
        case "tvdb": return "TVDB"
        case "tvmaze": return "TVmaze"
        case "anilist": return "AniList"
        case "anidb": return "AniDB"
        case "mal": return "MAL"
        default: return "TMDB"
        }
    }

    /// Parses the server's timestamps, which are usually NAIVE UTC
    /// (`2026-10-02T02:52:39.007478`), sometimes with `Z` or an offset.
    public static func instant(_ iso: String?) -> Date? {
        guard var text = iso, !text.isEmpty else { return nil }
        if text.count == 10 { return dayFormatter.date(from: text) }
        if text.range(of: #"([zZ]|[+-]\d\d:?\d\d)$"#, options: .regularExpression) == nil { text += "Z" }
        if let d = isoFractional.date(from: text) { return d }
        if let d = isoPlain.date(from: text) { return d }
        // Microsecond fractions (6 digits) trip ISO8601DateFormatter: trim to 3.
        if let dot = text.firstIndex(of: "."), let end = text[dot...].firstIndex(where: { !$0.isNumber && $0 != "." }) {
            let frac = text[text.index(after: dot)..<end]
            let trimmed = String(text[..<dot]) + "." + String(frac.prefix(3)) + String(text[end...])
            return isoFractional.date(from: String(trimmed))
        }
        return nil
    }

    // Parsing only (never mutated after creation), so one shared instance each
    // instead of a formatter per call: coverage parses every episode's air date.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// `formatReleaseDate` (release-dates.ts): `2026-09-29` → `29 Sep 2026`.
    public static func releaseDate(_ iso: String) -> String {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m) else { return iso }
        return "\(d) \(months[m - 1]) \(y)"
    }

    /// `hasPassed` (release-dates.ts): the ISO day is today or earlier, in local time.
    public static func dayHasPassed(_ iso: String, now: Date = Date()) -> Bool {
        let parts = iso.prefix(10).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return false }
        let cal = Calendar.current
        guard let day = cal.date(from: DateComponents(year: y, month: m, day: d)) else { return false }
        return day <= cal.startOfDay(for: now)
    }

    /// `relativeTime` (detail-format.ts): "just now" / "N minutes ago" / …
    public static func relative(_ iso: String?, now: Date = Date()) -> String {
        guard let then = instant(iso) else { return "" }
        let secs = max(0, (now.timeIntervalSince(then)).rounded())
        func ago(_ count: Double, _ word: String) -> String {
            let n = Int(count.rounded())
            return "\(n) \(word)\(n == 1 ? "" : "s") ago"
        }
        if secs < 45 { return "just now" }
        if secs < 3600 { return ago(secs / 60, "minute") }
        if secs < 86_400 { return ago(secs / 3600, "hour") }
        if secs < 604_800 { return ago(secs / 86_400, "day") }
        if secs < 2_592_000 { return ago(secs / 604_800, "week") }
        if secs < 31_536_000 { return ago(secs / 2_592_000, "month") }
        return ago(secs / 31_536_000, "year")
    }
}

// MARK: - Versions

extension DetailEdition {
    /// `versionKey`: the trimmed edition/version name, `""` for Standard.
    public var versionKey: String { (movieEdition ?? "").trimmingCharacters(in: .whitespaces) }
    /// `editionLabel`: "Black & White · HD·1080p", or just the tier label.
    public var label: String {
        versionKey.isEmpty ? tier.chipLabel : "\(versionKey) · \(tier.chipLabel)"
    }
}

public func versionLabel(_ key: String) -> String { key.isEmpty ? "Standard" : key }

// MARK: - Scope (detail-scope.ts)

/// The page's "Act on" scope: a tier axis and a version axis, each `all` or a value.
/// Persisted (shared across items) under `fusionha:detail-scope` like the web.
public struct DetailScope: Codable, Hashable, Sendable {
    /// `"all"` or a tier raw value (`HD-1080p` / `UHD-2160p`).
    public var tier: String
    /// `"all"` or a version key (`""` = Standard).
    public var version: String

    public init(tier: String = "all", version: String = "all") {
        self.tier = tier
        self.version = version
    }

    public static let all = DetailScope()
    public static let storageKey = "fusionha:detail-scope"

    public var tierValue: QualityTier? { QualityTier(rawValue: tier) }
    public var isAll: Bool { tier == "all" && version == "all" }

    public static func parse(_ raw: String?) -> DetailScope {
        guard let raw else { return .all }
        if raw == "all" { return .all }
        if QualityTier(rawValue: raw) != nil { return DetailScope(tier: raw, version: "all") }
        if let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(DetailScope.self, from: data),
           decoded.tier == "all" || QualityTier(rawValue: decoded.tier) != nil {
            return decoded
        }
        return .all
    }

    public var serialized: String {
        let tierJSON = tier.replacingOccurrences(of: "\"", with: "\\\"")
        let versionJSON = version.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"tier\":\"\(tierJSON)\",\"version\":\"\(versionJSON)\"}"
    }
}

extension ItemDetail {
    public var isSeries: Bool { kind == .series }

    /// Tiers present, HD first.
    public var distinctTiers: [QualityTier] {
        QualityTier.ordered.filter { t in editions.contains { $0.tier == t } }
    }

    /// Distinct version keys in edition order (Standard first when present).
    public var versionKeys: [String] {
        var seen: [String] = []
        for e in editions.sorted(by: { ($0.tier == .hd ? 0 : 1, $0.id) < ($1.tier == .hd ? 0 : 1, $1.id) })
        where !seen.contains(e.versionKey) {
            seen.append(e.versionKey)
        }
        if let i = seen.firstIndex(of: ""), i != 0 { seen.remove(at: i); seen.insert("", at: 0) }
        return seen
    }

    public var hasVersions: Bool { editions.contains { !$0.versionKey.isEmpty } }

    public var soleTier: QualityTier? {
        let tiers = Set(editions.map(\.tier))
        return tiers.count == 1 ? tiers.first : nil
    }

    public func effectiveScope(_ scope: DetailScope) -> DetailScope {
        var tier = scope.tier == "all" || editions.contains { $0.tier.rawValue == scope.tier } ? scope.tier : "all"
        if tier == "all", let sole = soleTier { tier = sole.rawValue }
        let within = tier == "all" ? editions : editions.filter { $0.tier.rawValue == tier }
        let version = scope.version == "all" || within.contains { $0.versionKey == scope.version } ? scope.version : "all"
        return DetailScope(tier: tier, version: version)
    }

    static func canonical(_ pool: [DetailEdition]) -> DetailEdition? {
        pool.first { $0.versionKey.isEmpty } ?? pool.min { $0.id < $1.id }
    }

    private func pool(for eff: DetailScope) -> [DetailEdition] {
        var pool = editions
        if eff.tier != "all" { pool = pool.filter { $0.tier.rawValue == eff.tier } }
        if eff.version != "all" { pool = pool.filter { $0.versionKey == eff.version } }
        return pool
    }

    /// `scopeEditionId`: nil when both axes are open.
    public func scopeEditionId(_ scope: DetailScope) -> Int? {
        let eff = effectiveScope(scope)
        if eff.isAll { return nil }
        return Self.canonical(pool(for: eff))?.id
    }

    /// `scopeEditionIds`: nil when both axes are open.
    public func scopeEditionIds(_ scope: DetailScope) -> Set<Int>? {
        let eff = effectiveScope(scope)
        if eff.isAll { return nil }
        return Set(pool(for: eff).map(\.id))
    }

    /// `scopedEditions`: the editions in scope (all of them when open), HD first.
    public func scopedEditions(_ scope: DetailScope) -> [DetailEdition] {
        let ids = scopeEditionIds(scope)
        return orderedEditions.filter { ids?.contains($0.id) ?? true }
    }

    /// HD before UHD, then by id.
    public var orderedEditions: [DetailEdition] {
        editions.sorted { ($0.tier == .hd ? 0 : 1, $0.id) < ($1.tier == .hd ? 0 : 1, $1.id) }
    }

    /// `editionFor(tier, version)`: the canonical edition of a tier within a version.
    public func edition(tier: QualityTier, version: String) -> DetailEdition? {
        let inTier = editions.filter { $0.tier == tier }
        let scoped = version == "all" ? inTier : inTier.filter { $0.versionKey == version }
        return Self.canonical(scoped)
    }

    /// The "acts on" / "showing" label for a scope.
    public func scopeLabel(_ scope: DetailScope, allText: String) -> String {
        let eff = effectiveScope(scope)
        if eff.isAll { return allText }
        if let tier = eff.tierValue {
            return eff.version == "all" || eff.version.isEmpty ? tier.chipLabel : "\(eff.version) · \(tier.chipLabel)"
        }
        return versionLabel(eff.version)
    }

    public var allEpisodes: [Episode] { (seasons ?? []).flatMap(\.episodes) }

    /// Episodes with a file for an edition (`editionFileCount`), or 1/0 for a movie.
    public func fileCount(_ edition: DetailEdition) -> Int {
        guard isSeries else { return edition.movieFile == nil ? 0 : 1 }
        return allEpisodes.filter { ep in (ep.files ?? []).contains { $0.editionId == edition.id } }.count
    }

    /// `editionCoverage`: `owned/total` episodes, or `owned/1` for a movie.
    public func coverageText(_ edition: DetailEdition) -> String {
        "\(fileCount(edition))/\(isSeries ? allEpisodes.count : 1)"
    }

    /// Bytes an edition owns on disk (each physical file once).
    public func editionBytes(_ edition: DetailEdition) -> Double {
        if !isSeries { return edition.movieFile?.size ?? 0 }
        var sizes: [Int: Double] = [:]
        for ep in allEpisodes {
            if let f = ep.file(for: edition.id) { sizes[f.id] = f.size ?? 0 }
        }
        return sizes.values.reduce(0, +)
    }
}

// MARK: - Episode status (episode-status.ts)

public enum EpisodeStatusKind: String, Sendable {
    case owned, attention, upgrading, downloading, stuck, missing, soon

    /// The tick tooltip text (`STATUS_TEXT`).
    public var statusText: String {
        switch self {
        case .owned: return "Downloaded"
        case .attention: return "Unresolved · not found on last scan"
        case .upgrading: return "Upgrading · fetching a better copy"
        case .downloading: return "Downloading"
        case .stuck: return "Stuck"
        case .missing: return "Missing"
        case .soon: return "Not yet aired"
        }
    }

    /// `tickKind`: an attention or upgrading file is still owned coverage; a
    /// not-yet-aired episode is `soon`, never a gap.
    public var tick: TickKind {
        switch self {
        case .owned, .attention, .upgrading: return .owned
        case .downloading, .stuck: return .grab
        case .soon: return .soon
        case .missing: return .want
        }
    }
}

/// How one episode tick paints. `untracked` is set by the caller from
/// monitoring (unmonitored and fileless): neutral, never a gap.
public enum TickKind: Sendable { case owned, grab, want, soon, untracked }

extension Episode {
    public func file(for editionId: Int) -> MovieFile? {
        files?.first { $0.editionId == editionId }?.file
    }

    public func download(for editionId: Int) -> EpisodeDownload? {
        downloadStates?.first { $0.editionId == editionId }
    }

    public var airInstant: Date? { DetailText.instant(airDatetime ?? airDate) }

    public func hasAired(now: Date = Date()) -> Bool {
        guard let d = airInstant else { return false }
        return d <= now
    }

    public func status(editionId: Int, now: Date = Date()) -> EpisodeStatusKind {
        let file = file(for: editionId)
        let state = download(for: editionId)?.state
        let live = ["downloading", "stuck", "upgrading"].contains(state ?? "") ? state : nil
        if let file {
            if file.unresolved == true { return .attention }
            if live == "upgrading" || live == "downloading" { return .upgrading }
            return .owned
        }
        if live == "stuck" { return .stuck }
        if live == "downloading" { return .downloading }
        return hasAired(now: now) ? .missing : .soon
    }
}

// MARK: - Coverage (version-coverage.ts)

/// One version's coverage over a set of episodes. `total` counts MONITORED
/// episodes; `wanted` is monitored, fileless and aired; `unaired` is monitored,
/// fileless and still to air (never missing); `kept` holds files on unmonitored
/// episodes; `untracked` is unmonitored and absent.
public struct Cover: Sendable, Hashable {
    public var total = 0, owned = 0, grabbing = 0, wanted = 0, unaired = 0, kept = 0, untracked = 0
    public init() {}

    public static func + (a: Cover, b: Cover) -> Cover {
        var c = Cover()
        c.total = a.total + b.total; c.owned = a.owned + b.owned; c.grabbing = a.grabbing + b.grabbing
        c.wanted = a.wanted + b.wanted; c.unaired = a.unaired + b.unaired
        c.kept = a.kept + b.kept; c.untracked = a.untracked + b.untracked
        return c
    }

    /// `coverState`: full ✓ / partial ◐ / empty ○.
    public enum State: Sendable { case done, part, empty }
    public var state: State {
        if total > 0 && owned >= total { return .done }
        if owned > 0 || grabbing > 0 { return .part }
        return .empty
    }
}

extension Season {
    /// `seasonCover`: an unmonitored season is not coverage (its files are kept).
    public func cover(editionId: Int, now: Date = Date()) -> Cover {
        var c = Cover()
        if monitored == false {
            for ep in episodes where ep.file(for: editionId) != nil { c.kept += 1 }
            c.untracked = episodes.count - c.kept
            return c
        }
        for ep in episodes {
            let kind = ep.status(editionId: editionId, now: now)
            if ep.monitored == false {
                if ep.file(for: editionId) != nil { c.kept += 1 } else { c.untracked += 1 }
                continue
            }
            c.total += 1
            switch kind.tick {
            case .owned: c.owned += 1
            case .grab: c.grabbing += 1
            case .soon: c.unaired += 1
            case .want, .untracked: break
            }
        }
        c.wanted = c.total - c.owned - c.grabbing - c.unaired
        return c
    }

    /// `seasonOff`: nothing in the season is tracked (unmonitored outright, or
    /// every episode unmonitored). A season with no episodes keeps the ordinary look.
    public func isOff(_ c: Cover) -> Bool {
        monitored == false || (c.total == 0 && c.kept + c.untracked > 0)
    }

    /// `seasonCompletion` for the Seasons tab: an episode counts as done only
    /// with a file for every scoped edition; monitored episodes only.
    public func completion(editionIds: [Int]) -> (done: Int, total: Int, downloading: Int, attention: Int) {
        var done = 0, total = 0, downloading = 0, attention = 0
        for ep in episodes where ep.monitored != false {
            total += 1
            let files = editionIds.compactMap { ep.file(for: $0) }
            if !editionIds.isEmpty && files.count == editionIds.count {
                done += 1
                if files.contains(where: { $0.unresolved == true || $0.analysis == "failed" }) { attention += 1 }
            } else if editionIds.contains(where: { ep.download(for: $0)?.state == "downloading" }) {
                downloading += 1
            }
        }
        return (done, total, downloading, attention)
    }

    public func bytes(editionIds: [Int]) -> Double {
        var sizes: [Int: Double] = [:]
        for ep in episodes {
            for id in editionIds { if let f = ep.file(for: id) { sizes[f.id] = f.size ?? 0 } }
        }
        return sizes.values.reduce(0, +)
    }

    public var title: String { seasonNumber == 0 ? "Specials" : "Season \(seasonNumber)" }
}

extension ItemDetail {
    public func cover(edition: DetailEdition, now: Date = Date()) -> Cover {
        (seasons ?? []).reduce(Cover()) { $0 + $1.cover(editionId: edition.id, now: now) }
    }

    /// Seasons newest first, Specials last.
    public var seasonsNewestFirst: [Season] {
        (seasons ?? []).sorted { a, b in
            if a.seasonNumber == 0 { return false }
            if b.seasonNumber == 0 { return true }
            return a.seasonNumber > b.seasonNumber
        }
    }

    /// Seasons in number order (Specials first), as the Versions panel lays them out.
    public var seasonsAscending: [Season] {
        (seasons ?? []).sorted { $0.seasonNumber < $1.seasonNumber }
    }

    /// `versionState`: done when the movie file exists / every monitored episode has a file.
    public func isComplete(_ edition: DetailEdition) -> Bool {
        if !isSeries { return edition.movieFile != nil }
        let monitored = allEpisodes.filter { $0.monitored != false }
        return !monitored.isEmpty && monitored.allSatisfy { $0.file(for: edition.id) != nil }
    }
}

/// The dot status of an edition (`versionStatusFor`).
public enum EditionDot: Sendable { case upgrade, grab, done, miss }

extension ItemDetail {
    public func dot(for edition: DetailEdition, activeQueueEditionIds: Set<Int>) -> EditionDot {
        if edition.downloadState == "upgrading" { return .upgrade }
        if activeQueueEditionIds.contains(edition.id) { return isComplete(edition) ? .upgrade : .grab }
        return isComplete(edition) ? .done : .miss
    }
}
