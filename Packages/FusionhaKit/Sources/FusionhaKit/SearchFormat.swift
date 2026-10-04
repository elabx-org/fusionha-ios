import Foundation

// Pure helpers behind the Interactive (Manual) Search sheet, ported from the
// web's components/detail/search-format.ts and lib/api/runs.ts
// (`indexerRetryHint`) so they can be unit tested without UI.

public enum ReleaseSearch {
    /// A sortable results column (`SortKey`), in the web's `COLUMNS` order.
    public enum SortKey: String, CaseIterable, Sendable {
        case release, quality, size, age, indexer, seed, score

        public var label: String {
            switch self {
            case .release: return "Release"
            case .quality: return "Quality"
            case .size: return "Size"
            case .age: return "Age"
            case .indexer: return "Indexer"
            case .seed: return "Seed"
            case .score: return "Score"
            }
        }

        /// The direction a fresh pick sorts (`initialDir`).
        public var initialAscending: Bool {
            switch self {
            case .release, .quality, .age, .indexer: return true
            case .size, .seed, .score: return false
            }
        }

        /// Seed only means something for torrents (`torrentOnly`).
        public var torrentOnly: Bool { self == .seed }
    }

    /// `formatScore`: always signed, unicode minus (`+485`, `−40`, `+0`).
    public static func score(_ value: Int) -> String {
        value < 0 ? "\u{2212}\(abs(value))" : "+\(value)"
    }

    /// `formatAge`: `3d`, `5h`, `2mo`, `1y`; sub-minute `now`; nothing → `—`.
    public static func age(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "—" }
        if seconds < 60 { return "now" }
        for (size, suffix) in ageUnits where seconds >= size {
            return "\(Int(seconds / size))\(suffix)"
        }
        return "now"
    }

    private static let ageUnits: [(Double, String)] = [
        (31_536_000, "y"), (2_592_000, "mo"), (604_800, "w"), (86_400, "d"), (3_600, "h"), (60, "m"),
    ]

    /// `resolutionOf`: the `_2160P`-style token lower-cased, else `SD`.
    public static func resolution(_ quality: String?) -> String {
        let seg = (quality ?? "").split(separator: "_").first { s in
            s.count > 1 && s.last.map { $0 == "P" || $0 == "p" } == true && s.dropLast().allSatisfy(\.isNumber)
        }
        return seg.map { $0.lowercased() } ?? "SD"
    }

    /// `indexerName`: the indexer's name, else `#id`.
    public static func indexer(_ release: ReleasePreview) -> String {
        release.indexerName ?? "#\(release.indexerId ?? 0)"
    }

    /// `protocolLabel`.
    public static func protocolLabel(_ raw: String) -> String {
        raw.uppercased() == "TORRENT" ? "Torrent" : "Usenet"
    }

    public static func isTorrent(_ release: ReleasePreview) -> Bool { release.protocolName.uppercased() == "TORRENT" }
    public static func isUsenet(_ release: ReleasePreview) -> Bool { release.protocolName.uppercased() == "USENET" }

    /// `compareReleases`: ascending order by one key (negative = `a` first).
    public static func compare(_ a: ReleasePreview, _ b: ReleasePreview, _ key: SortKey) -> Double {
        func text(_ x: String, _ y: String) -> Double {
            switch x.localizedCompare(y) {
            case .orderedAscending: return -1
            case .orderedDescending: return 1
            case .orderedSame: return 0
            }
        }
        switch key {
        case .release: return text(a.title, b.title)
        case .quality: return text(DetailText.quality(a.quality), DetailText.quality(b.quality))
        case .size: return (a.size ?? -1) - (b.size ?? -1)
        case .age:
            let x = a.ageSeconds ?? .infinity, y = b.ageSeconds ?? .infinity
            return x == y ? 0 : (x < y ? -1 : 1)
        case .indexer: return text(indexer(a), indexer(b))
        case .seed: return Double((a.seeders ?? -1) - (b.seeders ?? -1))
        case .score:
            let byScore = (a.cfScore ?? 0) - (b.cfScore ?? 0)
            return byScore != 0 ? Double(byScore) : (a.size ?? -1) - (b.size ?? -1)
        }
    }

    /// `sortReleases`: a stable sort by one key and direction.
    public static func sorted(_ rows: [ReleasePreview], by key: SortKey, ascending: Bool) -> [ReleasePreview] {
        let sign: Double = ascending ? 1 : -1
        return rows.enumerated().sorted { l, r in
            let c = sign * compare(l.element, r.element, key)
            return c != 0 ? c < 0 : l.offset < r.offset
        }.map(\.element)
    }

    /// `QualityChip` tone when the chip has no tier: `uhd`, `hd` or muted (nil).
    public static func tone(_ quality: String?) -> QualityTier? {
        guard let quality else { return nil }
        if uhdQualities.contains(quality) { return .uhd }
        if hdQualities.contains(quality) { return .hd }
        return nil
    }

    private static let uhdQualities: Set<String> = ["REMUX_2160P", "BLURAY_2160P", "WEBDL_2160P", "WEBRIP_2160P", "HDTV_2160P"]
    private static let hdQualities: Set<String> = ["REMUX_1080P", "BLURAY_1080P", "WEBDL_1080P", "WEBRIP_1080P", "HDTV_1080P", "RAWHD"]

    /// `tierForQuality`: ≥2160 → UHD, any other known resolution → HD, else nil.
    public static func tier(_ quality: String?) -> QualityTier? {
        let res = resolution(quality)
        guard res != "SD", let n = Int(res.dropLast()) else { return nil }
        return n >= 2160 ? .uhd : .hd
    }

    /// One release's grab-time edition target (`AutoTargetInfo`).
    public struct AutoTarget: Equatable, Sendable {
        public let tier: QualityTier
        /// The sibling edition the grab is filed under; nil when none exists (blocked).
        public let targetLabel: String?
    }

    /// `autoTargetFor`: nil when the release's tier is unknown or matches the active tab.
    public static func autoTarget(_ quality: String?, activeTier: QualityTier?,
                                  editions: [(id: Int, label: String, tier: QualityTier)]) -> AutoTarget? {
        guard let tier = tier(quality), let activeTier, tier != activeTier else { return nil }
        return AutoTarget(tier: tier, targetLabel: editions.first { $0.tier == tier }?.label)
    }

    /// `scopeStatusLines`: the notable auto-search silencers, ready to render.
    public static func scopeStatusLines(_ status: ReleaseScopeStatus, clock: (String) -> String) -> [String] {
        var lines: [String] = []
        if status.backoffActive == true {
            let n = status.backoffConsecutiveEmpty ?? 0
            let resume = status.backoffNextEligibleAt.map { " · resumes \(clock($0))" } ?? ""
            lines.append("Auto-search paused — \(n) consecutive empty \(n == 1 ? "search" : "searches")\(resume)"
                + " · a manual search runs now and ignores the backoff")
        }
        if status.failedGrabCooldownActive == true {
            let n = status.failedDownloadCount ?? 0
            let resume = status.failedGrabCooldownUntil.map { " · resumes \(clock($0))" } ?? ""
            lines.append("Cooling down after \(n) failed \(n == 1 ? "download" : "downloads")\(resume)"
                + " · a manual search runs now and ignores the cooldown")
        }
        return lines
    }

    /// `scopeStatusLastRunSummary`.
    public static func lastRunSummary(_ status: ReleaseScopeStatus) -> String? {
        guard status.lastRunAt != nil else { return nil }
        return "Last auto-search: \(status.lastRunReleases ?? 0) seen, \(status.lastRunGrabbed ?? 0) grabbed, "
            + "\(status.lastRunRejected ?? 0) rejected"
    }

    /// `indexerRetryHint`: `retry in 12m` / `retry in 2h` / `retrying`.
    public static func retryHint(_ disabledTill: Date?, now: Date = Date()) -> String {
        guard let disabledTill else { return "retrying" }
        let mins = Int((disabledTill.timeIntervalSince(now) / 60).rounded())
        if mins <= 0 { return "retrying" }
        if mins < 60 { return "retry in \(mins)m" }
        return "retry in \(Int((Double(mins) / 60).rounded()))h"
    }
}
