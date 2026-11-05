import SwiftUI
import FusionhaKit

/// A season or episode pushed over the title while it fills the flat open
/// Duo (plan `EpisodeChildPane`, mock browse.js season / episode on the
/// inner display): the title's header band stays across the display, the
/// left column lists the siblings and the right column is the page.
/// - Season: the version cards, every season (the open one ringed) and Next
///   up on the left; the season page on the right.
/// - Episode: the season's episodes (the open one ringed) on the left; the
///   episode page on the right.
/// A tap in the left column swaps the right page in place; Back still pops
/// the whole child. The child paints the ground, so the page skips its own
/// (`v2WideChild`).
struct V2TitleWideChild: View {
    @Environment(DetailStore.self) private var store
    @State private var season: Int
    @State private var episodeId: Int?
    @State private var width: CGFloat = 0
    @State private var barInset: CGFloat = 0

    init(route: V2TitleRoute) {
        switch route {
        case .season(let number):
            _season = State(initialValue: number)
            _episodeId = State(initialValue: nil)
        case .episode(let number, let id):
            _season = State(initialValue: number)
            _episodeId = State(initialValue: id)
        }
    }

    private var groundArt: URL? {
        PageArtSource.url(backdrop: store.detail?.backdropUrl, poster: store.detail?.posterUrl)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let detail = store.detail {
                V2TitleBand(detail: detail, height: V2TitleWide.bandHeight(barInset: barInset))
            }
            HStack(alignment: .top, spacing: 0) {
                left
                    .frame(width: V2TitleWide.leftWidth(width) + V2TitleWide.gutter)
                right
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.v2WideChild, true)
            }
            .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { barInset = $0 }
        .v2PageGround(art: groundArt, showsArt: false)
    }

    @ViewBuilder
    private var left: some View {
        if let detail = store.detail {
            if episodeId != nil, let current = detail.seasons?.first(where: { $0.seasonNumber == season }) {
                V2WideEpisodeList(detail: detail, season: current, selected: $episodeId)
            } else {
                V2WideSeasonList(detail: detail, selected: $season)
            }
        }
    }

    @ViewBuilder
    private var right: some View {
        if let episodeId {
            V2EpisodePage(seasonNumber: season, episodeId: episodeId)
                .id(episodeId)
        } else {
            V2SeasonPage(seasonNumber: season)
                .id(season)
        }
    }
}
