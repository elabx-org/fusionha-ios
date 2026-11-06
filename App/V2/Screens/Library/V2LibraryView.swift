import SwiftUI
import FusionhaKit

/// v2's Library tab (slice S4; mocks browse.js home, browse-lib.js, F1 of
/// filters-alt.js, on the S3 ground and W1 cards). One scroll: the home
/// (`V2LibraryPageTop`) then "All titles" as the A–Z poster grid with the
/// scroll thumb, the status-grouped grid, a plain grid for other sorts, or
/// the compact list. The ground comes from the first hero's art.
///
/// It reuses v1's store and logic: the model's library, `LibraryInputs`
/// (filtering, counting, rows), the filters (per window, seeded from v1's keys), the
/// scrubber, the poster sheet and the select bar. A tap opens v2's title
/// page (`V2TitleView`). Phone and the folded Duo: three posters a row; flat open
/// the grid simply widens across the seamless display; book pose keeps the
/// fold in a gutter.
struct V2LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.spread) private var spread
    @Environment(\.bookPose) private var bookPose
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.horizontalSizeClass) private var sizeClass
    // The filters follow the window (split screen), seeded from the ones
    // used last (`V2LibrarySceneFilters`). Show › Not monitored is v2's own.
    @SceneStorage("v2.library.kind") private var kindRaw = V2LibraryFilterSeed.kind
    @AppStorage("fusionha.library.density") private var density = "grid"
    @SceneStorage("v2.library.tier") private var tier: LibraryTier = V2LibraryFilterSeed.tier
    @SceneStorage("v2.library.status") private var status: LibraryStatus = V2LibraryFilterSeed.status
    @SceneStorage("v2.library.sort") private var sort: LibrarySort = V2LibraryFilterSeed.sort
    @SceneStorage("v2.library.recency") private var recency: LibraryRecency = V2LibraryFilterSeed.recency
    @SceneStorage("v2.library.group") private var group = V2LibraryFilterSeed.group
    @SceneStorage("v2.library.unmonitored") private var unmonitoredOnly = V2LibraryFilterSeed.unmonitored
    @AppStorage("v2.library.shelf") private var shelf: V2LibraryShelfSource = .recentlyAdded
    @State private var compactSort = CompactSort()
    @State private var derived = LibraryDerived()
    /// What `derived` was built from, but its columns (`V2LibraryDeriveKey`).
    @State private var derivedKey: V2LibraryDeriveKey?
    @State private var home = V2LibraryHome()
    /// Titles with a held download in the queue (read only when it changes).
    @State private var held: Set<Int> = []
    @State private var scrubber = ScrubberState()
    @State private var posterSheet: MediaItem?
    @State private var pane = LibraryPane()
    @State private var onScreen = LibraryOnScreen()
    @State private var entrance = LibraryEntrance()
    @State private var gridFold = LibraryGridFold()
    /// The Coming up row's lead card art: the ground follows the first card.
    @State private var comingUpArt: URL?

    private var compact: Bool { density == "compact" }
    private var alphaMode: Bool { sort == .title && !group && !compact }
    private var showsRail: Bool { alphaMode && derived.titleCount > 0 }
    /// Not on a Spread's left page: its trailing edge is the fold gutter.
    private var showsScrubber: Bool { showsRail && !(spread.isActive && !spread.spans) }
    private var query: String { model.searchText.trimmingCharacters(in: .whitespaces) }
    /// The fold through the grid matters in book pose only: flat open is one
    /// seamless display (owner, 2026-11-05).
    private var fold: ClosedRange<CGFloat>? { bookPose ? gridFold.fold : nil }
    /// The mock's side gutter: 20 on the phone and folded Duo, 24 open.
    private var gutter: CGFloat { pane.width >= 700 ? 24 : 20 }
    /// The home (heroes and shelf) shows above the grid.
    private var showsHome: Bool { !compact && query.isEmpty }

    /// Flat open beside an open title (slice S5): the list pane takes the
    /// title's palette in the deeper list-pane wash, with no art of its own,
    /// so the display reads as one page. Book pose keeps the Library's own.
    private var besideArt: URL? {
        guard duoOpen, !bookPose, let id = model.presentedItem?.id,
              let item = model.library.first(where: { $0.id == id }) else { return nil }
        return PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl)
    }

    /// The lead card's art while the Coming up row shows (V2LibraryPageTop's rule).
    private var homeArt: URL? {
        showsHome && !home.heroes.isEmpty ? comingUpArt : nil
    }

    private var filters: V2LibraryFilters {
        V2LibraryFilters(kind: $kindRaw, tier: $tier, status: $status, sort: $sort,
                         recency: $recency, group: $group, density: $density, unmonitored: $unmonitoredOnly)
    }

    /// Room kept clear at the grid's trailing side for the A–Z thumb (34
    /// wide, its trailing edge 16 past the content edge, so 18 of it would
    /// sit over the last column), plus a 6pt breath before it.
    private var scrubberRoom: CGFloat { showsScrubber ? 24 : 0 }

    private var columns: Int {
        if spread.spans { return PosterTracks.count(base: 3, spans: true) }
        if fold != nil { return V2LibraryColumns.count(for: gridFold.width) }
        return V2LibraryColumns.count(for: pane.width - 2 * gutter - scrubberRoom)
    }

    private var gridTracks: [FoldColumns.Track]? {
        PosterTracks.tracks(count: derived.columns, width: Double(gridFold.width),
                            fold: fold.map { Double($0.lowerBound)...Double($0.upperBound) },
                            spans: spread.spans, spacing: V2LibraryGrid.spacing)
    }

    /// The grid's poster width and gap, for the home's shelf to match (nil
    /// before the grid is measured; the shelf then keeps its own sizes).
    private var gridPoster: (width: CGFloat, gap: CGFloat)? {
        if let first = gridTracks?.first { return (CGFloat(first.width), CGFloat(V2LibraryGrid.spacing)) }
        let width = gridFold.width
        guard let cell = V2LibraryGrid.cellWidth(width: width, columns: derived.columns, sizeClass: sizeClass)
        else { return nil }
        return (cell, V2LibraryGrid.columnGap(width: width, sizeClass: sizeClass))
    }

    private var inputs: LibraryInputs {
        LibraryInputs(version: model.libraryVersion, kind: kindRaw, tier: tier, status: status, sort: sort,
                      recency: recency, group: group, query: query, compact: compact, columns: columns,
                      compactSort: compactSort, letterHeaders: false)
    }

    var body: some View {
        let _ = PerfCount.hit("V2LibraryView.body")
        let _ = PerfCount.mark("library.body")
        ScrollViewReader { proxy in
            scroll(proxy)
                .overlay {
                    if showsScrubber {
                        ScrollScrubber(state: scrubber, letters: derived.alpha.letters) { jump(toLetter: $0, proxy) }
                    }
                }
                .onChange(of: derived.columns) {
                    if let row = onScreen.anchorRow(in: derived) { jump(to: row, proxy) }
                }
                .onChange(of: model.duoGestures.swipedTo) { _, id in
                    guard let id, let row = derived.rowId(holding: id), !onScreen.rowIds.contains(row) else { return }
                    withAnimation(motion ? .smooth : nil) { proxy.scrollTo(row, anchor: .center) }
                }
                .onChange(of: model.scrollToTopTick) {
                    withAnimation(motion ? .smooth : nil) { proxy.scrollTo("library-top", anchor: .top) }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // A title setting up floats low, over the downloads bar's row, never
        // over the page's header, kind control or the list's toolbar (build 805).
        .overlay(alignment: .bottom) {
            if !model.requestScoped { SetupProgressPill(barHeight: 0).padding(.bottom, 76) }
        }
        // The kit's ambient art, not W1's: full strength under the home,
        // browse-lib.js's shorter, softer layer over the grid or list alone.
        .v2PageGround(art: besideArt ?? homeArt ?? home.groundArt, recipe: besideArt == nil ? .page : .listPane,
                      showsArt: besideArt == nil, artHeight: showsHome ? 760 : 520,
                      artOpacity: showsHome ? .ambient : .libraryList)
        .modifier(V2LibrarySearch())
        .modifier(V2LibraryToolbar(derived: derived, filters: filters))
        // Wide, the page draws the title beside its counts and kind control.
        .shellPage(V2LibraryPageHeader.titleInPage(paneWidth: pane.width) ? "" : "Library",
                   accountInPageWhenFolded: true)
        .spreadSpansBothPages(.library, !compact)
        .toolbarVisibility(model.selectMode ? .hidden : .automatic, for: .tabBar)
        .librarySelectBar(active: model.selectMode, visibleIds: derived.visibleIds)
        .animation(motion ? .snappy(duration: 0.3) : nil, value: model.selectMode)
        .environment(\.openPosterSheet, OpenPosterSheet { posterSheet = $0 })
        .sheet(item: $posterSheet) { item in LibraryPosterSheet(item: item) }
        .task {
            await model.loadLibraryIfNeeded()
        }
        .onQueueChange(model, initial: true) { queue in
            let next = Set(queue.filter { QueueProgress($0).held }.map(\.mediaItemId))
            if next != held { held = next }
        }
        .onChange(of: derived.visibleIds, initial: true) { _, ids in model.duoGestures.libraryOrder = ids }
        .onAppear {
            let gestures = model.duoGestures
            scrubber.onVisibility = { [weak gestures] shown in gestures?.edgeBusy = shown }
        }
        .onChange(of: inputs, initial: true) { rederive() }
        .onChange(of: unmonitoredOnly) { rederive() }
        .modifier(V2LibraryFilterWriteThrough(kind: kindRaw, tier: tier, status: status, sort: sort,
                                              recency: recency, group: group, unmonitored: unmonitoredOnly))
        .onChange(of: held) { rebuildHome() }
    }

    // MARK: Scroll

    private func scroll(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                V2LibraryPageTop(derived: derived, home: home, held: held, filters: filters, paneWidth: pane.width,
                                 gridPoster: gridPoster, gutter: gutter, showsHome: showsHome, shelf: $shelf,
                                 comingUpArt: $comingUpArt) {
                    withAnimation(motion ? .smooth : nil) { proxy.scrollTo("library-grid", anchor: .top) }
                }
                // The thumb hangs off the full content edge; the grid
                // itself stops short of it (`scrubberRoom`).
                Color.clear.frame(height: 1)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        scrubber.setGridTop(frame.minY)
                        scrubber.setGridTrailing(frame.maxX)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0)
                        .onGeometryChange(for: LibraryGridFold.self) { [bookPose] proxy in
                            LibraryGridFold.measured(proxy, bookPose: bookPose)
                        } action: { gridFold = $0 }
                    V2LibraryRows(derived: derived, tracks: gridTracks, width: gridFold.width, entrance: entrance,
                                  compactSort: $compactSort, filters: filters, query: query)
                }
                .padding(.trailing, scrubberRoom)
            }
            // A column change re-flows thousands of rows: never animated.
            .transaction(value: columns) { $0.animation = nil }
            .padding(.horizontal, gutter)
            .padding(.top, 8)
            .padding(.bottom, Theme.pageBottom)
        }
        .scrollDismissesKeyboard(.immediately)
        .onGeometryChange(for: LibraryPane.self) { LibraryPane(width: $0.size.width) } action: {
            PerfCount.hit("V2Library.pane.\(Int($0.width))")
            pane = $0
        }
        .refreshable { await model.loadLibrary() }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { old, new in
            model.updateChrome(old: old, new: new)
        }
        .onScrollGeometryChange(for: ScrubberState.Metrics.self) { geo in
            ScrubberState.Metrics(geo)
        } action: { _, metrics in
            if showsScrubber { scrubber.scrolled(metrics) }
        }
        .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.5) { ids in
            onScreen.rowIds = ids
            guard showsRail else { return }
            scrubber.activeLetter = derived.alpha.activeLetter(visible: ids)
        }
    }

    /// The grid and home from the library, narrowed first to the titles
    /// switched off when Show › Not monitored is on (v1's inputs untouched).
    private func rederive() {
        let key = V2LibraryDeriveKey(inputs, unmonitoredOnly: unmonitoredOnly)
        defer { derivedKey = key }
        // Only the columns changed (a title opening beside the list): new rows, nothing else.
        if key == derivedKey, let next = PerfCount.time("V2Library.rechunk", {
            derived.rechunked(inputs, library: model.library)
        }) {
            derived = next
            return
        }
        let source = unmonitoredOnly ? model.library.filter { $0.monitored == false } : model.library
        derived = PerfCount.time("V2Library.derive") { inputs.derive(from: source) }
        PerfCount.time("V2Library.rebuildHome") { rebuildHome() }
        startEntrance()
    }

    /// The home's heroes, shelves and attention titles, from the same set.
    private func rebuildHome() {
        let ids = Set(derived.visibleIds)
        let visible = model.library.filter { ids.contains($0.id) }
        home = V2LibraryHome(visible: visible, recent: derived.recent, held: held)
    }

    /// A new kind, tier, filter or sort plays the grid's entrance (v1's rule).
    private func startEntrance() {
        let key = "\(kindRaw)|\(tier)|\(status)|\(unmonitoredOnly)|\(sort)|\(recency)|\(group)|\(compact)|\(derived.rows.isEmpty)"
        guard entrance.update(key: key, rows: derived.rows) else { return }
        let generation = entrance.generation
        Task {
            try? await Task.sleep(for: LibraryEntrance.window)
            entrance.end(generation)
        }
    }

    private func jump(toLetter letter: String, _ proxy: ScrollViewProxy) {
        if let row = derived.alpha.letterRow[letter] { jump(to: row, proxy) }
    }

    /// Always instant (an animated jump per scrub letter queued up scrolls).
    private func jump(to row: String, _ proxy: ScrollViewProxy) {
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { proxy.scrollTo(row, anchor: .top) }
    }
}
