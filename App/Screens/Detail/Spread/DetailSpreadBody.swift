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
/// art (`DetailHeroBackdrop`) runs behind the band across both pages and on
/// down both, on a wash of the ground behind their text, fading out at the
/// level of the left page's Versions (`SpreadHeroBackdrop`).
struct DetailSpreadBody: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.motionEnabled) private var motion
    let detail: ItemDetail
    let pages: SpreadGeometry.Pages
    /// After a fold / unfold the episode waits for the old host to leave.
    let episodeReady: Bool
    let openWeb: () -> Void

    private static let margin: CGFloat = 20
    /// The band's frame (global): its height is the art's edge, its top
    /// where the backdrop's header starts under the bar.
    @State private var band = CGRect(x: 0, y: 0, width: 0, height: 130)
    /// The left page's facts (strip end, top of Versions) and its scroll.
    @State private var metrics = HeroHeaderMetrics()
    @State private var tracker = HeroScrollTracker()
    @State private var textWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            DetailSpreadBand(detail: detail) { textWidth = $0 }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { band = $0 }
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
        SpreadHeroBackdrop(url: ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl),
                           band: band, metrics: metrics, tracker: tracker,
                           column: CGFloat(pages.left.width), textWidth: textWidth,
                           beside: store.episodeSheet != nil)
    }

    /// The left page without an episode: the hero's facts, overview, item
    /// actions, versions and the Overview rails. Pulling it down closes the title.
    private var infoPage: some View {
        ScrollViewReader { proxy in
            ScrollView {
                DetailPage(detail: detail, openWeb: openWeb, infoPage: true,
                           onMetrics: { metrics = $0 }, onVersionsOnScreen: { tracker.versionsOnScreen = $0 })
                    .pinnedToProposedWidth()
            }
            .scrollIndicators(.hidden)
            .duoColumnPullSource()
            .task { await screenshotScroll(proxy) }
        }
    }

    /// CI screenshots: the left page scrolled (`FUSIONHA_SCREENSHOT_DETAIL_SCROLL`).
    private func screenshotScroll(_ proxy: ScrollViewProxy) async {
        #if DEBUG
        guard let anchor = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DETAIL_SCROLL"] else { return }
        try? await Task.sleep(for: .seconds(1.2))
        proxy.scrollTo(anchor, anchor: .center)
        #endif
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
