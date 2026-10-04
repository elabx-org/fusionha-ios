import Foundation

// The Versions panel's pure logic, ported from the web's
// components/detail/{version-coverage,version-display,release-dates}.ts and
// versions/VersionsPanel.tsx so it can be unit tested without UI.
//
// Vocabulary (fusionha 0.4.122+): a *tier* is HD·1080p / UHD·4K, an *edition*
// is the cut (Standard, the default, usually hidden), and a *version* is one
// tier + edition.

/// Standard (`""`) first, then alphabetical: the Versions-panel ordering rule.
public func editionKeyPrecedes(_ a: String, _ b: String) -> Bool {
    if a == b { return false }
    if a.isEmpty { return true }
    if b.isEmpty { return false }
    return a.localizedCompare(b) == .orderedAscending
}

/// One (tier, edition) combination the title does not track.
public struct MissingVersion: Hashable, Sendable, Identifiable {
    public let tier: QualityTier
    /// `""` for Standard, else the edition name.
    public let edition: String
    public var id: String { "\(tier.rawValue)~\(edition)" }
    public init(tier: QualityTier, edition: String) {
        self.tier = tier
        self.edition = edition
    }
}

/// A version's one status: the canonical key (its colour) and its word.
public struct VersionStatusDisplay: Hashable, Sendable {
    public let key: EditionStatus
    public let word: String
    /// The series count beside the word ("Missing 3"), if any.
    public let count: Int?

    public var text: String { count.map { "\(word) \($0)" } ?? word }
}

/// `seriesVersionStatus`: complete, downloading N, missing N (aired only),
/// unaired N, or (nothing tracked) unmonitored / unaired.
public func seriesVersionStatus(_ c: Cover) -> VersionStatusDisplay {
    if c.total == 0 {
        return c.kept + c.untracked > 0
            ? VersionStatusDisplay(key: .unmonitored, word: EditionStatus.unmonitored.label, count: nil)
            : VersionStatusDisplay(key: .unaired, word: EditionStatus.unaired.label, count: nil)
    }
    if c.owned >= c.total { return VersionStatusDisplay(key: .downloaded, word: EditionStatus.downloaded.label, count: nil) }
    if c.grabbing > 0 { return VersionStatusDisplay(key: .downloading, word: EditionStatus.downloading.label, count: c.grabbing) }
    if c.wanted > 0 { return VersionStatusDisplay(key: .missing, word: EditionStatus.missing.label, count: c.wanted) }
    return VersionStatusDisplay(key: .unaired, word: EditionStatus.unaired.label, count: c.unaired)
}

/// The status a movie version paints.
public enum MovieVersionStatus: Sendable, Hashable {
    case done, grab, upgrading, wanted, soon

    /// `movieStatusDisplay`: released-but-missing keeps the word "Wanted".
    public var display: VersionStatusDisplay {
        switch self {
        case .done: return VersionStatusDisplay(key: .downloaded, word: EditionStatus.downloaded.label, count: nil)
        case .upgrading: return VersionStatusDisplay(key: .upgrading, word: EditionStatus.upgrading.label, count: nil)
        case .grab: return VersionStatusDisplay(key: .downloading, word: EditionStatus.downloading.label, count: nil)
        case .soon: return VersionStatusDisplay(key: .upcoming, word: EditionStatus.upcoming.label, count: nil)
        case .wanted: return VersionStatusDisplay(key: .missing, word: "Wanted", count: nil)
        }
    }
}

/// `movieAvailability`: whether a movie is out yet, and the gating date.
public struct MovieAvailability: Hashable, Sendable {
    public enum Stage: Sendable { case released, upcoming, unknown }
    public let state: Stage
    public let iso: String?
    public let date: String?
    public let label: String?
}

/// The one availability line a fileless movie version shows.
public struct MovieAvailabilityNote: Hashable, Sendable {
    public enum Kind: Sendable { case released, upcoming, none }
    public let kind: Kind
    public let text: String
}

/// Backend `available_stage` → the window label an Upcoming version names.
public let releaseStageDisplay: [String: String] = [
    "theatrical": "Cinema", "digital": "Digital", "physical": "Physical",
]

extension DetailEdition {
    /// `versionUnresolved`: files not resolved on the last scan (absent ∪ dangling).
    public var unresolvedCount: Int {
        unresolvedFileCount ?? ((missingFileCount ?? 0) + (hasUnresolvedLinks == true ? 1 : 0))
    }
}

extension ItemDetail {
    /// HD before 4K, then Standard first, then editions alphabetically.
    public var versionsSorted: [DetailEdition] {
        editions.sorted { a, b in
            if a.tier != b.tier { return a.tier == .hd }
            if a.versionKey != b.versionKey { return editionKeyPrecedes(a.versionKey, b.versionKey) }
            return a.id < b.id
        }
    }

    /// Distinct edition keys, Standard first then alphabetical.
    public var editionKeysSorted: [String] {
        Array(Set(editions.map(\.versionKey))).sorted(by: editionKeyPrecedes)
    }

    /// `needsEditionTag`: show the edition tag (Standard included) only when a
    /// sibling version carries a real edition.
    public var needsEditionTag: Bool { hasVersions }

    /// `missingVersions`: every tier × every tracked edition the title lacks,
    /// HD first, Standard first.
    public var missingVersions: [MissingVersion] {
        let keys = editionKeysSorted
        let have = Set(editions.map { "\($0.tier.rawValue)~\($0.versionKey)" })
        var out: [MissingVersion] = []
        for tier in QualityTier.ordered {
            for key in keys where !have.contains("\(tier.rawValue)~\(key)") {
                out.append(MissingVersion(tier: tier, edition: key))
            }
        }
        return out
    }

    /// The version a RAW page scope points at (nil = all versions). A tier-only
    /// scope opens that tier's canonical version (Standard, else lowest id).
    public func focusedVersion(_ scope: DetailScope) -> DetailEdition? {
        guard scope.tier != "all" else { return nil }
        let inTier = editions.filter { $0.tier.rawValue == scope.tier }
        if scope.version != "all" { return inTier.first { $0.versionKey == scope.version } }
        return Self.canonical(inTier)
    }

    /// The panel's name for a version: `HD·1080p`, or `HD·1080p · Black & White`
    /// when the edition tag shows.
    public func versionName(_ edition: DetailEdition) -> String {
        needsEditionTag ? "\(edition.tier.chipLabel) · \(versionLabel(edition.versionKey))" : edition.tier.chipLabel
    }

    /// The tabs' read-only `showing …` echo: edition (Standard only when a
    /// sibling is non-Standard), then tier; "All versions" when both are open.
    public func showingLabel(_ scope: DetailScope) -> String {
        let eff = effectiveScope(scope)
        var parts: [String] = []
        if eff.version != "all" && (!eff.version.isEmpty || needsEditionTag) { parts.append(versionLabel(eff.version)) }
        if let tier = eff.tierValue { parts.append(tier.chipLabel) }
        return parts.isEmpty ? "All versions" : parts.joined(separator: " · ")
    }

    /// The rail's `applies to …` hint: the effective tier, or all versions.
    public func appliesToLabel(_ scope: DetailScope) -> String {
        effectiveScope(scope).tierValue?.chipLabel ?? "all versions"
    }

    /// `untrackedNote`: "+N unmonitored", or "+N specials unmonitored" when every
    /// unmonitored episode sits in Season 0.
    public func untrackedNote(_ cover: Cover) -> String? {
        let n = cover.kept + cover.untracked
        guard n > 0 else { return nil }
        let specials = (seasons ?? []).allSatisfy { s in
            s.seasonNumber == 0 || (s.monitored != false && s.episodes.allSatisfy { $0.monitored != false })
        }
        return "+\(n) \(specials ? "specials unmonitored" : "unmonitored")"
    }

    /// Seasons any of these versions tracks (in number order).
    public func trackedSeasons(editionIds: [Int], now: Date = Date()) -> [Season] {
        seasonsAscending.filter { s in editionIds.contains { !s.isOff(s.cover(editionId: $0, now: now)) } }
    }

    /// The season an opened row (or Compare seasons) starts on: the first
    /// tracked season with an aired gap, else the latest tracked, else the last.
    public func defaultSeason(editionIds: [Int], now: Date = Date()) -> Int? {
        let tracked = trackedSeasons(editionIds: editionIds, now: now)
        let gap = tracked.first { s in editionIds.contains { s.cover(editionId: $0, now: now).wanted > 0 } }
        return (gap ?? tracked.last ?? seasonsAscending.last)?.seasonNumber
    }

    /// `versionGrabbed`: the latest GRABBED / IMPORTED event for a version.
    public func versionGrabbed(_ editionId: Int, now: Date = Date()) -> (label: String, value: String) {
        let events = (history ?? []).filter {
            $0.editionId == editionId && ($0.eventType == "GRABBED" || $0.eventType == "IMPORTED")
        }
        guard let latest = events.max(by: { $0.createdAt < $1.createdAt }) else { return ("Grabbed", "—") }
        return (latest.eventType == "IMPORTED" ? "Imported" : "Grabbed", DetailText.relative(latest.createdAt, now: now))
    }

    /// `movieAvailability` (release-dates.ts). The display path passes
    /// `treatAnnouncedAsReleased: false` so an announced, unreleased movie reads Upcoming.
    public func movieAvailability(minimum: String?, now: Date = Date(),
                                  treatAnnouncedAsReleased: Bool = true) -> MovieAvailability {
        let minAvail = (minimum?.isEmpty == false ? minimum : nil) ?? "released"
        if minAvail == "announced" && treatAnnouncedAsReleased {
            return MovieAvailability(state: .released, iso: nil, date: nil, label: nil)
        }
        var iso: String?
        var label: String?
        if minAvail == "inCinemas" {
            if let c = inCinemas, !c.isEmpty { iso = c; label = "Cinema" } else { iso = releaseDate; label = "Release" }
        } else {
            var home: [(String, String)] = []
            if let d = digitalRelease, !d.isEmpty { home.append((d, "Digital")) }
            if let p = physicalRelease, !p.isEmpty { home.append((p, "Physical")) }
            if let first = home.sorted(by: { $0.0 < $1.0 }).first { iso = first.0; label = first.1 } else { iso = releaseDate; label = "Release" }
        }
        guard let iso, !iso.isEmpty else { return MovieAvailability(state: .unknown, iso: nil, date: nil, label: nil) }
        return MovieAvailability(state: DetailText.dayHasPassed(iso, now: now) ? .released : .upcoming,
                                 iso: iso, date: DetailText.releaseDate(iso), label: label)
    }

    /// `movieVersionStatus`: the queue-aware dot, split on the backend's
    /// `grabbable` verdict for a fileless version.
    public func movieVersionStatus(_ edition: DetailEdition, base: EditionDot, now: Date = Date()) -> MovieVersionStatus {
        switch base {
        case .done: return .done
        case .upgrade: return .upgrading
        case .grab: return .grab
        case .miss: break
        }
        if edition.grabbable == true { return .wanted }
        if edition.grabbable == false { return .soon }
        let avail = movieAvailability(minimum: edition.minimumAvailability, now: now, treatAnnouncedAsReleased: false)
        return avail.state == .upcoming ? .soon : .wanted
    }

    /// `movieAvailabilityNote`: "Released …" / "Digital …", "Upcoming — …", or
    /// "No HD·1080p file yet".
    public func movieAvailabilityNote(_ edition: DetailEdition, status: MovieVersionStatus,
                                      now: Date = Date()) -> MovieAvailabilityNote {
        let avail = movieAvailability(minimum: edition.minimumAvailability, now: now, treatAnnouncedAsReleased: false)
        if status == .wanted, let date = avail.date {
            return MovieAvailabilityNote(kind: .released,
                                         text: avail.state == .released ? "Released \(date)" : "\(avail.label ?? "Release") \(date)")
        }
        if status == .soon {
            let upFrom = edition.availableFrom.flatMap { $0.isEmpty ? nil : $0 }
            let iso = upFrom ?? (avail.state == .upcoming ? avail.iso : nil)
            let label = upFrom != nil ? (releaseStageDisplay[edition.availableStage ?? ""] ?? "Release") : (avail.label ?? "Release")
            if let iso { return MovieAvailabilityNote(kind: .upcoming, text: "Upcoming — \(label) \(DetailText.releaseDate(iso))") }
        }
        return MovieAvailabilityNote(kind: .none, text: "No \(edition.tier.chipLabel) file yet")
    }
}

extension Season {
    /// How one episode tick paints for a version: an unmonitored (season or
    /// episode), fileless episode is `untracked`, never a gap.
    public func tick(_ episode: Episode, editionId: Int, now: Date = Date()) -> TickKind {
        let base = episode.status(editionId: editionId, now: now).tick
        let off = monitored == false || episode.monitored == false
        return off && (base == .want || base == .soon) ? .untracked : base
    }
}

extension Cover {
    /// The chip state of a season: still-to-air outstanding is `soon`, never a gap.
    public var chipState: ChipState {
        if state != .done && wanted == 0 && grabbing == 0 && unaired > 0 { return .soon }
        switch state {
        case .done: return .done
        case .part: return .part
        case .empty: return .empty
        }
    }

    public enum ChipState: Sendable { case done, part, empty, soon }
}
