import Foundation
import FusionhaKit

/// One version's lane on a season card or page: its badge state and the
/// one-ink rail's numbers, from v1's season coverage (`Season.cover`).
struct V2SeasonLane: Identifiable {
    let edition: DetailEdition
    let cover: Cover
    let state: EditionBadgeState
    var id: Int { edition.id }

    var have: Int { cover.owned }
    /// On disk plus the aired rest; the episodes still to air draw hollow.
    var aired: Int { max(cover.owned, cover.total - cover.unaired) }
    var total: Int { cover.total }
    var rest: OneInkRail.Piece { OneInkRail.rest(for: state) }
    /// "6/7": on disk of aired, or nil when nothing is tracked.
    var count: String? { aired > 0 ? "\(have)/\(aired)" : nil }

    init(season: Season, edition: DetailEdition, now: Date = Date()) {
        self.edition = edition
        let cover = season.cover(editionId: edition.id, now: now)
        self.cover = cover
        state = Self.state(season, edition: edition, cover: cover, now: now)
    }

    /// Held first (a stuck download or a file that needs attention), then a
    /// live download, then what is on disk.
    static func state(_ season: Season, edition: DetailEdition, cover: Cover, now: Date) -> EditionBadgeState {
        let tracked = season.episodes.filter { $0.monitored != false }
        let kinds = tracked.map { $0.status(editionId: edition.id, now: now) }
        if kinds.contains(where: { $0 == .stuck || $0 == .attention }) { return .held }
        let busy: Set<EpisodeStatusKind> = [.downloading, .upgrading]
        if let live = tracked.first(where: { busy.contains($0.status(editionId: edition.id, now: now)) }) {
            return .downloading(progress: live.download(for: edition.id)?.progress.map { $0 / 100 })
        }
        if cover.total == 0 { return cover.kept > 0 ? .onDisk : .missing }
        if cover.owned >= cover.total { return .onDisk }
        if cover.owned > 0 { return .partial(have: cover.owned, of: cover.total) }
        return .missing
    }
}

/// A season's numbers across its versions: the card's and the page's lines.
struct V2SeasonFacts {
    let lanes: [V2SeasonLane]
    /// Episodes with a file in every version, of the tracked episodes that aired.
    let complete: Int
    let aired: Int
    let upcoming: Int
    let downloading: Int
    let held: Int
    let missing: Int
    let episodeCount: Int
    let firstAir: Date?
    let lastAir: Date?

    init(season: Season, editions: [DetailEdition], now: Date = Date()) {
        lanes = editions.map { V2SeasonLane(season: season, edition: $0, now: now) }
        episodeCount = season.episodes.count
        let dates = season.episodes.compactMap(\.airInstant).sorted()
        firstAir = dates.first
        lastAir = dates.last
        var complete = 0, aired = 0, upcoming = 0, downloading = 0, held = 0, missing = 0
        let tracked = season.monitored == false ? [] : season.episodes.filter { $0.monitored != false }
        for episode in tracked {
            let kinds = editions.map { episode.status(editionId: $0.id, now: now) }
            guard episode.hasAired(now: now) || kinds.contains(where: { $0 != .soon }) else {
                upcoming += 1
                continue
            }
            aired += 1
            if kinds.contains(where: { $0 == .stuck || $0 == .attention }) {
                held += 1
            } else if kinds.contains(where: { $0 == .downloading || $0 == .upgrading }) {
                downloading += 1
            } else if kinds.contains(.missing) {
                missing += 1
            }
            if !editions.isEmpty, editions.allSatisfy({ episode.file(for: $0.id) != nil }) { complete += 1 }
        }
        self.complete = complete
        self.aired = aired
        self.upcoming = upcoming
        self.downloading = downloading
        self.held = held
        self.missing = missing
    }

    /// "8 episodes · 13 Oct to 10 Nov".
    var spanLine: String {
        let count = "\(episodeCount) episode\(episodeCount == 1 ? "" : "s")"
        guard let firstAir, let lastAir else { return count }
        let style = Date.FormatStyle().day().month(.abbreviated)
        if Calendar.current.isDate(firstAir, inSameDayAs: lastAir) { return "\(count) · \(firstAir.formatted(style))" }
        return "\(count) · \(firstAir.formatted(style)) to \(lastAir.formatted(style))"
    }

    /// "1 downloading · 1 held · 1 upcoming", or "All on disk".
    var stateLine: String {
        var parts: [String] = []
        if downloading > 0 { parts.append("\(downloading) downloading") }
        if held > 0 { parts.append("\(held) held") }
        if missing > 0 { parts.append("\(missing) missing") }
        if upcoming > 0 { parts.append("\(upcoming) upcoming") }
        if parts.isEmpty { return aired > 0 ? "All on disk" : "Nothing tracked" }
        return parts.joined(separator: " · ")
    }

    /// The season page's count: "6 of 7 on disk · 1 upcoming".
    var countLine: String {
        var parts = ["\(complete) of \(aired) on disk"]
        if upcoming > 0 { parts.append("\(upcoming) upcoming") }
        return parts.joined(separator: " · ")
    }
}
