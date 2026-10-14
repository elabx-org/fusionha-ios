import SwiftUI
import FusionhaKit

extension EnvironmentValues {
    /// Press-and-hold on a Library poster opens its quick-actions sheet.
    @Entry var openPosterSheet: ((MediaItem) -> Void)?
}

// MARK: - Interactive search scoping (components/library/poster-sheet-model.ts)

/// What an interactive search from the poster sheet will cover.
enum SheetSearchTarget: Hashable {
    case item
    case season(Int)
    case episode(season: Int, id: Int, number: Int)
}

struct SheetVersionOption: Identifiable {
    let id: Int
    let label: String
    /// No file for the target yet.
    let missing: Bool
}

enum PosterSheetModel {
    private static func hasFile(_ episode: Episode, _ versionId: Int) -> Bool {
        (episode.files ?? []).contains { $0.editionId == versionId && $0.file != nil }
    }

    private static func episodes(_ data: ItemDetail, _ target: SheetSearchTarget) -> [Episode] {
        let seasons = data.seasons ?? []
        switch target {
        case .episode(let season, let id, _):
            return seasons.first { $0.seasonNumber == season }?.episodes.filter { $0.id == id } ?? []
        case .season(let season):
            return seasons.first { $0.seasonNumber == season }?.episodes ?? []
        case .item:
            // Whole series: regular seasons only — specials never drive the pick.
            return seasons.filter { $0.seasonNumber > 0 }.flatMap(\.episodes)
        }
    }

    static func isSeries(_ data: ItemDetail) -> Bool { !(data.seasons ?? []).isEmpty }

    /// Every version, in the item's own order, flagged missing for `target`.
    static func versionOptions(_ data: ItemDetail, _ target: SheetSearchTarget, now: Date) -> [SheetVersionOption] {
        let series = isSeries(data)
        let eps = series ? episodes(data, target) : []
        // The whole series only counts aired episodes, so a far-future season
        // never marks an otherwise complete version missing.
        let relevant: [Episode]
        if case .item = target { relevant = eps.filter { $0.hasAired(now: now) } } else { relevant = eps }
        return data.editions.map { ed in
            let missing = series ? relevant.contains { !hasFile($0, ed.id) } : ed.movieFile == nil
            return SheetVersionOption(id: ed.id, label: ed.label, missing: missing)
        }
    }

    /// The likely pick: the first missing version, else the last (usually 4K).
    static func recommended(_ options: [SheetVersionOption]) -> Int? {
        (options.first { $0.missing } ?? options.last)?.id
    }

    struct SeasonSummary: Identifiable {
        let number: Int
        let label: String
        let total: Int
        let aired: Int
        let missing: Int
        var id: Int { number }
    }

    private static func wantedIds(_ data: ItemDetail) -> [Int] {
        let monitored = data.editions.filter(\.monitored).map(\.id)
        return monitored.isEmpty ? data.editions.map(\.id) : monitored
    }

    /// Seasons newest first, Specials last.
    static func seasonSummaries(_ data: ItemDetail, now: Date) -> [SeasonSummary] {
        let seasons = data.seasons ?? []
        let ordered = seasons.filter { $0.seasonNumber > 0 }.sorted { $0.seasonNumber > $1.seasonNumber }
            + seasons.filter { $0.seasonNumber == 0 }
        let wanted = wantedIds(data)
        return ordered.map { season in
            let aired = season.episodes.filter { $0.hasAired(now: now) }
            return SeasonSummary(number: season.seasonNumber,
                                 label: season.seasonNumber == 0 ? "Specials" : "Season \(season.seasonNumber)",
                                 total: season.episodes.count, aired: aired.count,
                                 missing: aired.filter { ep in wanted.contains { !hasFile(ep, $0) } }.count)
        }
    }

    enum EpisodeState { case have, missing, partial, unaired }

    struct EpisodeRow: Identifiable {
        let id: Int
        let number: Int
        let title: String
        let state: EpisodeState
        let missingLabels: [String]
    }

    static func episodeRows(_ data: ItemDetail, season number: Int, now: Date) -> [EpisodeRow] {
        guard let season = (data.seasons ?? []).first(where: { $0.seasonNumber == number }) else { return [] }
        let ids = wantedIds(data)
        let wanted = data.editions.filter { ids.contains($0.id) }
        return season.episodes.sorted { $0.episodeNumber < $1.episodeNumber }.map { ep in
            let lacking = wanted.filter { !hasFile(ep, $0.id) }
            let state: EpisodeState
            if lacking.isEmpty { state = .have }
            else if !ep.hasAired(now: now) { state = .unaired }
            else { state = lacking.count == wanted.count ? .missing : .partial }
            return EpisodeRow(id: ep.id, number: ep.episodeNumber, title: ep.title ?? "Episode \(ep.episodeNumber)",
                              state: state, missingLabels: state == .partial ? lacking.map(\.label) : [])
        }
    }

    /// The heading subtitle the search sheet shows for a target.
    static func subtitle(_ target: SheetSearchTarget, version: DetailEdition) -> String {
        switch target {
        case .episode(let season, _, let number): return EpisodeCode.episode(season: season, episode: number)
        case .season(let season): return "\(EpisodeCode.season(season)) · Season pack"
        case .item: return version.label
        }
    }
}
