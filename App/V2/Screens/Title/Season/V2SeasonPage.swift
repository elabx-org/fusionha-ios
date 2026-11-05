import SwiftUI
import FusionhaKit

/// A season, pushed from its card (mock browse.js `seasonPhone` /
/// `seasonTop`, slice S6): on the series' art-palette ground, the bar's
/// "Season 1 / 6 of 7 on disk · 1 upcoming" and ⋯, one tick lane per
/// version, Search missing, then the episode rows in one frosted card, each with a small still
/// (each row's background is its slice of the card). A row pushes its
/// episode; swiping it offers Monitor (bookmark) and Search. A list, so
/// the swipe actions are the system's.
struct V2SeasonPage: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.detailReduceMotion) private var reduce
    let seasonNumber: Int
    @State private var width: CGFloat = 0

    private var detail: ItemDetail? { store.detail }
    private var season: Season? { detail?.seasons?.first { $0.seasonNumber == seasonNumber } }
    private var canEdit: Bool { model.me?.can("edit") ?? true }
    private var canSearch: Bool { canEdit && (model.me?.can("search") ?? true) }

    private var groundArt: URL? {
        PageArtSource.url(backdrop: detail?.backdropUrl, poster: detail?.posterUrl)
    }

    var body: some View {
        Group {
            if let detail, let season {
                let facts = V2SeasonFacts(season: season, editions: detail.orderedEditions)
                list(detail, season, facts)
                    .toolbar { toolbar(detail, season, facts) }
            } else {
                EmptyBox(message: "This season is no longer in the library.")
                    .padding(20)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .v2PageGroundUnlessWideChild(art: groundArt)
        .navigationTitle(season?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { V2TitleToast(store: store, reduceMotion: reduce) }
    }

    private func list(_ detail: ItemDetail, _ season: Season, _ facts: V2SeasonFacts) -> some View {
        let oldest = store.oldestFirst.contains(seasonNumber)
        let episodes = season.episodes.sorted { oldest ? $0.episodeNumber < $1.episodeNumber : $0.episodeNumber > $1.episodeNumber }
        let editions = detail.orderedEditions
        // Owner pick (2026-11-05, "alternative"): every row keeps a small
        // still. The series art until the server sends episode stills.
        let still = TMDBImage.resized(detail.backdropUrl ?? detail.posterUrl, to: "w300")
        return List {
            V2SeasonPageHeader(detail: detail, season: season, facts: facts, canSearch: canSearch)
                .listRowInsets(EdgeInsets(top: 8, leading: gutter, bottom: 16, trailing: gutter))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            ForEach(Array(episodes.enumerated()), id: \.element.id) { index, episode in
                V2EpisodeRow(detail: detail, episode: episode,
                             state: V2EpisodeState(episode: episode, editions: editions),
                             monitored: store.episodeMonitored(episode), stillURL: still)
                    .background {
                        NavigationLink(value: V2TitleRoute.episode(season: seasonNumber, episodeId: episode.id)) { EmptyView() }
                            .opacity(0)
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens the episode")
                    // Inside the episode card: the gutter plus the card's inset.
                    .listRowInsets(EdgeInsets(top: 0, leading: gutter + ModuleMetrics.inset, bottom: 0,
                                              trailing: gutter + ModuleMetrics.inset))
                    .listRowBackground(ModuleListSegment(
                        position: .init(index: index, count: episodes.count), gutter: gutter,
                        hairlineLeading: ModuleMetrics.inset + V2EpisodeRow.textLeading(hasStill: still != nil)))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        swipe(detail, episode)
                    }
                    .contextMenu { V2EpisodeContextMenu(detail: detail, seasonNumber: seasonNumber, episode: episode) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 32, for: .scrollContent)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var gutter: CGFloat { width >= 560 ? 24 : 16 }

    @ViewBuilder
    private func swipe(_ detail: ItemDetail, _ episode: Episode) -> some View {
        if canSearch {
            Button {
                let code = EpisodeCode.episode(season: seasonNumber, episode: episode.episodeNumber)
                Task { await store.search(label: "\(detail.title) \(code)", episodeId: episode.id) }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tint(.blue)
        }
        if canEdit {
            let on = store.episodeMonitored(episode)
            Button {
                Task { await store.setEpisodeMonitored(episode, seasonNumber: seasonNumber, !on) }
            } label: {
                Label(on ? "Unmonitor" : "Monitor", systemImage: on ? "bookmark" : "bookmark.fill")
            }
            .tint(Theme.i1)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ detail: ItemDetail, _ season: Season, _ facts: V2SeasonFacts) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(season.title).font(.system(size: 17, weight: .bold))
                Text(facts.countLine)
                    .font(.system(size: 12.5))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
        ToolbarItem(placement: .topBarTrailing) {
            V2SeasonActionsMenu(detail: detail, season: season, missing: facts.missing)
        }
    }
}

/// The season's lanes and Search missing, above the episodes (mock
/// `seasonTop .slanes`) on its own frosted card, so they stay readable on
/// bright art: thin tick lanes, each keeping its T5 badge (badges
/// wherever editions show) but not its count, since the bar says how many.
private struct V2SeasonPageHeader: View {
    @Environment(DetailStore.self) private var store
    let detail: ItemDetail
    let season: Season
    let facts: V2SeasonFacts
    let canSearch: Bool

    private var searching: Bool { store.flash?.phase == .searching }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                ForEach(facts.lanes) { V2SeasonLaneRow(lane: $0, showsCount: false) }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            if canSearch && facts.missing > 0 {
                Button {
                    Task { await store.gradualSearch(label: "\(detail.title) \(season.title)", season: season.seasonNumber,
                                                     missingOnly: true) }
                } label: {
                    Label("Search missing", systemImage: "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.glass)
                .disabled(searching)
                .accessibilityHint("Searches the \(facts.missing) missing episode\(facts.missing == 1 ? "" : "s"), one at a time")
            }
        }
        .frame(maxWidth: .infinity)
        .v2CardStyle()
    }
}
