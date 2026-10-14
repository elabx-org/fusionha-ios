import SwiftUI
import FusionhaKit

// The poster sheet's Interactive search drill pages: season, then the whole
// season or one episode, then the version.

extension LibraryPosterSheet {
    @ViewBuilder
    var waiting: some View {
        Text(loadFailed ? "Couldn't load this title. Try again." : "Loading…")
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.mut)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
    }

    var seasonsPage: some View {
        SheetPage(title: "Interactive search", caption: "What do you want to search for?") { go(.actions) } content: {
            if let detail {
                let seasons = PosterSheetModel.seasonSummaries(detail, now: Date())
                let latest = seasons.first { $0.number > 0 }?.number
                SheetList {
                    ForEach(Array(seasons.enumerated()), id: \.element.id) { i, s in
                        let state = s.missing > 0 ? "\(s.missing) missing" : (s.aired == 0 ? "not aired yet" : "complete")
                        SheetRow(index: i, label: s.label, detail: "\(state) · \(s.aired)/\(s.total) aired",
                                 tone: s.number == latest ? .recommended : .normal, chevron: true) {
                            go(.episodes(s.number))
                        }
                    }
                    SheetSeparator()
                    SheetRow(index: seasons.count, label: "Whole series", detail: "complete-series packs", chevron: true) {
                        choose(.item, back: .seasons)
                    }
                }
            } else {
                waiting
            }
        }
    }

    func episodesPage(_ season: Int) -> some View {
        let label = season == 0 ? "Specials" : "Season \(season)"
        return SheetPage(title: label) { go(.seasons) } content: {
            if let detail {
                SheetList {
                    SheetRow(index: 0, label: "Whole season", detail: "season packs + every episode in \(label)",
                             tone: .recommended, chevron: true) {
                        choose(.season(season), back: .episodes(season))
                    }
                }
                SheetGroupLabel(text: "Or one episode")
                SheetList {
                    let rows = PosterSheetModel.episodeRows(detail, season: season, now: Date())
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                        SheetRow(index: i + 1, label: String(format: "%02d · %@", r.number, r.title),
                                 detail: episodeDetail(r),
                                 tone: r.state == .missing || r.state == .partial ? .recommended : .normal,
                                 chevron: true) {
                            choose(.episode(season: season, id: r.id, number: r.number), back: .episodes(season))
                        }
                    }
                }
            } else {
                waiting
            }
        }
    }

    func episodeDetail(_ row: PosterSheetModel.EpisodeRow) -> String {
        switch row.state {
        case .have: return "has a file"
        case .missing: return "missing"
        case .partial: return "\(row.missingLabels.joined(separator: ", ")) missing"
        case .unaired: return "not aired yet"
        }
    }

    func versionsPage(_ target: SheetSearchTarget, back: Page) -> some View {
        let what: String
        switch target {
        case .episode(let season, _, let number): what = EpisodeCode.episode(season: season, episode: number)
        case .season(let season): what = "Season \(season) · season pack"
        case .item: what = isSeries ? "Whole series" : item.title
        }
        return SheetPage(title: "Which version?", caption: what) {
            pendingLaunch = false
            go(back)
        } content: {
            if let detail {
                let options = PosterSheetModel.versionOptions(detail, target, now: Date())
                let rec = PosterSheetModel.recommended(options)
                SheetList {
                    ForEach(Array(options.enumerated()), id: \.element.id) { i, o in
                        SheetRow(index: i, label: o.label,
                                 detail: o.id == rec && o.missing ? "missing — most likely what you want"
                                     : (o.missing ? "missing" : "has a file · look for an upgrade"),
                                 tone: o.id == rec ? .recommended : .normal, hint: "1 query") {
                            launch(detail, target, versionId: o.id)
                        }
                    }
                    if options.count > 1 {
                        SheetSeparator()
                        SheetRow(index: options.count, label: "All versions", detail: "switch between them in the results",
                                 hint: "\(options.count) queries") {
                            launch(detail, target, versionId: rec ?? options[0].id, all: true)
                        }
                    }
                }
            } else {
                waiting
            }
        }
    }
}
