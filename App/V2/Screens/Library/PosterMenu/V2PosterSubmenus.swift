import SwiftUI
import FusionhaKit

// The poster context menu's Interactive search submenus: season, then the
// whole season (first) or one episode, then Which version?. The counts and
// words are v1's drill pages (`LibraryPosterSheet+Pages`, `PosterSheetModel`).

/// Interactive search ›: every season with "n missing · a/t aired", then
/// Whole series ("complete-series packs").
struct V2PosterSeasonsMenu: View {
    let item: MediaItem
    let detail: ItemDetail
    let launch: V2PosterLaunch

    var body: some View {
        let seasons = PosterSheetModel.seasonSummaries(detail, now: Date())
        Section("What do you want to search for?") {
            ForEach(seasons) { s in
                Menu {
                    V2PosterEpisodesMenu(item: item, detail: detail, season: s.number, launch: launch)
                } label: {
                    Text(s.label)
                    Text("\(s.missing > 0 ? "\(s.missing) missing" : (s.aired == 0 ? "not aired yet" : "complete")) · \(s.aired)/\(s.total) aired")
                }
            }
        }
        Section {
            V2PosterVersionsMenu(item: item, detail: detail, target: .item, launch: launch) {
                Text("Whole series")
                Text("complete-series packs")
            }
        }
    }
}

/// Season N ›: Whole season first, then "Or one episode".
struct V2PosterEpisodesMenu: View {
    let item: MediaItem
    let detail: ItemDetail
    let season: Int
    let launch: V2PosterLaunch

    private var label: String { season == 0 ? "Specials" : "Season \(season)" }

    var body: some View {
        Section {
            V2PosterVersionsMenu(item: item, detail: detail, target: .season(season), launch: launch) {
                Text("Whole season")
                Text("season packs + every episode in \(label)")
            }
        }
        Section("Or one episode") {
            ForEach(PosterSheetModel.episodeRows(detail, season: season, now: Date())) { r in
                V2PosterVersionsMenu(item: item, detail: detail,
                                     target: .episode(season: season, id: r.id, number: r.number), launch: launch) {
                    Text(String(format: "%02d · %@", r.number, r.title))
                    Text(Self.state(r))
                }
            }
        }
    }

    static func state(_ row: PosterSheetModel.EpisodeRow) -> String {
        switch row.state {
        case .have: return "has a file"
        case .missing: return "missing"
        case .partial: return "\(row.missingLabels.joined(separator: ", ")) missing"
        case .unaired: return "not aired yet"
        }
    }
}

/// One target: a single-version title searches at once; otherwise a
/// "Which version?" submenu with each version (its state and "1 query",
/// the likely pick said first) and All versions.
struct V2PosterVersionsMenu<Title: View>: View {
    let item: MediaItem
    let detail: ItemDetail
    let target: SheetSearchTarget
    let launch: V2PosterLaunch
    @ViewBuilder var title: Title

    var body: some View {
        if detail.editions.count == 1 {
            Button { launch(detail, target, detail.editions[0].id, false) } label: { title }
        } else {
            Menu {
                versions
            } label: {
                title
            }
        }
    }

    private var what: String {
        switch target {
        case .episode(let season, _, let number): return EpisodeCode.episode(season: season, episode: number)
        case .season(let season): return "Season \(season) · season pack"
        case .item: return item.kind != .movie ? "Whole series" : item.title
        }
    }

    @ViewBuilder
    private var versions: some View {
        let options = PosterSheetModel.versionOptions(detail, target, now: Date())
        let rec = PosterSheetModel.recommended(options)
        Section("Which version? · \(what)") {
            ForEach(options) { o in
                Button { launch(detail, target, o.id, false) } label: {
                    Text(o.label)
                    Text(hint(o, recommended: o.id == rec))
                }
            }
        }
        if options.count > 1 {
            Section {
                Button { launch(detail, target, rec ?? options[0].id, true) } label: {
                    Text("All versions")
                    Text("switch between them in the results · \(options.count) queries")
                }
            }
        }
    }

    private func hint(_ o: SheetVersionOption, recommended: Bool) -> String {
        let state = recommended && o.missing ? "missing — most likely what you want"
            : (o.missing ? "missing" : "has a file · look for an upgrade")
        return "\(state) · 1 query"
    }
}
