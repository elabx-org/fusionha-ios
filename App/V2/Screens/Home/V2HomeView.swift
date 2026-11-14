import SwiftUI
import FusionhaKit

/// v2's first tab, Home (owner-approved Home mock, 2026-11-06; it was the
/// Library tab): rows to browse (`V2HomeContent`) ending in one door to
/// every title. All titles is the Library grid (`V2LibraryView`), pushed
/// from here ("‹ Home") on the All titles card, a kind's count, Needs you's
/// Show all or Recently added's See all, and by every route that opens the
/// Library or filters it (`AppModel.pendingAllTitles`). Whether All titles
/// is open is kept per window, as the Library's filters are. Home has no
/// filter chips or search field; those live in All titles.
///
/// The push is one idempotent path (`AppModel.allTitles`, `AllTitlesPush`):
/// a tap, a route or a restore opens it once, Back closes it once, and a
/// push the stack dropped under a kept one (a fold, the launch settling) is
/// put back while Home is on screen (`keepPushed`). Across a fold Home keeps
/// the section at its top (`FoldAnchor`) and Coming up its centred card.
struct V2HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
    @Environment(\.collapsedTabs) private var tabs
    /// The Duo's column: the trailing safe-area inset.
    @State private var column: CGFloat = 0
    @AppStorage("fusionha.library.density") private var density = "grid"
    /// All titles was open in this window (restored on relaunch).
    @SceneStorage("v2.home.allTitles") private var allTitlesKept = false
    @State private var entry: V2AllTitlesEntry?
    @State private var data = V2HomeData()
    /// Titles with a held download in the queue (read only when it changes).
    @State private var held: Set<Int> = []
    @State private var width: CGFloat = 0
    /// The focused Coming up card's art: the ground follows it.
    @State private var comingUpArt: URL?
    /// The section at the top, kept across a fold (`FoldAnchor`).
    @State private var anchor = FoldAnchorTracker()
    /// A kept All titles was put back once for this Home (relaunch).
    @State private var restored = false
    /// Recently arrived (imports from History) and the timeline page shown,
    /// kept across launches; the full timeline page is pushed over Home.
    @State private var arrivals = V2ArrivalsFeed()
    @State private var arrived: [V2TimelineEntry] = []
    @AppStorage("v2.home.recentPage") private var recentPageRaw = 0
    @State private var timelineShown = false
    /// Half folded on a table (the fold side to side inside Home's container):
    /// Home spans both halves (`V2HomeTabletop`). Nil in every other pose.
    @State private var tabletop: V2TabletopSpace?

    /// Flat open beside an open title: the list pane takes the title's
    /// palette with no art of its own (the Library's rule, slice S5).
    private var besideArt: URL? {
        guard duoOpen, !bookPose, let id = model.presentedItem?.id,
              let item = model.library.first(where: { $0.id == id }) else { return nil }
        return PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl)
    }

    /// Collapsed tabs (owner, build 1132): Home runs under the Duo's column
    /// to the display's edge. The lines that sit beside the clock and the
    /// arrow at rest (the heading, Needs you, Coming up's menu) keep clear of
    /// them (`V2HomeContent.columnReserve`); the rows below scroll under the
    /// glass. Book pose keeps its pages either side of the fold.
    private var fullWidth: Bool { tabs.on && !bookPose }

    /// Home's sections; the tabletop's bottom half leaves out the heading and
    /// Coming up (the stage), its plain page leaves out Coming up (the row
    /// around it, `V2ComingUpRow`).
    private func content(width: CGFloat, columnReserve: CGFloat, heading: Bool, comingUp: Bool) -> V2HomeContent {
        V2HomeContent(data: data, held: held, width: width, columnReserve: columnReserve,
                      comingUpArt: $comingUpArt,
                      arrived: arrived, recentPage: recentPage, open: openAllTitles, openTimeline: { page in
            recentPage.wrappedValue = page
            timelineShown = true
        }, showsHeading: heading, showsComingUp: comingUp)
    }

    /// Tabletop: the Coming up row is the page's root, so it owns the feed and
    /// the focus and lays Home out across the two halves.
    private func tabletopPage(_ space: V2TabletopSpace) -> some View {
        V2ComingUpRow(width: space.size.width, gutter: 20, wide: false, leadArt: $comingUpArt,
                      tabletop: V2TabletopContext(
                        space: space,
                        plain: AnyView(scrollPage(comingUp: false)),
                        rest: AnyView(content(width: space.size.width, columnReserve: 0, heading: false, comingUp: false))))
    }

    @ViewBuilder
    private var homePage: some View {
        if let tabletop { tabletopPage(tabletop) } else { scrollPage(comingUp: true) }
    }

    var body: some View {
        let _ = PerfCount.hit("V2HomeView.body")
        homePage
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onGeometryChange(for: V2TabletopSpace?.self) { V2TabletopSpace($0) } action: { tabletop = $0 }
            .v2PageGround(art: besideArt ?? comingUpArt ?? data.groundArt, recipe: besideArt == nil ? .page : .listPane,
                          showsArt: besideArt == nil, artHeight: 760, artOpacity: .ambient)
            // The page draws "Home" with the mark itself (`V2HomeHeading`), so
            // the bar has no title (on the folded Duo `.toolbar(removing: .title)`
            // still drew a second "Home" above the page's, build 982).
            // Collapsed tabs: no Add in the arrow's list; Search, listed
            // there, is where you add (search + Add merge, owner 2026-11-12).
            .shellPage("") { if !tabs.on { AddTitleToolbarItem(model: model) } }
            // Home spans both pages of a Spread; All titles keeps the grid's rule.
            .spreadSpansBothPages(.library, !model.allTitles.wanted || density != "compact")
            // Tabletop: Home spans both halves until a title, All titles or the
            // timeline is on top of it (then the shell splits at the fold).
            .tabletopSpansBothHalves(.library, !model.allTitles.wanted && !timelineShown)
            .navigationDestination(isPresented: allTitlesBinding) { V2LibraryView(entry: entry) }
            .navigationDestination(isPresented: $timelineShown) { V2RecentTimelinePage(feed: arrivals, page: recentPage) }
            .task { await arrivals.watch(model.client) }
            .onChange(of: ArrivedKey(rows: arrivals.rows, version: model.libraryVersion), initial: true) {
                let library = Dictionary(model.library.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                arrived = V2TimelineEntries.arrived(arrivals.rows, library: library)
            }
            .task { await restoreKept() }
            // While Home is on screen with the push kept (it went: the page covers Home).
            .task(id: model.allTitles.wanted) { await keepPushed() }
            .task { await model.loadLibraryIfNeeded() }
            .onQueueChange(model, initial: true) { queue in
                let next = Set(queue.filter { QueueProgress($0).held }.map(\.mediaItemId))
                if next != held { held = next }
            }
            .onChange(of: DataKey(version: model.libraryVersion, held: held), initial: true) {
                data = PerfCount.time("V2Home.data") { V2HomeData(library: model.library, held: held) }
            }
            // Routes that open the Library land in All titles (`takeRoute`).
            .task(id: model.pendingAllTitles) { await takeRoute() }
    }

    /// The page of Home's sections, scrolling. `comingUp` false: the Coming up
    /// row is outside it (the tabletop with nothing coming up).
    private func scrollPage(comingUp: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("home-top")
                    content(width: width, columnReserve: fullWidth ? column : 0, heading: true, comingUp: comingUp)
                }
                .padding(.top, 4)
                .padding(.bottom, Theme.pageBottom)
            }
            .ignoresSafeArea(.container, edges: fullWidth ? .trailing : [])
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.trailing } action: { if $0 > 0 { column = $0 } }
            .readsScreenCentre()
            .refreshable { await model.loadLibrary() }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { old, new in
                // Under All titles, Home stays mounted: only the page on top
                // drives the chrome, or the two scroll views fight over it.
                guard !model.allTitles.wanted else { return }
                model.updateChrome(old: old, new: new)
            }
            .keepsFoldAnchor(anchor, proxy: proxy)
            // Tapping the Home tab: under All titles it goes back to Home
            // (the system's pop-to-root); on Home it scrolls to the top.
            .onChange(of: model.scrollToTopTick) {
                if model.allTitles.wanted {
                    withAnimation(motion ? .smooth : nil) { closeAllTitles() }
                } else {
                    withAnimation(motion ? .smooth : nil) { proxy.scrollTo("home-top", anchor: .top) }
                }
            }
            #if DEBUG
            // CI screenshots: `FUSIONHA_SCREENSHOT_HOME_SCROLL=recent|kinds`.
            .task(id: data.recent.count) {
                guard let target = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_HOME_SCROLL"],
                      !data.recent.isEmpty else { return }
                try? await Task.sleep(for: .seconds(4))
                proxy.scrollTo("home-\(target)", anchor: .top)
            }
            #endif
        }
    }

    /// The push lives on the window's model (`AppModel.allTitles`). The
    /// stack writes only pops (`AllTitlesPush.stackSet`).
    private var allTitlesBinding: Binding<Bool> {
        Binding { model.allTitles.presented } set: { shown in
            if model.allTitles.stackSet(shown) { forgetAllTitles() }
        }
    }

    private var recentPage: Binding<V2TimelinePage> {
        Binding { V2TimelinePage(rawValue: recentPageRaw) ?? .added } set: { recentPageRaw = $0.rawValue }
    }

    private func openAllTitles(_ how: V2AllTitlesEntry) {
        show(how, animated: true)
    }

    /// The one way in: pushes All titles unless it is already pushed (or on
    /// its way), so a second tap or a repeated route pushes nothing. Only a
    /// tap on Home animates; routes and restores land in place (an animated
    /// push over a Home still laying out Coming up stalled the folded Duo in CI).
    private func show(_ how: V2AllTitlesEntry?, animated: Bool) {
        guard !model.allTitles.wanted else { return }
        if let how { entry = how }
        allTitlesKept = true
        var transaction = Transaction()
        transaction.disablesAnimations = !animated
        withTransaction(transaction) { _ = model.allTitles.open() }
    }

    /// The one way out besides Back: the Home tab tapped under All titles.
    private func closeAllTitles() {
        model.allTitles.close()
        forgetAllTitles()
    }

    private func forgetAllTitles() {
        allTitlesKept = false
        entry = nil
    }

    /// Once per Home: All titles open in this window before a relaunch
    /// comes back. A beat after Home is up: a destination presented in the
    /// stack's first pass came up blank (CI, build 1).
    private func restoreKept() async {
        guard !restored else { return }
        restored = true
        if Self.freshForScreenshots && !Self.screenshotReset {
            Self.screenshotReset = true
            allTitlesKept = false
        }
        guard allTitlesKept, !model.allTitles.wanted else { return }
        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled else { return }
        show(nil, animated: false)
    }

    /// Home on screen while the push is kept: the shell rebuilt the tab's
    /// stack under it (a fold, the launch settling) and dropped the page,
    /// or the push stalled. Put the same push back (binding false, a beat,
    /// true), checked a few times; never closes it. A pop clears the push
    /// first, so Back stays on Home.
    private func keepPushed() async {
        guard model.allTitles.wanted else { return }
        for wait in [600, 1000, 1000, 1000, 1000] {
            // The first wait outlasts an animated push, whose page appears as it starts.
            try? await Task.sleep(for: .milliseconds(wait))
            guard !Task.isCancelled, model.allTitles.wanted else { return }
            guard model.allTitles.dropped(pageOnScreen: model.allTitlesOnScreen) else { continue }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { model.allTitles.withdraw() }
            try? await Task.sleep(for: .milliseconds(80))
            // Even when cancelled: never leave the push withdrawn.
            withTransaction(instant) { _ = model.allTitles.reassert() }
        }
    }

    /// A route that opens the Library: All titles, once. At launch it waits
    /// for the first library load (up to 3 s): pushed while it was loading,
    /// the stack stalled on Home (CI, small library). Taken here, or by All
    /// titles when it is already up (`V2LibraryView`); a Home torn down
    /// before it was taken leaves it for the next.
    private func takeRoute() async {
        guard model.pendingAllTitles else { return }
        for _ in 0..<30 where !model.libraryLoaded {
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled, model.pendingAllTitles else { return }
        model.pendingAllTitles = false
        show(.asLeft, animated: false)
    }

    /// CI screenshots start on Home unless a shot asks for All titles.
    private static var freshForScreenshots: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"] != nil
        #else
        false
        #endif
    }

    /// Once per launch, screenshots forget a kept All titles (each shot
    /// starts on Home unless it asks for All titles).
    @MainActor private static var screenshotReset = false

    private struct ArrivedKey: Equatable {
        let rows: [ArrivalRow]
        let version: Int
    }

    private struct DataKey: Equatable {
        let version: Int
        let held: Set<Int>
    }
}
