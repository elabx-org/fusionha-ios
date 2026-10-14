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
    /// Cards per grid row: 3 on phones, more when unfolded (`PosterColumns`).
    var columns = 3
    var alpha = LibraryAlphaIndex()
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

// MARK: - Sorting and letters

extension LibraryView {
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
}
