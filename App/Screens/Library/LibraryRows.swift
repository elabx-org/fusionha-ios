import SwiftUI
import FusionhaKit

// MARK: - Rows

/// One row of the Library scroll. Rows are flat so the scroll stays fully lazy
/// and the scroll thumb can jump to any row.
enum LibraryRowModel: Identifiable {
    case section(CardStatus, Int)
    /// A–Z letter header (wide layout): the letter and its title count.
    case letter(String, Int)
    case items([MediaItem])
    case tableHeader
    case tableRow(MediaItem, last: Bool)

    var id: String {
        switch self {
        case .section(let status, _): return "status-\(status.rawValue)"
        case .letter(let letter, _): return "letter-\(letter)"
        case .items(let items): return "row-\(items[0].id)"
        case .tableHeader: return "table-header"
        case .tableRow(let item, _): return "table-\(item.id)"
        }
    }

    private static func chunk(_ group: ArraySlice<MediaItem>, columns: Int, into rows: inout [LibraryRowModel]) {
        var start = group.startIndex
        let columns = max(columns, 1)
        while start < group.endIndex {
            let end = min(start + columns, group.endIndex)
            rows.append(.items(Array(group[start..<end])))
            start = end
        }
    }

    /// The A–Z grid on phones (`buildRowModel` with `headers: false`): one
    /// continuous run of 3-card rows with no letter headers. Each letter's jump
    /// target is the row holding its FIRST title; each row remembers the letter
    /// of its first card for the thumb's "where am I" bubble.
    static func alpha(_ items: [MediaItem], columns: Int = 3, headers: Bool = false) -> (rows: [LibraryRowModel], index: LibraryAlphaIndex) {
        if headers { return alphaSectioned(items, columns: columns) }
        var rows: [LibraryRowModel] = []
        chunk(items[...], columns: columns, into: &rows)
        var index = LibraryAlphaIndex()
        for (i, row) in rows.enumerated() {
            guard case .items(let cards) = row else { continue }
            index.rowLetter[row.id] = (i, LibraryView.letter(for: cards[0].title))
            for card in cards {
                let letter = LibraryView.letter(for: card.title)
                if index.letterRow[letter] == nil { index.letterRow[letter] = row.id }
            }
        }
        index.letters = LibraryAlphaIndex.alphabet.filter { index.letterRow[$0] != nil }
        return (rows, index)
    }

    /// The A–Z grid past 720 (`buildRowModel` with `headers: true`): a letter
    /// header before each letter's run, its titles starting a fresh row. The
    /// rail jumps to the header.
    private static func alphaSectioned(_ items: [MediaItem], columns: Int) -> (rows: [LibraryRowModel], index: LibraryAlphaIndex) {
        var rows: [LibraryRowModel] = []
        var index = LibraryAlphaIndex()
        var start = items.startIndex
        while start < items.endIndex {
            let letter = LibraryView.letter(for: items[start].title)
            var end = start
            while end < items.endIndex && LibraryView.letter(for: items[end].title) == letter { end += 1 }
            // A letter that comes back (an odd sort key) continues its first run
            // without a second header, so row ids stay unique.
            if index.letterRow[letter] == nil {
                let header = LibraryRowModel.letter(letter, end - start)
                index.letterRow[letter] = header.id
                index.rowLetter[header.id] = (rows.count, letter)
                rows.append(header)
            }
            let first = rows.count
            chunk(items[start..<end], columns: columns, into: &rows)
            for i in first..<rows.count { index.rowLetter[rows[i].id] = (i, letter) }
            start = end
        }
        index.letters = LibraryAlphaIndex.alphabet.filter { index.letterRow[$0] != nil }
        return (rows, index)
    }

    /// A plain grid for the other sorts.
    static func plain(_ items: [MediaItem], columns: Int = 3) -> [LibraryRowModel] {
        var rows: [LibraryRowModel] = []
        chunk(items[...], columns: columns, into: &rows)
        return rows
    }

    /// Group by status (`groupByStatus`): Downloading, Needs attention, Upcoming, Complete.
    static func grouped(_ items: [MediaItem], columns: Int = 3) -> [LibraryRowModel] {
        var rows: [LibraryRowModel] = []
        for status in CardStatus.allCases {
            let members = items.filter { $0.cardStatus == status }
            guard !members.isEmpty else { continue }
            rows.append(.section(status, members.count))
            chunk(members[...], columns: columns, into: &rows)
        }
        return rows
    }

    static func table(_ items: [MediaItem]) -> [LibraryRowModel] {
        guard !items.isEmpty else { return [] }
        return [.tableHeader] + items.enumerated().map { .tableRow($0.element, last: $0.offset == items.count - 1) }
    }
}

/// The grid rows last seen on screen. A plain class so scrolling never
/// re-renders the page; read only when the column count changes.
final class LibraryOnScreen {
    var rowIds: [String] = []

    /// The row that now holds the topmost title that was on screen.
    func anchorRow(in derived: LibraryDerived) -> String? {
        let shown = Set(rowIds.compactMap { id -> Int? in
            id.hasPrefix("row-") ? Int(id.dropFirst(4)) : (id.hasPrefix("table-") ? Int(id.dropFirst(6)) : nil)
        })
        guard !shown.isEmpty else { return nil }
        // Row ids carry their first title; the topmost is the earliest in display order.
        guard let top = derived.visibleIds.first(where: shown.contains) else { return nil }
        // Still at the top of the page: stay there (header and all).
        if top == derived.visibleIds.first { return nil }
        for row in derived.rows {
            switch row {
            case .items(let items) where items.contains(where: { $0.id == top }): return row.id
            case .tableRow(let item, _) where item.id == top: return row.id
            default: continue
            }
        }
        return nil
    }
}

/// Jump targets for the scroll thumb (`buildAlphaIndex` + `startLetters`).
struct LibraryAlphaIndex {
    /// `ALPHABET`: '#' then A–Z.
    static let alphabet = ["#"] + "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
    /// The letters that have titles, in ALPHABET order.
    var letters: [String] = []
    /// Letter → the row holding its first title.
    var letterRow: [String: String] = [:]
    /// Row id → (row position, letter of its first card).
    var rowLetter: [String: (Int, String)] = [:]

    /// The letter at the top of the grid, from the rows on screen.
    func activeLetter(visible ids: [String]) -> String? {
        ids.compactMap { rowLetter[$0] }.min { $0.0 < $1.0 }?.1
    }
}

/// The A–Z letter header (`.alphaHead`): the letter, a hairline, the count.
struct LibraryLetterHeader: View {
    let letter: String
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(letter)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(Theme.txt)
                .frame(width: 30, alignment: .leading)
                .accessibilityHidden(true)
            // Broken at the iPhone Duo's fold (Web layout), never across it.
            Rectangle().fill(Theme.line).frame(height: 1).foldGapMask()
            Text("\(count)").font(.system(size: 12, design: .monospaced).monospacedDigit()).foregroundStyle(Theme.dim)
        }
        .padding(.vertical, 8)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(letter), \(count) \(count == 1 ? "title" : "titles")")
        .accessibilityAddTraits(.isHeader)
    }
}

/// Status section header (group=status): dot, uppercase label, count, gradient rule.
struct StatusSectionHeader: View {
    let status: CardStatus
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(token: status.monoToken, size: 8)
            Text(status.sectionLabel.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.mut)
            Text("\(count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.dim)
            LinearGradient(colors: [Theme.line, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .foldGapMask()
        }
        .padding(.top, 4)
        .padding(.bottom, 22)
    }
}

// MARK: - Skeleton

/// LibraryGridSkeleton: 12 cells, 18 × 6 gaps, shimmering, in the same
/// columns and tracks as the grid it stands in for (`LibraryView.columns` and
/// its fold tracks), so the first load does not re-flow and, on an open
/// iPhone Duo, no cell sits on the fold.
struct LibraryGridSkeleton: View {
    var columns = 3
    var tracks: [FoldColumns.Track]?

    private var rows: Int { max(1, (12 + columns - 1) / max(columns, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<rows, id: \.self) { _ in
                if let tracks, tracks.count == columns {
                    TrackRowLayout(tracks: tracks) {
                        ForEach(0..<columns, id: \.self) { _ in cell }
                    }
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        ForEach(0..<max(columns, 1), id: \.self) { _ in cell.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }

    private var cell: some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.txt.opacity(0.06))
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

/// One poster row: `columns` cards, each row only as tall as its own tallest
/// card (7f2b50c7), padded out with empty cells on the last row.
struct LibraryGridRow: View {
    static let spacing: Double = 6
    let items: [MediaItem]
    let columns: Int
    /// With a fold through the grid: each poster's track, the fold in a gutter.
    var tracks: [FoldColumns.Track]?

    var body: some View {
        Group {
            if let tracks, tracks.count == columns {
                TrackRowLayout(tracks: tracks) {
                    ForEach(items) { PosterCard(item: $0) }
                }
            } else {
                HStack(alignment: .top, spacing: CGFloat(Self.spacing)) {
                    ForEach(0..<max(columns, items.count), id: \.self) { i in
                        if i < items.count {
                            PosterCard(item: items[i]).frame(maxWidth: .infinity, alignment: .top)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 18)
    }
}

/// The Library grid's own width and the top-to-bottom fold through it, in
/// its coordinates (`FoldInfo.verticalFold`): the real fold x, so the Duo's
/// off-centre fold lands in a gutter (the old `crossesMiddle` missed it).
struct LibraryGridFold: Equatable {
    var width: CGFloat = 0
    var fold: ClosedRange<CGFloat>?

    init() {}

    init(_ proxy: GeometryProxy) {
        width = proxy.size.width
        fold = FoldInfo.verticalFold(proxy)
    }
}

/// The Library scroll's measured width. The fold is read where it matters,
/// at its real x (`LibraryGridFold`), never assumed in the middle.
struct LibraryPane: Equatable {
    var width: CGFloat = 0
}
