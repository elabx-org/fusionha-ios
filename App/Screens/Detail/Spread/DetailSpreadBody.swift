import SwiftUI
import FusionhaKit

/// The title split at the fold while it fills the open display in a Spread
/// (`TitleSpread`): the art band across both pages (the parent header spans,
/// its children sit below), then two pages that scroll on their own, nothing
/// in the fold and text 20 pt from each page's edges.
///
/// - An episode open: the title's tabs on the left page with the episode's
///   row marked, the episode itself on the right (`EpisodeDetailSheet`
///   inline). Another row swaps only the right page.
/// - Otherwise (the list hidden with the sidebar button): the facts,
///   versions and Overview rails on the left page, the tabs on the right.
///
/// Both pages sit on the art ground with the cards' colour bleed. The hero
/// art (`DetailHeroBackdrop`) runs behind the band across both pages; on the
/// left page it carries on behind the facts and fades out where Versions
/// start, on a wash of the ground behind the text; on the right page it lets
/// go just under the band, where the tabs begin.
struct DetailSpreadBody: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.motionEnabled) private var motion
    let detail: ItemDetail
    let pages: SpreadGeometry.Pages
    /// After a fold / unfold the episode waits for the old host to leave.
    let episodeReady: Bool
    let openWeb: () -> Void

    private static let margin: CGFloat = 20
    @State private var bandHeight: CGFloat = 130
    /// The left page's header (facts to the top of Versions); 0 beside an episode.
    @State private var headerHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            DetailSpreadBand(detail: detail)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bandHeight = $0 }
            if let target = store.episodeSheet {
                FoldSplitLayout(primary: CGFloat(pages.left.width), gap: CGFloat(pages.gap)) {
                    tabsPage(marking: target.episodeId)
                    episodePage(target)
                }
            } else {
                FoldSplitLayout(primary: CGFloat(pages.left.width), gap: CGFloat(pages.gap)) {
                    infoPage
                    tabsPage(marking: nil)
                }
            }
        }
        .background(alignment: .top) { backdrop }
        .environment(\.cardBleed, true)
    }

    private var backdrop: some View {
        let header = store.episodeSheet == nil ? headerHeight : 0
        return DetailHeroBackdrop(
            url: ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl),
            layout: HeroBackdropLayout(style: .band, edge: bandHeight,
                                       end: header > 0 ? bandHeight + header : bandHeight + 28,
                                       column: CGFloat(pages.left.width)),
            underBar: true)
    }

    /// The left page without an episode: the hero's facts, overview, item
    /// actions, versions and the Overview rails. Pulling it down closes the title.
    private var infoPage: some View {
        ScrollView {
            DetailPage(detail: detail, openWeb: openWeb, infoPage: true) { headerHeight = $0 }
                .pinnedToProposedWidth()
        }
        .scrollIndicators(.hidden)
        .duoColumnPullSource()
    }

    /// The title's tabs. Beside an episode they keep Overview and bring the
    /// episode's row into view; beside the facts Overview is on the left page.
    private func tabsPage(marking episodeId: Int?) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                DetailTabsView(detail: detail, openWeb: openWeb)
                    .padding(.horizontal, Self.margin)
                    .padding(.bottom, 32)
                    .pinnedToProposedWidth()
            }
            .scrollIndicators(.hidden)
            .task {
                guard let episodeId else { return }
                try? await Task.sleep(for: .milliseconds(150))
                proxy.scrollTo(EpisodeRowID.make(episodeId), anchor: .center)
            }
        }
        .environment(\.detailTabsOmitOverview, episodeId == nil)
    }

    /// The episode as the right page; a new episode swings in over the last.
    private func episodePage(_ target: EpisodeSheetTarget) -> some View {
        ZStack(alignment: .top) {
            if episodeReady {
                EpisodeDetailSheet(target: target, inline: true)
                    .id(target.episodeId)
                    .transition(DuoPageMotion.transition(motion: motion))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(DuoPageMotion.animation(motion: motion), value: target.episodeId)
    }
}

/// The scroll id of an episode row in the Seasons tab.
enum EpisodeRowID {
    static func make(_ episodeId: Int) -> String { "episode-\(episodeId)" }
}
