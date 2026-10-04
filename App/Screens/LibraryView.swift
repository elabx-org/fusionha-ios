import SwiftUI
import FusionhaKit

// MARK: - Filters (routes/library-filters.ts)

enum LibraryTier: Hashable {
    case all, hd, uhd

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all: return true
        case .hd: return item.editions.contains { $0.tier == .hd }
        case .uhd: return item.editions.contains { $0.tier == .uhd }
        }
    }
}

/// The Library-Pulse stat filter (`status=`).
enum LibraryStatus: String, CaseIterable, Hashable {
    case all, downloading, missing, upcoming, complete, attention

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all: return true
        case .attention: return item.hasAttention == true
        case .downloading: return item.cardStatus == .downloading
        case .missing: return item.cardStatus == .missing
        case .upcoming: return item.cardStatus == .upcoming
        case .complete: return item.cardStatus == .complete
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case title
    case yearDesc = "year-desc"
    case yearAsc = "year-asc"
    case addedDesc = "added-desc"
    case releasedDesc = "released-desc"
    var id: Self { self }

    var label: String {
        switch self {
        case .title: return "Title A–Z"
        case .yearDesc: return "Year · Newest"
        case .yearAsc: return "Year · Oldest"
        case .addedDesc: return "Recently added"
        case .releasedDesc: return "Recently released"
        }
    }
}

enum LibraryRecency: String, CaseIterable, Hashable {
    case all, added, released
}

/// Everything the page renders, derived once per input change (never per
/// render): with thousands of titles, re-filtering on every frame of an A–Z
/// rail drag froze the app.
struct LibraryDerived {
    var rows: [LibraryRowModel] = []
    var letters: Set<String> = []
    var visibleIds: [Int] = []
    var titleCount = 0
    var editionCount = 0
    var kindTitles: [LibraryKind: Int] = [:]
    var kindEditions: [LibraryKind: Int] = [:]
    var attentionCount = 0
    var pulse = PulseStats()
}

/// `computePulse` over the filtered set.
struct PulseStats {
    var titles = 0
    var totalEditions = 0
    var counts: [CardStatus: Int] = [:]
    var titleCounts: [CardStatus: Int] = [:]
    var fourKTitles = 0
    var onDisk: Double = 0

    init() {}

    init(_ items: [MediaItem]) {
        for item in items {
            for bucket in item.editionBuckets {
                counts[bucket, default: 0] += 1
                totalEditions += 1
            }
            titleCounts[item.cardStatus, default: 0] += 1
            if item.editions.contains(where: { $0.tier == .uhd }) { fourKTitles += 1 }
            onDisk += item.totalSize
        }
        titles = items.count
    }

    var healthPct: Int {
        totalEditions > 0 ? Int((Double(counts[.complete] ?? 0) / Double(totalEditions) * 100).rounded()) : 0
    }
}

// MARK: - Library page

/// The web's Library page on mobile (routes/Library.tsx): header with live
/// counts, the kinds card, the toolbar (select · tier · attention · Filters ·
/// density) and the A–Z poster grid with its letter rail, the status-grouped
/// grid, a plain grid for other sorts, or the compact table.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    @AppStorage("library.kind") private var kindRaw = "all"
    @AppStorage("fusionha.library.density") private var density = "grid"
    @State private var tier: LibraryTier = .all
    @State private var status: LibraryStatus = .all
    @State private var sort: LibrarySort = .title
    @State private var recency: LibraryRecency = .all
    @State private var group = false
    @State private var showingFilters = false
    @State private var derived = LibraryDerived()
    @State private var railMetrics = RailMetrics()

    private var kind: LibraryKind? { LibraryKind(rawValue: kindRaw) }
    private var compact: Bool { density == "compact" }

    private var query: String {
        model.searchText.trimmingCharacters(in: .whitespaces)
    }

    private struct Inputs: Equatable {
        var version: Int, kind: String, tier: LibraryTier, status: LibraryStatus
        var sort: LibrarySort, recency: LibraryRecency, group: Bool, query: String, compact: Bool
    }

    private var inputs: Inputs {
        Inputs(version: model.libraryVersion, kind: kindRaw, tier: tier, status: status, sort: sort,
               recency: recency, group: group, query: query, compact: compact)
    }

    var body: some View {
        Screen(showsAdd: true, filtersInPlace: true) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id("library-top")
                        PageHeader(title: "Library", subtitle: subtitle)
                            .padding(.bottom, 20)
                            .reveal(0)
                        LibraryPulseCard(derived: derived, selection: $kindRaw, status: $status)
                            .padding(.bottom, 20)
                            .reveal(1)
                        toolbar.reveal(2)
                        Color.clear.frame(height: 1)
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { y in
                                railMetrics.stageY = y
                            }
                        content
                    }
                    .padding(.horizontal, Theme.pageGutter)
                    .padding(.trailing, showsRail ? 42 : 0)
                    .padding(.top, 20)
                    .padding(.bottom, 90)
                }
                .scrollDismissesKeyboard(.immediately)
                .refreshable { await model.loadLibrary() }
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { old, new in
                    updateChrome(old: old, new: new)
                }
                .overlay(alignment: .topTrailing) {
                    if showsRail {
                        AlphabetRail(available: derived.letters, metrics: railMetrics) { letter in
                            // No animation: an animated jump per letter while dragging
                            // queued up scrolls and made the app unresponsive.
                            proxy.scrollTo(LibraryRowModel.headerId(letter), anchor: .top)
                        }
                        .padding(.trailing, Theme.pageGutter)
                    }
                }
                .onChange(of: model.scrollToTopTick) {
                    if motion {
                        withAnimation(.smooth) { proxy.scrollTo("library-top", anchor: .top) }
                    } else {
                        proxy.scrollTo("library-top", anchor: .top)
                    }
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
        .sheet(isPresented: $showingFilters) {
            LibraryFiltersSheet(recency: $recency, group: $group, sort: $sort)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.panel)
        }
        .task {
            if !model.libraryLoaded { await model.loadLibrary() }
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
        return "\(t) \(t == 1 ? "title" : "titles") · \(e) \(e == 1 ? "edition" : "editions")"
    }

    // MARK: Derivation

    private func rebuild() {
        let needle = query.lowercased()
        let now = Date()
        let window: TimeInterval = 30 * 86_400
        func recent(_ iso: String?) -> Bool {
            guard let date = Format.timestamp(iso) ?? Format.day(iso) else { return false }
            return date <= now && now.timeIntervalSince(date) <= window
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
        if compact {
            next.rows = LibraryRowModel.table(visible)
        } else if group {
            next.rows = LibraryRowModel.grouped(visible)
        } else {
            next.rows = LibraryRowModel.build(visible, sectioned: sort == .title)
        }
        next.letters = Set(next.rows.compactMap { if case .header(let letter, _, _) = $0 { letter } else { nil } })
        derived = next
    }

    /// `compare` in library-filters.ts: title uses localeCompare; other sorts
    /// put missing keys last and tie-break by title.
    static func sorted(_ items: [MediaItem], by sort: LibrarySort) -> [MediaItem] {
        func byTitle(_ a: MediaItem, _ b: MediaItem) -> Bool {
            a.title.localizedCompare(b.title) == .orderedAscending
        }
        func dateDesc(_ a: MediaItem, _ b: MediaItem, _ ak: String?, _ bk: String?) -> Bool {
            switch (ak, bk) {
            case (nil, nil): return byTitle(a, b)
            case (nil, _): return false
            case (_, nil): return true
            case let (x?, y?): return x != y ? x > y : byTitle(a, b)
            }
        }
        switch sort {
        case .title:
            return items.sorted(by: byTitle)
        case .addedDesc:
            return items.sorted { dateDesc($0, $1, $0.addedAt, $1.addedAt) }
        case .releasedDesc:
            return items.sorted { dateDesc($0, $1, $0.releaseDate, $1.releaseDate) }
        case .yearDesc, .yearAsc:
            return items.sorted { a, b in
                switch (a.year, b.year) {
                case (nil, nil): return byTitle(a, b)
                case (nil, _): return false
                case (_, nil): return true
                case let (x?, y?):
                    if x != y { return sort == .yearDesc ? x > y : x < y }
                    return byTitle(a, b)
                }
            }
        }
    }

    /// The rail's bucket (`letterOf`): the first character, uppercased; anything
    /// outside A–Z is '#'. No article stripping: "The Matrix" files under T.
    static func letter(for title: String) -> String {
        guard let first = title.trimmingCharacters(in: .whitespaces).uppercased().unicodeScalars.first else { return "#" }
        return (65...90).contains(first.value) ? String(first) : "#"
    }

    // MARK: Toolbar (LibraryToolbar mobile branch)

    private var filterBadge: Int {
        (recency != .all ? 1 : 0) + (group ? 1 : 0) + (sort != .title ? 1 : 0)
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryToolbarRow(spacing: 10) {
                Button {
                    if model.selectMode { model.exitSelectMode() } else { model.selectMode = true }
                } label: {
                    Image(systemName: model.selectMode ? "checkmark.square" : "viewfinder")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(model.selectMode ? Theme.i2 : Theme.mut)
                        .frame(width: 38, height: 38)
                        .background(model.selectMode ? Theme.i2.opacity(0.10) : Theme.panel,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(model.selectMode ? Theme.i2 : Theme.line))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(model.selectMode ? "Exit select mode" : "Select titles")

                SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")], selection: $tier)

                if derived.attentionCount > 0 || status == .attention {
                    Button {
                        withAnimation(motion ? .snappy : nil) { status = status == .attention ? .all : .attention }
                    } label: {
                        Text("Needs attention · \(derived.attentionCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.miss)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .background(Theme.miss.opacity(status == .attention ? 0.2 : 0.12),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.miss.opacity(status == .attention ? 0.7 : 0.4)))
                    }
                    .buttonStyle(PressScaleStyle())
                }
            } trailing: {
                Button { showingFilters = true } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.mut)
                        Text("Filters").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt)
                        if filterBadge > 0 {
                            Text("\(filterBadge)")
                                .font(.system(size: 10.5, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .frame(minWidth: 17, minHeight: 17)
                                .background(Theme.fusion, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .panel(Theme.panel, radius: 10)
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.bottom, 20)

            densityToggle
                .padding(.bottom, 20)
        }
    }

    /// Grid / list toggle: 34×30 buttons in a `--panel` track.
    private var densityToggle: some View {
        HStack(spacing: 0) {
            ForEach(["grid", "compact"], id: \.self) { value in
                let active = density == value
                Button {
                    withAnimation(motion ? Motion.indicator : nil) { density = value }
                } label: {
                    Image(systemName: value == "grid" ? "square.grid.2x2" : "list.bullet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(active ? Theme.segActiveText : Theme.mut)
                        .frame(width: 34, height: 30)
                        .background {
                            if active {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Theme.indigo.opacity(0.14))
                                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Theme.indigo.opacity(0.55)))
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value == "grid" ? "Grid view" : "List view")
            }
        }
        .padding(3)
        .panel(Theme.panel, radius: 10)
        .sensoryFeedback(.selection, trigger: density)
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
                EmptyBox(message: "Your library is empty. Use Add to search TMDB and start tracking a title across its quality editions.")
            }
        } else if derived.rows.isEmpty || derived.titleCount == 0 {
            EmptyBox(message: "No titles match \(query.isEmpty ? "these filters" : "your search"). Try clearing a filter or the search box.")
        } else {
            ForEach(derived.rows) { row in
                switch row {
                case .header(let letter, let count, _):
                    LetterHeader(letter: letter, count: count)
                case .section(let status, let count):
                    StatusSectionHeader(status: status, count: count)
                case .items(let items):
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(0..<3, id: \.self) { i in
                            if i < items.count {
                                PosterCard(item: items[i]).frame(maxWidth: .infinity, alignment: .top)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                    .padding(.bottom, 18)
                case .tableHeader:
                    LibraryTableHeader()
                case .tableRow(let item, let last):
                    LibraryTableRow(item: item, last: last)
                }
            }
        }
    }
}

/// Lays out the toolbar's left group with a trailing control pinned right,
/// wrapping the left group like the web's `flex-wrap` row.
private struct LibraryToolbarRow<Leading: View, Trailing: View>: View {
    var spacing: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                leading
                Spacer(minLength: 0)
                trailing
            }
            VStack(alignment: .leading, spacing: spacing) {
                HStack(spacing: spacing) {
                    leading
                }
                HStack {
                    Spacer(minLength: 0)
                    trailing
                }
            }
        }
    }
}

// MARK: - Rows

/// One row of the Library scroll. Rows are flat so the scroll stays fully lazy
/// and the rail can jump to any header.
enum LibraryRowModel: Identifiable {
    case header(String, Int, id: String)
    case section(CardStatus, Int)
    case items([MediaItem])
    case tableHeader
    case tableRow(MediaItem, last: Bool)

    var id: String {
        switch self {
        case .header(_, _, let id): return id
        case .section(let status, _): return "status-\(status.rawValue)"
        case .items(let items): return "row-\(items[0].id)"
        case .tableHeader: return "table-header"
        case .tableRow(let item, _): return "table-\(item.id)"
        }
    }

    static func headerId(_ letter: String) -> String { "letter-\(letter)" }

    private static func chunk(_ group: ArraySlice<MediaItem>, into rows: inout [LibraryRowModel]) {
        var start = group.startIndex
        while start < group.endIndex {
            let end = min(start + 3, group.endIndex)
            rows.append(.items(Array(group[start..<end])))
            start = end
        }
    }

    /// Lettered runs (`buildAlphaSections`) when sorted by title, else a plain grid.
    static func build(_ items: [MediaItem], sectioned: Bool) -> [LibraryRowModel] {
        var rows: [LibraryRowModel] = []
        guard sectioned else {
            chunk(items[...], into: &rows)
            return rows
        }
        var seen: [String: Int] = [:]
        var start = items.startIndex
        while start < items.endIndex {
            let letter = LibraryView.letter(for: items[start].title)
            var end = start + 1
            while end < items.endIndex, LibraryView.letter(for: items[end].title) == letter { end += 1 }
            let n = seen[letter, default: 0]
            seen[letter] = n + 1
            // A letter can reopen (e.g. an accented title sorts among E but files under #);
            // the rail jumps to its first run.
            rows.append(.header(letter, end - start, id: n == 0 ? headerId(letter) : "\(headerId(letter))-\(n)"))
            chunk(items[start..<end], into: &rows)
            start = end
        }
        return rows
    }

    /// Group by status (`groupByStatus`): Downloading, Needs attention, Upcoming, Complete.
    static func grouped(_ items: [MediaItem]) -> [LibraryRowModel] {
        var rows: [LibraryRowModel] = []
        for status in CardStatus.allCases {
            let members = items.filter { $0.cardStatus == status }
            guard !members.isEmpty else { continue }
            rows.append(.section(status, members.count))
            chunk(members[...], into: &rows)
        }
        return rows
    }

    static func table(_ items: [MediaItem]) -> [LibraryRowModel] {
        guard !items.isEmpty else { return [] }
        return [.tableHeader] + items.enumerated().map { .tableRow($0.element, last: $0.offset == items.count - 1) }
    }
}

/// Letter header: 21/800 letter in a 30pt column, a hairline, a mono count.
private struct LetterHeader: View {
    let letter: String
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(letter)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(Theme.txt)
                .frame(width: 30, alignment: .leading)
            Rectangle().fill(Theme.line).frame(height: 1)
            Text("\(count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim)
        }
        .padding(.vertical, 8)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .background(Theme.bg)
    }
}

/// Status section header (group=status): dot, uppercase label, count, gradient rule.
private struct StatusSectionHeader: View {
    let status: CardStatus
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(status.color).frame(width: 8, height: 8)
            Text(status.sectionLabel.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.mut)
            Text("\(count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim)
            LinearGradient(colors: [Theme.line, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
        .padding(.top, 4)
        .padding(.bottom, 18)
    }
}

extension CardStatus {
    /// `statusColor(CARD_STATUS_KEY[...])`.
    var color: Color {
        switch self {
        case .downloading: return Theme.grab
        case .missing: return Theme.miss
        case .upcoming: return Theme.unaired
        case .complete: return Theme.done
        }
    }
}

// MARK: - A–Z rail

/// Shared between the scroll view (writer) and the rail (reader) so scrolling
/// never re-renders the whole page.
@Observable
final class RailMetrics {
    var stageY: CGFloat = 0
}

/// The A–Z rail (AlphabetRail.tsx `.railMobile`): 22pt wide with a hairline on
/// its left, sticky from the grid's top to above the tab bar. Tap a letter to
/// jump; hold or drag to scrub with the fisheye magnification and a selection
/// haptic per letter. Jumps are instant and throttled to 120ms.
private struct AlphabetRail: View {
    let available: Set<String>
    let metrics: RailMetrics
    let jump: (String) -> Void
    @Environment(\.motionEnabled) private var motion
    @State private var scrubIndex: Int?
    @State private var scrubbing = false
    @State private var touchStart: Date?
    @State private var lastJump = Date.distantPast
    @State private var pending: String?

    private let letters = ["#"] + "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).minY
            let minTop = geo.safeAreaInsets.top + 12
            let top = max(minTop, metrics.stageY - origin)
            let bottom = geo.size.height - 12
            let height = max(bottom - top, 120)
            rail(height: height)
                .frame(width: 22, height: height)
                .offset(y: top)
        }
        .frame(width: 22)
        .sensoryFeedback(.selection, trigger: scrubIndex)
        .accessibilityHidden(true)
    }

    private func rail(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(letters.indices, id: \.self) { i in
                let letter = letters[i]
                let present = available.contains(letter)
                let lift = liftFor(i)
                Text(letter)
                    .font(.system(size: 9.5, weight: scrubbing && scrubIndex == i ? .black : .heavy))
                    .foregroundStyle(color(i, present: present))
                    .shadow(color: scrubbing && scrubIndex == i ? Theme.i2.opacity(0.8) : .clear, radius: 6)
                    .scaleEffect(1 + lift * 1.5)
                    .offset(x: -lift * 42)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.line).frame(width: 1) }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = touchStart ?? Date()
                    if touchStart == nil { touchStart = start }
                    let moved = abs(value.translation.height) >= 8 || abs(value.translation.width) >= 8
                    if !scrubbing && (moved || Date().timeIntervalSince(start) >= 0.12) {
                        withAnimation(motion ? .snappy(duration: 0.18) : nil) { scrubbing = true }
                    }
                    guard scrubbing else { return }
                    let index = indexFor(y: value.location.y, height: height)
                    if index != scrubIndex {
                        withAnimation(motion ? .interactiveSpring(duration: 0.18) : nil) { scrubIndex = index }
                        request(letters[index])
                    }
                }
                .onEnded { value in
                    let index = indexFor(y: value.location.y, height: height)
                    if !scrubbing {
                        if available.contains(letters[index]) { jump(letters[index]) }
                    } else if let pending {
                        jump(pending)
                    }
                    pending = nil
                    touchStart = nil
                    withAnimation(motion ? .snappy(duration: 0.25) : nil) {
                        scrubbing = false
                        scrubIndex = nil
                    }
                }
        )
    }

    private func indexFor(y: CGFloat, height: CGFloat) -> Int {
        let usable = max(height - 8, 1)
        return min(max(Int((y - 4) / usable * CGFloat(letters.count)), 0), letters.count - 1)
    }

    /// Jumps at most every 120ms; the latest letter waits for the next slot.
    private func request(_ letter: String) {
        guard available.contains(letter) else { return }
        if Date().timeIntervalSince(lastJump) >= 0.12 {
            lastJump = Date()
            pending = nil
            jump(letter)
        } else {
            pending = letter
        }
    }

    /// `lift = max(0, 1 - |i - idx| / 3.5)`.
    private func liftFor(_ i: Int) -> CGFloat {
        guard scrubbing, motion, let idx = scrubIndex else { return 0 }
        return max(0, 1 - CGFloat(abs(i - idx)) / 3.5)
    }

    private func color(_ i: Int, present: Bool) -> Color {
        if scrubbing && scrubIndex == i { return Theme.i2 }
        return present ? Theme.mut : Theme.dim.opacity(0.3)
    }
}

// MARK: - Skeleton

/// LibraryGridSkeleton: 12 cells, 3 columns, gap 9, shimmering.
private struct LibraryGridSkeleton: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
            ForEach(0..<12, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 7) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .shimmer()
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    GeometryReader { geo in
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBar(height: 13, radius: 6).frame(width: geo.size.width * 0.82)
                            SkeletonBar(height: 11, radius: 6).frame(width: geo.size.width * 0.52)
                        }
                    }
                    .frame(height: 30)
                }
            }
        }
    }
}
