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
    @SceneStorage("v2.home.allTitles") private var showsAllTitles = false
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
        .shellPage("Home") { AddTitleToolbarItem(model: model) }
        // Home spans both pages of a Spread; All titles keeps the grid's rule.
        .spreadSpansBothPages(.library, !showsAllTitles || density != "compact")
        .navigationDestination(isPresented: $showsAllTitles) { V2LibraryView(entry: $entry) }
        .task { await model.loadLibraryIfNeeded() }
        .onQueueChange(model, initial: true) { queue in
            let next = Set(queue.filter { QueueProgress($0).held }.map(\.mediaItemId))
            if next != held { held = next }
        }
        .onChange(of: DataKey(version: model.libraryVersion, held: held), initial: true) {
            data = PerfCount.time("V2Home.data") { V2HomeData(library: model.library, held: held) }
        }
        .onChange(of: model.pendingAllTitles, initial: true) { _, pending in
            guard pending else { return }
            model.pendingAllTitles = false
            openAllTitles(.asLeft)
        }
    }

    private func openAllTitles(_ how: V2AllTitlesEntry) {
        entry = how
        showsAllTitles = true
    }

    private struct DataKey: Equatable {
        let version: Int
        let held: Set<Int>
    }
}
