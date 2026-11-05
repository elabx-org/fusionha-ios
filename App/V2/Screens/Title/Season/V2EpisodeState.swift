import Foundation
import FusionhaKit

/// An episode's v2 state across the title's versions: one T5 badge state
/// per version (v1's episode status, `V2TitleNextUp.state`) and the row's
/// status circle.
struct V2EpisodeState {
    enum Circle: Equatable {
        case onDisk
        case missing
        case upcoming
        case held
        /// `percent` 0...100 when the client reports it; `held` when another version is held.
        case downloading(percent: Int?, held: Bool)
    }

    let badges: [(tier: QualityTier, state: EditionBadgeState)]
    let circle: Circle

    init(episode: Episode, editions: [DetailEdition], now: Date = Date()) {
        badges = editions.map { (tier: $0.tier, state: V2TitleNextUp.state(episode, edition: $0, now: now)) }
        let kinds = editions.map { episode.status(editionId: $0.id, now: now) }
        let held = kinds.contains { $0 == .stuck || $0 == .attention }
        if let live = editions.first(where: { [EpisodeStatusKind.downloading, .upgrading].contains(episode.status(editionId: $0.id, now: now)) }) {
            let progress = episode.download(for: live.id)?.progress
            circle = .downloading(percent: progress.map { Int($0.rounded()) }, held: held)
        } else if held {
            circle = .held
        } else if !editions.isEmpty, editions.allSatisfy({ episode.file(for: $0.id) != nil }) {
            circle = .onDisk
        } else if !episode.hasAired(now: now) {
            circle = .upcoming
        } else {
            circle = .missing
        }
    }

    /// "On disk", "Missing", "Airs Tue 10 Nov", "Downloading 62%", "Held".
    var spoken: String {
        switch circle {
        case .onDisk: return "On disk"
        case .missing: return "Missing"
        case .upcoming: return "Not aired yet"
        case .held: return "Held, needs you"
        case .downloading(let percent, let held):
            let pct = percent.map { " \($0)%" } ?? ""
            return "Downloading\(pct)\(held ? ", one version held" : "")"
        }
    }
}

enum V2EpisodeText {
    /// "E4 · 48m · Oct 20" (anime adds "#52").
    static func meta(_ episode: Episode, anime: Bool) -> String {
        var parts = ["E\(episode.episodeNumber)"]
        if anime, let abs = episode.absoluteNumber { parts[0] += " · #\(abs)" }
        if let runtime = episode.runtime, runtime > 0 { parts.append("\(runtime)m") }
        if let date = episode.airInstant { parts.append(date.formatted(.dateTime.month(.abbreviated).day())) }
        return parts.joined(separator: " · ")
    }

    /// "S1 · E4 · Oct 20 '26 · 48m" (the episode page).
    static func pageMeta(_ episode: Episode, season: Int) -> String {
        var parts = ["S\(season)", "E\(episode.episodeNumber)"]
        if let date = episode.airInstant {
            let year = date.formatted(.dateTime.year(.twoDigits))
            parts.append("\(date.formatted(.dateTime.month(.abbreviated).day())) ’\(year)")
        }
        if let runtime = episode.runtime, runtime > 0 { parts.append("\(runtime)m") }
        return parts.joined(separator: " · ")
    }

    /// The row's line where an episode has no overview: "Airs Tue 10 Nov".
    static func noSynopsis(_ episode: Episode, now: Date = Date()) -> String {
        guard let date = episode.airInstant else { return "No synopsis yet" }
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "No synopsis yet · \(date > now ? "airs" : "aired") \(day)"
    }
}
