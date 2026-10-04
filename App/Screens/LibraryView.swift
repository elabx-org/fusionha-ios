import SwiftUI
import FusionhaKit

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, downloading, missing, complete, attention
    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All titles"
        case .downloading: return "Downloading"
        case .missing: return "Missing"
        case .complete: return "Complete"
        case .attention: return "Needs attention"
        }
    }

    func matches(_ item: MediaItem) -> Bool {
        let rails = item.editions.filter(\.monitored).map { $0.rail(isSeries: item.kind == .series) }
        switch self {
        case .all: return true
        case .downloading: return rails.contains { $0.state == .downloading || $0.state == .upgrading }
        case .missing: return rails.contains { $0.state == .wanted || $0.state == .partial }
        case .complete: return !rails.isEmpty && rails.allSatisfy { $0.state == .owned }
        case .attention: return item.hasAttention == true || rails.contains(where: \.attention)
        }
    }
}

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

enum LibrarySort: String, CaseIterable, Identifiable {
    case title, added, year
    var id: Self { self }
    var label: String {
        switch self {
        case .title: return "Title"
        case .added: return "Date added"
        case .year: return "Year"
        }
    }
}

/// The web's Library page on mobile: header, kinds card, tier filter + Filters,
/// grid/list toggle and the A–Z sectioned poster grid with its letter rail.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("library.kind") private var kindRaw = "all"
    @AppStorage("library.list") private var listMode = false
    @State private var tier: LibraryTier = .all
    @State private var filter: LibraryFilter = .all
    @State private var sort: LibrarySort = .title

    private var kind: KindBucket? { KindBucket(rawValue: kindRaw) }

    private var query: String {
        model.searchScope == .library ? model.searchText.trimmingCharacters(in: .whitespaces) : ""
    }

    /// The filtered, sorted, sectioned rows. Built once per input change rather
    /// than on every render: with thousands of titles, re-filtering and
    /// re-sorting on each frame of an A–Z rail drag froze the app.
    @State private var rows: [LibraryRowModel] = []
    @State private var letters: Set<String> = []
    @State private var visibleCount = 0

    private struct Inputs: Equatable {
        var version: Int, kind: String, tier: LibraryTier, filter: LibraryFilter
        var sort: LibrarySort, query: String, list: Bool
    }

    private var inputs: Inputs {
        Inputs(version: model.libraryVersion, kind: kindRaw, tier: tier, filter: filter,
               sort: sort, query: query, list: listMode)
    }

    private func rebuild() {
        let titleSort = sort == .title
        let keyed = model.library
            .filter { item in
                (kind == nil || item.kindBucket == kind) && tier.matches(item) && filter.matches(item)
                    && (query.isEmpty || item.title.localizedCaseInsensitiveContains(query))
            }
            .map { (item: $0, key: titleSort ? Self.sortKey($0.title) : "") }
        let visible: [MediaItem]
        switch sort {
        case .title:
            visible = keyed.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }.map(\.item)
        case .added:
            visible = keyed.map(\.item).sorted { ($0.addedAt ?? "") > ($1.addedAt ?? "") }
        case .year:
            visible = keyed.map(\.item).sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        }
        visibleCount = visible.count
        rows = LibraryRowModel.build(visible, sectioned: titleSort && !listMode, perRow: listMode ? 1 : 3)
        letters = Set(rows.compactMap { if case .header(let letter, _) = $0 { letter } else { nil } })
    }

    /// "The Matrix" sorts under M, like the web's alphabet grouping.
    static func sortKey(_ title: String) -> String {
        for article in ["The ", "A ", "An "] where title.hasPrefix(article) {
            return String(title.dropFirst(article.count))
        }
        return title
    }

    static func letter(for title: String) -> String {
        guard let first = sortKey(title).uppercased().first else { return "#" }
        return first.isLetter && first.isASCII ? String(first) : "#"
    }

    var body: some View {
        Screen(showsAdd: true, filtersInPlace: true) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        PageHeader(title: "Library", subtitle: subtitle)
                        KindsCard(items: model.library, selection: $kindRaw)
                        toolbar
                        content
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 14)
                    .padding(.trailing, showsRail ? 22 : 0)
                    .padding(.bottom, 90)
                }
                .refreshable { await model.loadLibrary() }
                .overlay(alignment: .trailing) {
                    if showsRail {
                        AlphabetRail(available: letters) { letter in
                            // No animation: an animated jump per letter while dragging
                            // queued up scrolls and made the app unresponsive.
                            proxy.scrollTo(LibraryRowModel.headerId(letter), anchor: .top)
                        }
                        .padding(.trailing, 2)
                    }
                }
            }
        }
        .task {
            if !model.libraryLoaded { await model.loadLibrary() }
        }
        .onChange(of: inputs, initial: true) { rebuild() }
    }

    private var showsRail: Bool { sort == .title && !listMode && visibleCount > 0 }

    private var subtitle: String {
        let editions = model.library.reduce(0) { $0 + $1.editions.count }
        return "\(model.library.count) titles · \(editions) editions"
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SegmentedPills(options: [(LibraryTier.all, "All"), (.hd, "HD"), (.uhd, "4K")], selection: $tier)
                Spacer(minLength: 0)
                Menu {
                    Picker("Show", selection: $filter) {
                        ForEach(LibraryFilter.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Sort by", selection: $sort) {
                        ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Filters")
                        if filter != .all || sort != .title {
                            Circle().fill(Theme.cyan).frame(width: 7, height: 7)
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.txt)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .panel(Theme.panel, radius: 12)
                }
            }
            viewToggle
        }
    }

    /// Grid / list icon toggle.
    private var viewToggle: some View {
        HStack(spacing: 2) {
            ForEach([false, true], id: \.self) { list in
                Button {
                    withAnimation(.snappy) { listMode = list }
                } label: {
                    Image(systemName: list ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(listMode == list ? Color(hex: 0xA5F3FC) : Theme.mut)
                        .frame(width: 40, height: 34)
                        .background {
                            if listMode == list {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.indigo.opacity(0.26))
                                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(Theme.indigo.opacity(0.7)))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(list ? "List view" : "Grid view")
            }
        }
        .padding(4)
        .panel(Theme.panel2, radius: 12)
    }

    @ViewBuilder
    private var content: some View {
        if model.library.isEmpty {
            if !model.libraryLoaded {
                ProgressView().tint(Theme.mut).frame(maxWidth: .infinity).padding(.top, 60)
            } else if let error = model.libraryError {
                EmptyBox(message: "The library could not be loaded. \(error)", systemImage: "wifi.exclamationmark")
            } else {
                EmptyBox(message: "Your library is empty. Tap + to add a title.")
            }
        } else if rows.isEmpty {
            EmptyBox(message: query.isEmpty ? "No titles match these filters." : "No titles match “\(query)”.")
        } else {
            ForEach(rows) { row in
                switch row {
                case .header(let letter, let count):
                    LetterHeader(letter: letter, count: count)
                case .items(let items):
                    if listMode {
                        LibraryRow(item: items[0]).onTapGesture { model.open(items[0].id) }
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(0..<3, id: \.self) { i in
                                if i < items.count {
                                    PosterCard(item: items[i]).frame(maxWidth: .infinity, alignment: .top)
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One row of the Library scroll: a letter header or a line of posters. Rows
/// are flat so the scroll stays fully lazy and the rail can jump to any header.
enum LibraryRowModel: Identifiable {
    case header(String, Int)
    case items([MediaItem])

    var id: String {
        switch self {
        case .header(let letter, _): return Self.headerId(letter)
        case .items(let items): return "row-\(items[0].id)"
        }
    }

    static func headerId(_ letter: String) -> String { "letter-\(letter)" }

    static func build(_ items: [MediaItem], sectioned: Bool, perRow: Int) -> [LibraryRowModel] {
        var rows: [LibraryRowModel] = []
        func chunk(_ group: ArraySlice<MediaItem>) {
            var start = group.startIndex
            while start < group.endIndex {
                let end = min(start + perRow, group.endIndex)
                rows.append(.items(Array(group[start..<end])))
                start = end
            }
        }
        guard sectioned else {
            chunk(items[...])
            return rows
        }
        var start = items.startIndex
        while start < items.endIndex {
            let letter = LibraryView.letter(for: items[start].title)
            var end = start + 1
            while end < items.endIndex, LibraryView.letter(for: items[end].title) == letter { end += 1 }
            rows.append(.header(letter, end - start))
            chunk(items[start..<end])
            start = end
        }
        return rows
    }
}

/// The kinds summary card: proportional kind bar + kind chips with counts.
private struct KindsCard: View {
    let items: [MediaItem]
    @Binding var selection: String

    private func count(_ kind: KindBucket) -> Int { items.filter { $0.kindBucket == kind }.count }

    var body: some View {
        let selected = KindBucket(rawValue: selection)
        let present = KindBucket.allCases.filter { count($0) > 0 }
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: selected == .series || selected == .anime ? "tv" : "film")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(selected.map(Theme.kind) ?? Theme.cyan)
                    .frame(width: 30, height: 30)
                    .background((selected.map(Theme.kind) ?? Theme.cyan).opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder((selected.map(Theme.kind) ?? Theme.cyan).opacity(0.4)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(selected?.plural ?? "All kinds")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                    Text(selected.map { "\(count($0)) titles" } ?? "\(present.count) kinds")
                        .font(.system(size: 12)).foregroundStyle(Theme.mut)
                }
            }

            GeometryReader { geo in
                let total = max(items.count, 1)
                let gaps = CGFloat(max(present.count - 1, 0)) * 2
                HStack(spacing: 2) {
                    ForEach(present, id: \.self) { kind in
                        Capsule()
                            .fill(Theme.kind(kind))
                            .opacity(selected == nil || selected == kind ? 1 : 0.3)
                            .frame(width: (geo.size.width - gaps) * CGFloat(count(kind)) / CGFloat(total))
                    }
                }
            }
            .frame(height: 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(label: "All", count: nil, color: Theme.indigo, value: "all")
                    ForEach(KindBucket.allCases, id: \.self) { kind in
                        chip(label: kind.plural, count: count(kind), color: Theme.kind(kind), value: kind.rawValue)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color(hex: 0x10272E), Theme.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.line))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func chip(label: String, count: Int?, color: Color, value: String) -> some View {
        DotChip(label: label, count: count, dot: color, selected: selection == value) {
            withAnimation(.snappy) { selection = value }
        }
    }
}

private struct LetterHeader: View {
    let letter: String
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            Text(letter).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.txt)
            Rectangle().fill(Theme.line).frame(height: 1)
            Text("\(count)").font(.system(size: 13).monospacedDigit()).foregroundStyle(Theme.dim)
        }
        .padding(.top, 8)
    }
}

/// The A–Z rail on the right edge; tap or drag to jump to a letter.
private struct AlphabetRail: View {
    let available: Set<String>
    let jump: (String) -> Void
    @State private var active: String?

    private let letters = ["#"] + "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(letter == active ? Theme.cyan : (available.contains(letter) ? Theme.mut : Theme.dim.opacity(0.5)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let index = Int(value.location.y / geo.size.height * CGFloat(letters.count))
                let letter = letters[min(max(index, 0), letters.count - 1)]
                guard letter != active else { return }
                active = letter
                if available.contains(letter) { jump(letter) }
            }.onEnded { _ in active = nil })
        }
        .frame(width: 18)
        .frame(maxHeight: 460)
        .sensoryFeedback(.selection, trigger: active)
        .accessibilityHidden(true)
    }
}

/// The web's poster card: clean art with corner badges, then title, meta line
/// and one coverage rail per edition.
struct PosterCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let item: MediaItem

    private var monitored: Bool { item.monitored ?? true }
    private var downloading: Bool {
        item.editions.contains { $0.status == .downloading || $0.status == .upgrading }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(monitored ? Theme.txt : Theme.mut)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if let year = item.year {
                        Text(String(year)).lineLimit(1)
                    }
                    if item.isAnime == true {
                        AnimeChip()
                    } else {
                        Text("·")
                        KindGlyph(kind: item.kind)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(monitored ? Theme.mut : Theme.dim)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(item.editions) { CoverageRailView(edition: $0, isSeries: item.kind == .series) }
                }
                .padding(.top, 6)
            }
            .padding(.top, 7)
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.open(item.id) }
        .contextMenu { actions }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var art: some View {
        PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w342"))
            .aspectRatio(2 / 3, contentMode: .fit)
            .saturation(monitored ? 1 : 0.75)
            .brightness(monitored ? 0 : -0.1)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(item.hasAttention == true ? Theme.miss.opacity(0.7) : Theme.line))
            .overlay(alignment: .topLeading) {
                Image(systemName: monitored ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(monitored ? Theme.cyan : .white.opacity(0.72))
                    .frame(width: 22, height: 22)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.18)))
                    .padding(8)
                    .accessibilityLabel(monitored ? "Monitored" : "Not monitored")
            }
            .overlay(alignment: .topTrailing) {
                if item.editions.contains(where: { $0.tier == .uhd }) {
                    Text("4K")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.22)))
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if downloading {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.grab)
                        .symbolEffect(.rotate, options: .repeat(.continuous))
                        .frame(width: 22, height: 22)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.grab.opacity(0.55)))
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Menu { actions } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
                        .frame(width: 34, height: 30)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More actions")
            }
    }

    @ViewBuilder
    private var actions: some View {
        Button("Open", systemImage: "arrow.up.right.square") { model.open(item.id) }
        Button("Automatic search", systemImage: "magnifyingglass") {
            Task { try? await model.client?.searchItem(id: item.id) }
        }
        if let server = model.credentials?.serverURL {
            Button("Open in web app", systemImage: "safari") {
                openURL(server.appendingPathComponent("library/\(item.id)"))
            }
        }
    }
}

/// Compact list row (the web's list view).
private struct LibraryRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w154"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                HStack(spacing: 6) {
                    if let year = item.year { Text(String(year)) }
                    if item.isAnime == true { AnimeChip() } else { KindGlyph(kind: item.kind) }
                }
                .font(.system(size: 12)).foregroundStyle(Theme.mut)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(item.editions) { CoverageRailView(edition: $0, isSeries: item.kind == .series) }
                }
                .frame(maxWidth: 220)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .panel(Theme.card, radius: 12)
        .contentShape(Rectangle())
    }
}
