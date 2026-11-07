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
    /// The push itself, set a beat after Home is up: a destination
    /// presented in the stack's first pass came up blank (CI, build 1).
    @State private var showsAllTitles = false
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
                model.updateChrome(old: old, new: new)
            }
            .onChange(of: model.scrollToTopTick) {
                withAnimation(motion ? .smooth : nil) { proxy.scrollTo("home-top", anchor: .top) }
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
        // Wide, the page draws "Home" itself (`V2HomeContent.heading`).
        .shellPage(width >= 700 ? "" : "Home") { AddTitleToolbarItem(model: model) }
        // Home spans both pages of a Spread; All titles keeps the grid's rule.
        .spreadSpansBothPages(.library, !showsAllTitles || density != "compact")
        .navigationDestination(isPresented: $showsAllTitles) { V2LibraryView(entry: $entry) }
        .onChange(of: showsAllTitles) { _, shown in allTitlesKept = shown }
        // Restores All titles on relaunch and when a fold rebuilds the shell
        // (a new Home whose push state starts false).
        .task {
            if Self.freshForScreenshots && !Self.screenshotReset {
                Self.screenshotReset = true
                allTitlesKept = false
            }
            if allTitlesKept && !showsAllTitles { await push(nil) }
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
        // The route is consumed only once the push lands: a fold that
        // rebuilds the shell mid-wait leaves it for the new Home.
        .task(id: model.pendingAllTitles) {
            guard model.pendingAllTitles else { return }
            var waited = false
            for _ in 0..<30 where !model.libraryLoaded {
                waited = true
                try? await Task.sleep(for: .milliseconds(100))
            }
            // Let Home lay out the loaded library before the push.
            if waited { try? await Task.sleep(for: .milliseconds(600)) }
            guard !Task.isCancelled, model.pendingAllTitles else { return }
            if await push(.asLeft) { model.pendingAllTitles = false }
        }
    }

    private func openAllTitles(_ how: V2AllTitlesEntry) {
        Task { await push(how) }
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
    @discardableResult
    private func push(_ how: V2AllTitlesEntry?) async -> Bool {
        try? await Task.sleep(for: .milliseconds(80))
        guard !Task.isCancelled else { return false }
        if let how { entry = how }
        showsAllTitles = true
        return true
    }

    private struct DataKey: Equatable {
        let version: Int
        let held: Set<Int>
    }
}
