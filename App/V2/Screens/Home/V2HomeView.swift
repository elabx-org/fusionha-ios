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
struct V2HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.bookPose) private var bookPose
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

    /// Flat open beside an open title: the list pane takes the title's
    /// palette with no art of its own (the Library's rule, slice S5).
    private var besideArt: URL? {
        guard duoOpen, !bookPose, let id = model.presentedItem?.id,
              let item = model.library.first(where: { $0.id == id }) else { return nil }
        return PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl)
    }

    var body: some View {
        let _ = PerfCount.hit("V2HomeView.body")
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("home-top")
                    V2HomeContent(data: data, held: held, width: width, comingUpArt: $comingUpArt, open: openAllTitles)
                }
                .padding(.top, 4)
                .padding(.bottom, Theme.pageBottom)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .refreshable { await model.loadLibrary() }
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { old, new in
                // Under All titles, Home stays mounted: only the page on top
                // drives the chrome, or the two scroll views fight over it.
                guard !model.allTitlesShown else { return }
                model.updateChrome(old: old, new: new)
            }
            // Tapping the Home tab: under All titles it goes back to Home
            // (the system's pop-to-root); on Home it scrolls to the top.
            .onChange(of: model.scrollToTopTick) {
                if model.allTitlesShown {
                    withAnimation(motion ? .smooth : nil) { model.allTitlesShown = false }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .v2PageGround(art: besideArt ?? comingUpArt ?? data.groundArt, recipe: besideArt == nil ? .page : .listPane,
                      showsArt: besideArt == nil, artHeight: 760, artOpacity: .ambient)
        // The page draws "Home" with the mark itself (`V2HomeHeading`), so
        // the bar has no title (on the folded Duo `.toolbar(removing: .title)`
        // still drew a second "Home" above the page's, build 982).
        .shellPage("") { AddTitleToolbarItem(model: model) }
        // Home spans both pages of a Spread; All titles keeps the grid's rule.
        .spreadSpansBothPages(.library, !model.allTitlesShown || density != "compact")
        .navigationDestination(isPresented: allTitlesBinding) { V2LibraryView(entry: entry) }
        .onChange(of: model.allTitlesShown) { _, shown in
            allTitlesKept = shown
            if !shown { entry = nil }
        }
        // Home on screen while the push is set: the tab's stack was rebuilt
        // under it (the shell settling at launch, a fold) and dropped All
        // titles. Push it again. A pop clears the flag before Home appears.
        .onAppear {
            guard model.allTitlesShown else { return }
            model.allTitlesShown = false
            Task { await push(nil, animated: false) }
        }
        // Restores All titles on relaunch and when a fold rebuilds the shell
        // (a new Home whose push state starts false).
        .task {
            if Self.freshForScreenshots && !Self.screenshotReset {
                Self.screenshotReset = true
                allTitlesKept = false
            }
            if allTitlesKept && !model.allTitlesShown { await push(nil, animated: false) }
        }
        .task { await model.loadLibraryIfNeeded() }
        .onQueueChange(model, initial: true) { queue in
            let next = Set(queue.filter { QueueProgress($0).held }.map(\.mediaItemId))
            if next != held { held = next }
        }
        .onChange(of: DataKey(version: model.libraryVersion, held: held), initial: true) {
            data = PerfCount.time("V2Home.data") { V2HomeData(library: model.library, held: held) }
        }
        // Routes that open the Library land in All titles. At launch the
        // push waits for the first library load (up to 3 s): pushed while
        // it was loading, the stack stalled on Home (CI, small library).
        // The push is checked, not trusted: the shell can rebuild the stack
        // under it while it settles at launch, so it is pushed again until
        // All titles is on screen (five tries a second apart). The route is
        // consumed only then: a Home torn down mid-way leaves it for the next.
        .task(id: model.pendingAllTitles) {
            guard model.pendingAllTitles else { return }
            for _ in 0..<30 where !model.libraryLoaded {
                try? await Task.sleep(for: .milliseconds(100))
            }
            for _ in 0..<5 where !model.allTitlesOnScreen {
                guard !Task.isCancelled, model.pendingAllTitles else { return }
                model.allTitlesShown = false
                guard await push(.asLeft, animated: false) else { return }
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            model.pendingAllTitles = false
        }
    }

    /// The push lives on the window's model (`AppModel.allTitlesShown`),
    /// set a beat after Home is up: a destination presented in the stack's
    /// first pass came up blank (CI, build 1).
    private var allTitlesBinding: Binding<Bool> {
        Binding { model.allTitlesShown } set: { model.allTitlesShown = $0 }
    }

    private func openAllTitles(_ how: V2AllTitlesEntry) {
        Task { await push(how, animated: true) }
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

    /// False when this Home went away before the push (nothing was set).
    /// Only a tap on Home animates; routes and restores land in place (an
    /// animated push over a Home still laying out Coming up stalled the
    /// folded Duo in CI).
    @discardableResult
    private func push(_ how: V2AllTitlesEntry?, animated: Bool) async -> Bool {
        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled else { return false }
        if let how { entry = how }
        // Kept here, not only in onChange: a Home rebuilt in the same
        // update (the shell settling its layout) restores from it.
        allTitlesKept = true
        var transaction = Transaction()
        transaction.disablesAnimations = !animated
        withTransaction(transaction) { model.allTitlesShown = true }
        return true
    }

    private struct DataKey: Equatable {
        let version: Int
        let held: Set<Int>
    }
}
