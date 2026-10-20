import Foundation

// Pure logic behind the item detail page's episode ticks and version coverage,
// ported from the web's components/detail/{episode-status,version-coverage}.ts.

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
