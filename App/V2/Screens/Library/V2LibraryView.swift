import SwiftUI
import FusionhaKit

/// v2's All titles (slice S4; mocks browse-lib.js, F1 of filters-alt.js, on
/// the S3 ground and W1 cards), pushed from Home (`V2HomeView`, owner-approved
/// 2026-11-06; it was the Library tab's root). One scroll: the header
/// (`V2LibraryPageTop`: counts, kind control, filter chips, sort) then the
/// A–Z poster grid with the scroll thumb, the status-grouped grid, a plain
/// grid for other sorts, or the compact list. The ground comes from the
/// newest title's art. `entry` says how Home opened it (a kind, Needs you,
/// Recently added); it is applied to the window's filters once.
///
/// It reuses v1's store and logic: the model's library, `LibraryInputs`
/// (filtering, counting, rows), the filters (per window, seeded from v1's keys), the
/// scrubber, the poster sheet and the select bar. A tap opens v2's title
/// page (`V2TitleView`). Phone and the folded Duo: three posters a row; flat open
/// the grid simply widens across the seamless display; book pose keeps the
/// fold in a gutter.
struct V2LibraryView: View {
    /// Read once, never written back: writing Home's state from inside
    /// the push that presents this page hung SwiftUI (CI, Home builds).
    let entry: V2AllTitlesEntry?
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.spread) private var spread
    @Environment(\.bookPose) private var bookPose
    @Environment(\.duoOpen) private var duoOpen
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
    @SceneStorage("v2.library.network") private var network = V2LibraryFilterSeed.network
    @State private var compactSort = CompactSort()
    @State private var derived = LibraryDerived()
    /// What `derived` was built from, but its columns (`V2LibraryDeriveKey`).
    @State private var derivedKey: V2LibraryDeriveKey?
    @State private var scrubber = ScrubberState()
    @State private var posterSheet: MediaItem?
    @State private var pane = LibraryPane()
    @State private var onScreen = LibraryOnScreen()
    @State private var entrance = LibraryEntrance()
    @State private var gridFold = LibraryGridFold()

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

    /// Flat open beside an open title (slice S5): the list pane takes the
    /// title's palette in the deeper list-pane wash, with no art of its own,
    /// so the display reads as one page. Book pose keeps the Library's own.
    private var besideArt: URL? {
        guard duoOpen, !bookPose, let id = model.presentedItem?.id,
              let item = model.library.first(where: { $0.id == id }) else { return nil }
        return PageArtSource.url(backdrop: item.backdropUrl, poster: item.posterUrl)
    }

    /// The newest title's art, for the ground.
    private var groundArt: URL? {
        guard let first = derived.recent.first else { return nil }
        return PageArtSource.url(backdrop: first.backdropUrl, poster: first.posterUrl)
    }

    private var filters: V2LibraryFilters {
        V2LibraryFilters(kind: $kindRaw, tier: $tier, status: $status, sort: $sort,
                         recency: $recency, group: $group, density: $density, unmonitored: $unmonitoredOnly,
                         network: $network)
    }

    private var columns: Int {
        if spread.spans { return PosterTracks.count(base: 3, spans: true) }
        if fold != nil { return V2LibraryColumns.count(for: gridFold.width) }
        return V2LibraryColumns.count(for: pane.width - 2 * gutter)
    }

    private var gridTracks: [FoldColumns.Track]? {
        PosterTracks.tracks(count: derived.columns, width: Double(gridFold.width),
                            fold: fold.map { Double($0.lowerBound)...Double($0.upperBound) },
                            spans: spread.spans, spacing: V2LibraryGrid.spacing)
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
        // The kit's ambient art in browse-lib.js's shorter, softer layer.
        .v2PageGround(art: besideArt ?? groundArt, recipe: besideArt == nil ? .page : .listPane,
                      showsArt: besideArt == nil, artHeight: 520, artOpacity: .libraryList)
        .modifier(V2LibrarySearch())
        .modifier(V2LibraryToolbar(derived: derived, filters: filters))
        // Wide, the page draws the title beside its counts and kind control.
        .shellPage(V2LibraryPageHeader.titleInPage(paneWidth: pane.width) ? "" : "All titles",
                   accountInPageWhenFolded: true)
        .toolbarVisibility(model.selectMode ? .hidden : .automatic, for: .tabBar)
        .librarySelectBar(active: model.selectMode, visibleIds: derived.visibleIds)
        .animation(motion ? .snappy(duration: 0.3) : nil, value: model.selectMode)
        .environment(\.openPosterSheet, OpenPosterSheet { posterSheet = $0 })
        .sheet(item: $posterSheet) { item in LibraryPosterSheet(item: item) }
        .task {
            await model.loadLibraryIfNeeded()
        }
        .onChange(of: entry, initial: true) { _, how in
            guard let how else { return }
            apply(how)
        }
        .onChange(of: derived.visibleIds, initial: true) { _, ids in model.duoGestures.libraryOrder = ids }
        .onDisappear { model.allTitlesOnScreen = false }
        .onAppear {
            model.allTitlesOnScreen = true
            // The route that brought us here is done. Cleared here, not by
            // Home: Home's task is cancelled the moment this covers it, so
            // the flag stayed set and every Back re-pushed All titles (IMG_7891).
            model.pendingAllTitles = false
            let gestures = model.duoGestures
            scrubber.onVisibility = { [weak gestures] shown in gestures?.edgeBusy = shown }
        }
        .onChange(of: inputs, initial: true) { rederive() }
        .onChange(of: unmonitoredOnly) { rederive() }
        .onChange(of: network) { rederive() }
        .modifier(V2LibraryFilterWriteThrough(kind: kindRaw, tier: tier, status: status, sort: sort,
                                              recency: recency, group: group, unmonitored: unmonitoredOnly,
                                              network: network))
    }

    // MARK: Scroll

    private func scroll(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                V2LibraryPageTop(derived: derived, filters: filters, paneWidth: pane.width)
                // The grid runs to the page gutter; the A–Z thumb floats over
                // its trailing edge only while scrolling (Photos' scroller), so
                // no width is kept for it (owner, build 854).
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

    /// The grid from the library, narrowed first to the titles
    /// switched off when Show › Not monitored is on and to the Service
    /// chip's network (v1's inputs untouched).
    private func rederive() {
        let key = V2LibraryDeriveKey(inputs, unmonitoredOnly: unmonitoredOnly, network: network)
        defer { derivedKey = key }
        // Only the columns changed (a title opening beside the list): new rows, nothing else.
        if key == derivedKey, let next = PerfCount.time("V2Library.rechunk", {
            derived.rechunked(inputs, library: model.library)
        }) {
            derived = next
            return
        }
        let mine = unmonitoredOnly ? model.library.filter { $0.monitored == false } : model.library
        let source = V2LibraryServices.narrow(mine, to: network)
        derived = PerfCount.time("V2Library.derive") { inputs.derive(from: source) }
        startEntrance()
    }

    /// How Home opened All titles, onto the window's filters.
    private func apply(_ how: V2AllTitlesEntry) {
        switch how {
        case .asLeft:
            return
        case .everything:
            kindRaw = "all"
        case .kind(let kind):
            kindRaw = kind.rawValue
        case .needsYou:
            status = .attention
        case .recent(let lastMonth):
            status = .all
            recency = lastMonth ? .added : .all
            sort = .addedDesc
        }
    }

    /// A new kind, tier, filter or sort plays the grid's entrance (v1's rule).
    private func startEntrance() {
        let key = "\(kindRaw)|\(tier)|\(status)|\(unmonitoredOnly)|\(network)|\(sort)|\(recency)|\(group)|\(compact)|\(derived.rows.isEmpty)"
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
