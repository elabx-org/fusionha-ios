import SwiftUI
import FusionhaKit

// MARK: - Library page

/// The web's Library page on mobile (routes/Library.tsx): header with live
/// counts, the kinds card, the toolbar (select · tier · attention · Filters ·
/// density) and the A–Z poster grid with its scroll thumb, the status-grouped
/// grid, a plain grid for other sorts, or the compact table.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @Environment(\.railConsolidate) private var consolidate
    @AppStorage("library.kind") private var kindRaw = "all"
    @AppStorage("fusionha.library.density") private var density = "grid"
    @State private var tier: LibraryTier = .all
    @State private var status: LibraryStatus = .all
    @State private var sort: LibrarySort = .title
    @State private var recency: LibraryRecency = .all
    @State private var group = false
    @State private var showingFilters = false
    @State private var derived = LibraryDerived()
    @State private var scrubber = ScrubberState()
    @State private var posterSheet: MediaItem?
    /// Cards per row for the grid's current width.
    @State private var columns = 3
    /// The grid's width (the page less its side margins).
    @State private var gridWidth: CGFloat = 0
    /// The A–Z grid's window: known row heights, only the visible rows rendered.
    @State private var window = LibraryGridWindow()
    /// The grid rows on screen, kept (unobserved) so a fold/unfold that changes
    /// the column count can scroll back to the same titles.
    @State private var onScreen = LibraryOnScreen()

    private var kind: LibraryKind? { LibraryKind(rawValue: kindRaw) }
    private var compact: Bool { density == "compact" }

    private var query: String {
        model.searchText.trimmingCharacters(in: .whitespaces)
    }

    private struct Inputs: Equatable {
        var version: Int, kind: String, tier: LibraryTier, status: LibraryStatus
        var sort: LibrarySort, recency: LibraryRecency, group: Bool, query: String, compact: Bool
        var columns: Int, gridWidth: CGFloat, consolidate: Bool
    }

    private var inputs: Inputs {
        Inputs(version: model.libraryVersion, kind: kindRaw, tier: tier, status: status, sort: sort,
               recency: recency, group: group, query: query, compact: compact, columns: columns,
               gridWidth: gridWidth, consolidate: consolidate)
    }

    var body: some View {
        Screen(showsAdd: true, filtersInPlace: true) {
            ScrollViewReader { proxy in
                scroll(proxy)
                    .overlay {
                        if showsRail {
                            ScrollScrubber(state: scrubber, letters: derived.alpha.letters) { letter in
                                if let row = derived.alpha.letterRow[letter] { jump(to: row, proxy) }
                            }
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
        .toolbarVisibility(model.selectMode ? .hidden : .automatic, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.selectMode {
                BulkActionBar(visibleIds: derived.visibleIds)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(motion ? .snappy(duration: 0.3) : nil, value: model.selectMode)
        .environment(\.openPosterSheet, { posterSheet = $0 })
        .sheet(item: $posterSheet) { item in
            LibraryPosterSheet(item: item)
        }
        .sheet(isPresented: $showingFilters) {
            LibraryFiltersSheet(recency: $recency, group: $group, sort: $sort)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .task {
            if !model.libraryLoaded { await model.loadLibrary() }
            #if DEBUG
            // CI screenshots: `FUSIONHA_SCREENSHOT_POSTER_SHEET=<item id>` long-presses that poster.
            if let id = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_POSTER_SHEET"].flatMap(Int.init) {
                try? await Task.sleep(for: .seconds(1))
                posterSheet = model.library.first { $0.id == id }
            }
            #endif
        }
        .onChange(of: inputs, initial: true) { rebuild() }
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

    private var showsRail: Bool { sort == .title && !group && !compact && derived.titleCount > 0 }

    private var subtitle: String {
        let t = derived.titleCount, e = derived.editionCount
        return "\(t) \(t == 1 ? "title" : "titles") · \(e) \(e == 1 ? "version" : "versions")"
    }

    // MARK: Derivation

    private func rebuild() {
        let needle = query.lowercased()
        let now = Date()
        let recentWindow: TimeInterval = 30 * 86_400
        func recent(_ iso: String?) -> Bool {
            guard let date = Format.timestamp(iso) ?? Format.day(iso) else { return false }
            return date <= now && now.timeIntervalSince(date) <= recentWindow
        }
        // Tier + recency + search, before the kind narrowing (the kinds card counts this set).
        let kindBase = model.library.filter { item in
            guard tier.matches(item) else { return false }
            if recency == .added && !recent(item.addedAt) { return false }
            if recency == .released && !recent(item.releaseDate) { return false }
            return needle.isEmpty || item.title.lowercased().contains(needle)
        }
        var next = LibraryDerived()
        for item in kindBase {
            next.kindTitles[item.libraryKind, default: 0] += 1
            next.kindEditions[item.libraryKind, default: 0] += item.editions.count
        }
        let base = Self.sorted(kind.map { k in kindBase.filter { $0.libraryKind == k } } ?? kindBase, by: sort)
        next.pulse = PulseStats(base)
        next.attentionCount = base.filter { $0.hasAttention == true }.count
        let visible = status == .all ? base : base.filter(status.matches)
        next.visibleIds = visible.map(\.id)
        next.titleCount = visible.count
        next.editionCount = visible.reduce(0) { $0 + $1.editions.count }
        next.columns = columns
        if compact {
            next.rows = LibraryRowModel.table(visible)
        } else if group {
            next.rows = LibraryRowModel.grouped(visible, columns: columns)
        } else if sort == .title {
            (next.rows, next.alpha) = LibraryRowModel.alpha(visible, columns: columns)
            next.windowed = true
            configureWindow(next.rows)
        } else {
            next.rows = LibraryRowModel.plain(visible, columns: columns)
        }
        derived = next
    }

    /// Hands the A–Z rows and their rail counts to the window.
    private func configureWindow(_ rows: [LibraryRowModel]) {
        let entries = rows.compactMap { row -> LibraryGridWindow.Entry? in
            guard case .items(let items) = row else { return nil }
            return .init(id: row.id, slots: LibraryGridRow.slots(items, consolidate: consolidate))
        }
        let cols = CGFloat(max(columns, 1))
        window.configure(entries: entries, cardWidth: max(0, (gridWidth - 6 * (cols - 1)) / cols))
    }

    // MARK: Scroll

    private func scroll(_ proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Outside the lazy rows, so the header's entrance plays once and
                // never replays when a jump back to the top re-realizes it.
                pageTop
                Color.clear.frame(height: 1)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { y in
                        scrubber.setGridTop(y)
                    }
                content
            }
            // Plex-app rhythm on phones: 16pt side margins.
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.immediately)
        .onGeometryChange(for: CGFloat.self) { $0.size.width - 32 } action: { width in
            gridWidth = width
            columns = PosterColumns.count(for: width)
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
            if showsRail { scrubber.scrolled(metrics) }
        }
        .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.5) { ids in
            onScreen.rowIds = ids
            if showsRail { scrubber.activeLetter = derived.alpha.activeLetter(visible: ids) }
        }
        // Poster loads wait while the scrubber keeps jumping; frames and titles never do.
        .environment(\.artLoadGate, scrubber.artGate)
    }

    private var pageTop: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("library-top")
            PageHeader(title: "Library", subtitle: subtitle)
                .padding(.bottom, 20)
                .reveal(0)
            LibraryPulseCard(derived: derived, selection: $kindRaw, status: $status)
                .padding(.bottom, 20)
                .reveal(1)
            LibraryToolbar(tier: $tier, status: $status, density: $density,
                           attentionCount: derived.attentionCount, filterBadge: filterBadge) {
                showingFilters = true
            }
            .reveal(2)
        }
    }

    private var filterBadge: Int {
        (recency != .all ? 1 : 0) + (group ? 1 : 0) + (sort != .title ? 1 : 0)
    }

    /// An instant jump (a scrub letter, a fold re-anchor). The windowed grid
    /// renders the target rows first and scrolls on the next turn, so the jump
    /// lands on rows that already exist: card frames, titles and version chips
    /// at once, posters filling in behind them.
    private func jump(to row: String, _ proxy: ScrollViewProxy) {
        // Always instant: an animated jump per letter while scrubbing queued up
        // scrolls and made the app unresponsive (F-A).
        func go() {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { proxy.scrollTo(row, anchor: .top) }
        }
        if derived.windowed, window.pin(row) {
            Task { @MainActor in go() }
        } else {
            go()
        }
    }

    // MARK: Body states

    @ViewBuilder
    private var content: some View {
        if model.library.isEmpty {
            if !model.libraryLoaded {
                LibraryGridSkeleton()
            } else if model.libraryError != nil {
                EmptyBox(message: "Your library could not be loaded. Check the backend and try again.")
            } else {
                EmptyBox(message: "Your library is empty. Use Add to search TMDB and start tracking a title in one or more versions (HD, 4K).")
            }
        } else if derived.rows.isEmpty || derived.titleCount == 0 {
            EmptyBox(message: "No titles match \(query.isEmpty ? "these filters" : "your search"). Try clearing a filter or the search box.")
        } else {
            if derived.windowed {
                LibraryWindowedGrid(rows: derived.rows, columns: derived.columns, window: window)
            } else {
                lazyRows
            }
        }
    }

    private var lazyRows: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(derived.rows) { row in
                switch row {
                case .section(let status, let count):
                    StatusSectionHeader(status: status, count: count)
                case .items(let items):
                    LibraryGridRow(items: items, columns: derived.columns)
                case .tableHeader:
                    LibraryTableHeader()
                case .tableRow(let item, let last):
                    LibraryTableRow(item: item, last: last)
                }
            }
        }
        .scrollTargetLayout()
    }
}
