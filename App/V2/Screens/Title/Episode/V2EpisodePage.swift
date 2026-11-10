import SwiftUI
import FusionhaKit

/// An episode, pushed from its season (mock browse.js `episodePhone`,
/// browse-sheets.js `BRS.episode`, slice S6): the art (the episode's still,
/// else the series backdrop) with the episode's title in white on its
/// darkened foot and "S1 · E4 · Oct 20 '26 · 48m", then Details | History |
/// Search. The bar carries Automatic search, Interactive search and the
/// file's actions. Everything runs v1's episode code on the title's store.
struct V2EpisodePage: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.detailReduceMotion) private var reduce
    @Environment(\.columnPage) private var column
    /// Beside the season's list on the flat open Duo (`V2TitleWideChild`):
    /// the band above carries the art, so a short header instead of the hero.
    @Environment(\.v2WideChild) private var wideChild
    /// The window's kept stacks: the page keeps its place across a fold.
    @Environment(V2TitleStacks.self) private var stacks: V2TitleStacks?
    let seasonNumber: Int
    let episodeId: Int
    @State private var tab: EpisodeSheetTab = .details
    @State private var versionId: Int?
    @State private var search: InteractiveSearchModel?
    @State private var compact = false
    @State private var width: CGFloat = 0
    /// The hero's (or the wide header's) height, for the kept offset.
    @State private var headerHeight: CGFloat = 0

    private var detail: ItemDetail? { store.detail }
    private var episode: Episode? {
        detail?.seasons?.first { $0.seasonNumber == seasonNumber }?.episodes.first { $0.id == episodeId }
    }
    private var groundArt: URL? { PageArtSource.url(backdrop: detail?.backdropUrl, poster: detail?.posterUrl) }

    var body: some View {
        Group {
            if let detail, let episode {
                page(detail, episode)
                    .toolbar { V2EpisodeToolbar(detail: detail, episode: episode, seasonNumber: seasonNumber,
                                                version: version(detail, episode)) }
                    // Its own three buttons stay for now: the file menu asks before
                    // deleting with a dialog of its own, which a menu's row can't show.
                    .columnArrow(column.collapsed, beforeSwitch: column.close)
            } else {
                EmptyBox(message: "This episode is no longer in the library.")
                    .padding(20)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .v2PageGroundUnlessWideChild(art: groundArt, showsArt: false)
        .navigationTitle(compact ? (episode?.title ?? "") : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(compact ? .visible : .hidden, for: .navigationBar)
        .animation(reduce ? nil : .easeInOut(duration: 0.2), value: compact)
        .overlay(alignment: .top) { V2TitleToast(store: store, reduceMotion: reduce) }
        .onChange(of: tab) { _, new in
            guard new == .search, search == nil, let detail, let episode else { return }
            search = makeSearch(detail, episode)
        }
    }

    private func page(_ detail: ItemDetail, _ episode: Episode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if wideChild {
                        V2EpisodeWideHeader(detail: detail, episode: episode, seasonNumber: seasonNumber)
                            .padding(.horizontal, 24)
                            .padding(.top, 14)
                    } else {
                        V2EpisodeHero(detail: detail, episode: episode, seasonNumber: seasonNumber)
                    }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Episode", selection: $tab) {
                        ForEach(EpisodeSheetTab.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .sensoryFeedback(.selection, trigger: tab)
                    pane(detail, episode)
                        .id(tab)
                        .transition(.opacity)
                }
                .padding(.horizontal, width >= 560 ? 24 : 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .animation(reduce ? nil : .easeInOut(duration: 0.2), value: tab)
            }
            .pinnedToProposedWidth()
        }
        .scrollIndicators(.hidden)
        .v2EpisodeKeepsPlace(stacks?.place(.episode(season: seasonNumber, episodeId: episodeId), on: store.itemId),
                             header: $headerHeight, tab: $tab, versionId: $versionId)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectHidden(!compact, for: .top)
        .ignoresSafeArea(.container, edges: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > 200
        } action: { _, past in
            compact = past
        }
    }

    @ViewBuilder
    private func pane(_ detail: ItemDetail, _ episode: Episode) -> some View {
        switch tab {
        case .details:
            V2EpisodeDetailsPane(detail: detail, episode: episode, seasonNumber: seasonNumber,
                                 version: version(detail, episode), versionId: versionBinding(detail, episode))
        case .history:
            V2EpisodeHistoryPane(detail: detail, episode: episode, seasonNumber: seasonNumber,
                                 version: version(detail, episode), versionId: versionBinding(detail, episode))
        case .search:
            if let search {
                V2InteractiveSearchPane(model: search, embedded: true)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
            }
        }
    }

    /// The version shown: the one picked, else the first with a file, else the first.
    private func version(_ detail: ItemDetail, _ episode: Episode) -> DetailEdition? {
        let editions = detail.orderedEditions
        if let versionId, let picked = editions.first(where: { $0.id == versionId }) { return picked }
        return editions.first { episode.file(for: $0.id) != nil } ?? editions.first
    }

    private func versionBinding(_ detail: ItemDetail, _ episode: Episode) -> Binding<Int> {
        Binding(get: { version(detail, episode)?.id ?? 0 }, set: { versionId = $0 })
    }

    /// The Search tab: the version shown when it is missing this episode, else
    /// the first version that is (v1's episode sheet rule).
    private func makeSearch(_ detail: ItemDetail, _ episode: Episode) -> InteractiveSearchModel {
        let editions = detail.orderedEditions
        let shown = version(detail, episode)
        let pick = shown.flatMap { episode.file(for: $0.id) == nil ? $0 : nil }
            ?? editions.first { episode.file(for: $0.id) == nil } ?? shown
        return InteractiveSearchModel(store: store, target: InteractiveTarget(
            editionIds: pick.map { [$0.id] } ?? [], episodeId: episode.id,
            subtitle: "S\(seasonNumber)·E\(episode.episodeNumber)"))
    }
}

/// The episode's art with its title on the foot (white in every palette).
struct V2EpisodeHero: View {
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    let episode: Episode
    let seasonNumber: Int

    private var light: Bool { page?.isLight ?? Theme.isLight }
    /// The episode's still at full size (TMDB `original`; another provider's
    /// as stored), else the series backdrop.
    private var art: URL? {
        TMDBImage.resized(episode.stillUrl, to: "original")
            ?? ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl)
    }

    var body: some View {
        Color.clear
            .containerRelativeFrame(.vertical) { length, _ in min(max(length * 0.41, 206), 360) }
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    PosterImage(url: art)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    V2HeroShade(light: light, tint: page?.tint)
                }
                .clipped()
                .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title ?? "Episode \(episode.episodeNumber)")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-0.6)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .shadow(color: .black.opacity(0.5), radius: 9, y: 2)
                        .accessibilityAddTraits(.isHeader)
                    Text(V2EpisodeText.pageMeta(episode, season: seasonNumber))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }
    }
}
