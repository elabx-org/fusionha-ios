import SwiftUI
import FusionhaKit

// MARK: - Library page

/// The web's Library page (routes/Library.tsx), content first (owner-approved
/// layout A, 2026-10-23). On a phone, the closed Duo and across the open
/// Duo's spread: the one-line counts, the kind control, quality · Filters ·
/// grid ⇄ list, the Recently added shelf, then "All titles" as the A–Z poster
/// grid with its scroll thumb. Past 720
/// of its own width (ruling L17, `PaneWidthRule`): the inline pulse ribbon,
/// the desktop toolbar, letter headers and the A–Z rail. Either way also the
/// status-grouped grid, a plain grid for other sorts, or the compact table.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    /// iPhone Duo Spread: with nothing picked the grid spans both pages.
    @Environment(\.spread) private var spread
    // Every filter persists, so the Library reopens exactly as it was left
    // (the web keeps them all in the URL); only the search box is transient.
    @AppStorage("library.kind") private var kindRaw = "all"
    @AppStorage("fusionha.library.density") private var density = "grid"
    @AppStorage("library.tier") private var tier: LibraryTier = .all
    @AppStorage("library.status") private var status: LibraryStatus = .all
    @AppStorage("library.sort") private var sort: LibrarySort = .title
    @AppStorage("library.recency") private var recency: LibraryRecency = .all
    @AppStorage("library.group") private var group = false
    /// The compact table's column sort (local to the table, as on the web).
    @State private var compactSort = CompactSort()
    @State private var showingFilters = false
    /// The library filter is open under the counts (Search in the bar).
    @State private var searching = false
    @State private var derived = LibraryDerived()
    @State private var scrubber = ScrubberState()
    @State private var rail = AlphaRailState()
    @State private var posterSheet: MediaItem?
    /// The scroll's own width.
    @State private var pane = LibraryPane()
    /// The grid rows on screen, kept (unobserved) so a fold/unfold that changes
    /// the column count can scroll back to the same titles.
    @State private var onScreen = LibraryOnScreen()
    /// The grid's own width and the fold through it (`LibraryGridFold`).
    @State private var gridFold = LibraryGridFold()

    private var compact: Bool { density == "compact" }
    /// The web's desktop Library: past 720 of the Library's own width. A
    /// Spread span keeps the phone pieces, one page each.
    private var wide: Bool { !spread.spans && PaneWidthRule.isWide(Double(pane.width)) }
    /// The A–Z index applies: title sort, ungrouped, posters.
    private var alphaMode: Bool { sort == .title && !group && !compact }
    private var showsRail: Bool { alphaMode && derived.titleCount > 0 }
    /// The rail column beside the grid (wide only).
    private var railWidth: CGFloat { wide && alphaMode ? LibraryAlphaRail.width : 0 }

    private var query: String {
        model.searchText.trimmingCharacters(in: .whitespaces)
    }

    /// Cards per row for the grid's width (16pt margins, the rail beside it).
    /// A Spread span: three a side. A fold through the grid (Web layout, flat
    /// or Book): the usual count, its tracks split around the real fold (never
    /// an assumed centred fold: the Duo's is right of the content's middle).
    private var columns: Int {
        if spread.spans { return PosterTracks.count(base: 3, spans: true) }
        if gridFold.fold != nil { return PosterColumns.count(for: gridFold.width) }
        return PosterColumns.count(for: pane.width - 32 - railWidth)
    }

    /// The poster tracks that keep the fold in a gutter (`nil`: no fold).
    private var gridTracks: [FoldColumns.Track]? {
        PosterTracks.tracks(count: derived.columns, width: Double(gridFold.width),
                            fold: gridFold.fold.map { Double($0.lowerBound)...Double($0.upperBound) },
                            spans: spread.spans, spacing: LibraryGridRow.spacing)
    }

    /// The compact table's rows split at the fold (Web layout); `nil` without one.
    private var tableSplit: FoldColumns.Panes? {
        LibraryFold.table(width: Double(gridFold.width),
                          fold: gridFold.fold.map { Double($0.lowerBound)...Double($0.upperBound) })
    }

    private var inputs: LibraryInputs {
        LibraryInputs(version: model.libraryVersion, kind: kindRaw, tier: tier, status: status, sort: sort,
                      recency: recency, group: group, query: query, compact: compact, columns: columns,
                      compactSort: compactSort, letterHeaders: wide)
    }

    var body: some View {
        Screen(showsAdd: true, filtersInPlace: true) {
            ScrollViewReader { proxy in
                scroll(proxy)
                    .overlay {
                        // Not on a Spread's left page: there its trailing edge is the
                        // fold gutter and the thumb would cover the last column.
                        if showsRail && !wide && !(spread.isActive && !spread.spans) {
                            ScrollScrubber(state: scrubber, letters: derived.alpha.letters) { jump(toLetter: $0, proxy) }
                        }
                    }
                    .onChange(of: derived.columns) {
                        // Folding or unfolding re-flows the grid: keep the same titles on screen.
                        if let row = onScreen.anchorRow(in: derived) { jump(to: row, proxy) }
                    }
                    .onChange(of: model.scrollToTopTick) {
                        withAnimation(motion ? .smooth : nil) { proxy.scrollTo("library-top", anchor: .top) }
                    }
            }
        }
        .shellPage("Library")
        .spreadSpansBothPages(.library, !compact)
        .toolbarVisibility(model.selectMode ? .hidden : .automatic, for: .tabBar)
        .librarySelectBar(active: model.selectMode, visibleIds: derived.visibleIds)
        .animation(motion ? .snappy(duration: 0.3) : nil, value: model.selectMode)
        .animation(motion ? .smooth(duration: 0.3) : nil, value: wide)
        .environment(\.openPosterSheet, { posterSheet = $0 })
        .sheet(item: $posterSheet) { item in
            LibraryPosterSheet(item: item)
        }
        .task {
            if !model.libraryLoaded {
                await model.restoreLibrary()
                await model.loadLibrary()
            }
            #if DEBUG
            // CI screenshots: `FUSIONHA_SCREENSHOT_POSTER_SHEET=<item id>` long-presses that poster.
            if let id = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_POSTER_SHEET"].flatMap(Int.init) {
                try? await Task.sleep(for: .seconds(1))
                posterSheet = model.library.first { $0.id == id }
            }
            #endif
        }
        .onChange(of: inputs, initial: true) { derived = inputs.derive(from: model.library) }
    }

    private func updateChrome(old: CGFloat, new: CGFloat) {
        let delta = new - old
        if new <= 90 {
            if model.chromeHidden { model.chromeHidden = false }
        } else if delta > 4 {
            if !model.chromeHidden { model.chromeHidden = true }
        } else if delta < -4 {
            if model.chromeHidden { model.chromeHidden = false }
        }
    }

    // MARK: Scroll

    private func scroll(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Outside the lazy rows, so the header's entrance plays once and
                // never replays when a jump back to the top re-realizes it.
                LibraryPageTop(derived: derived, wide: wide, compact: compact, filterBadge: filterBadge,
                               paneWidth: pane.width, kind: $kindRaw, density: $density, tier: $tier,
                               status: $status, sort: $sort, recency: $recency, group: $group,
                               searching: $searching, showingFilters: $showingFilters) {
                    withAnimation(motion ? .smooth : nil) { proxy.scrollTo("library-grid", anchor: .top) }
                }
                Color.clear.frame(height: 1)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { y in
                        scrubber.setGridTop(y)
                    }
                    .onGeometryChange(for: LibraryGridFold.self) { LibraryGridFold($0) } action: { gridFold = $0 }
                content
            }
            // Plex-app rhythm on phones: 16pt side margins.
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, Theme.pageBottom)
        }
        .scrollDismissesKeyboard(.immediately)
        .onGeometryChange(for: LibraryPane.self) { LibraryPane(width: $0.size.width) } action: { pane = $0 }
        // The desktop A–Z rail: a column of its own at the trailing edge, so
        // the grid lays out beside it, never under it.
        .safeAreaInset(edge: .trailing, spacing: 0) {
            if wide && showsRail {
                LibraryAlphaRail(present: Set(derived.alpha.letters), state: rail) { jump(toLetter: $0, proxy) }
                    .padding(.vertical, 14)
                    .transition(.opacity)
            }
        }
        .refreshable { await model.loadLibrary() }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { old, new in
            updateChrome(old: old, new: new)
        }
        .onScrollGeometryChange(for: ScrubberState.Metrics.self) { geo in
            ScrubberState.Metrics(geo)
        } action: { _, metrics in
            if showsRail && !wide { scrubber.scrolled(metrics) }
        }
        .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.5) { ids in
            onScreen.rowIds = ids
            guard showsRail else { return }
            let letter = derived.alpha.activeLetter(visible: ids)
            if wide { rail.set(letter) } else { scrubber.activeLetter = letter }
        }
    }

    /// `hasActiveFilters`: anything narrowing the grid, the search box included.
    private var filtersActive: Bool {
        kindRaw != "all" || tier != .all || recency != .all || !query.isEmpty || sort != .title || status != .all
    }

    private var filterBadge: Int {
        (recency != .all ? 1 : 0) + (group ? 1 : 0) + (sort != .title ? 1 : 0)
    }

    private func jump(toLetter letter: String, _ proxy: ScrollViewProxy) {
        if let row = derived.alpha.letterRow[letter] { jump(to: row, proxy) }
    }

    /// An instant jump (a scrub letter, a fold re-anchor). It lands on the
    /// grid's silhouette: every card has a fixed 2:3 poster frame with a dark
    /// placeholder, so frames, titles and version chips paint at once and the
    /// posters fill in behind them.
    private func jump(to row: String, _ proxy: ScrollViewProxy) {
        // Always instant: an animated jump per letter while scrubbing queued up
        // scrolls and made the app unresponsive (F-A).
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { proxy.scrollTo(row, anchor: .top) }
    }

    // MARK: Body states

    @ViewBuilder
    private var content: some View {
        if model.library.isEmpty {
            if !model.libraryLoaded {
                LibraryGridSkeleton(columns: derived.columns, tracks: gridTracks)
            } else if model.libraryError != nil {
                EmptyBox(message: "Your library could not be loaded. Check the backend and try again.")
            } else {
                EmptyBox(message: "Your library is empty. Use Add to search TMDB and start tracking a title in one or more versions (HD, 4K).")
            }
        } else if derived.rows.isEmpty || derived.titleCount == 0 {
            EmptyBox(message: LibraryPhoneCopy.noMatches(filtersActive: filtersActive))
        } else {
            lazyRows
        }
    }

    private var lazyRows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(derived.rows) { row in
                switch row {
                case .section(let status, let count):
                    StatusSectionHeader(status: status, count: count)
                case .letter(let letter, let count):
                    LibraryLetterHeader(letter: letter, count: count)
                case .items(let items):
                    LibraryGridRow(items: items, columns: derived.columns, tracks: gridTracks)
                case .tableHeader:
                    LibraryTableHeader(sort: compactSort, split: tableSplit) { column in
                        withAnimation(motion ? .snappy : nil) { compactSort = compactSort.tapped(column) }
                    }
                case .tableRow(let item, let last):
                    LibraryTableRow(item: item, last: last, split: tableSplit)
                }
            }
        }
        .scrollTargetLayout()
    }
}
