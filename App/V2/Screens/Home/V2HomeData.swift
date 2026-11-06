import Foundation
import FusionhaKit

/// What Home shows, built once per library change (never per render) from
/// the whole library: the counts line, what needs the owner, Recently added
/// and one row per kind with titles.
struct V2HomeData {
    /// The counts line's numbers (`V2LibraryStatsLine` reads these).
    var stats = LibraryDerived()
    var attention: [MediaItem] = []
    /// Newest first, with something on disk (`RecentShelf`).
    var recent: [MediaItem] = []
    /// Titles added in the last 30 days: what "See all" opens.
    var recentCount = 0
    var kinds: [V2HomeKind] = []
    /// A few posters for the All titles card's stack.
    var stack: [MediaItem] = []

    static let recentLimit = 6
    static let kindLimit = 12

    init() {}

    init(library: [MediaItem], held: Set<Int>, now: Date = Date()) {
        stats.titleCount = library.count
        stats.editionCount = library.reduce(0) { $0 + $1.editions.count }
        stats.pulse = PulseStats(library)
        attention = library.filter { $0.hasAttention == true || held.contains($0.id) }
        let parse: (String?) -> Date? = { Format.timestamp($0) ?? Format.day($0) }
        recent = RecentShelf.pick(library, parse: parse, limit: Self.recentLimit)
        let since = now.addingTimeInterval(-30 * 86_400)
        recentCount = library.reduce(0) { n, item in
            guard let added = parse(item.addedAt), added <= now, added >= since else { return n }
            return n + 1
        }
        var byKind: [LibraryKind: [MediaItem]] = [:]
        for item in library { byKind[item.libraryKind, default: []].append(item) }
        for kind in LibraryKind.allCases {
            guard let items = byKind[kind], !items.isEmpty else { continue }
            stats.kindTitles[kind] = items.count
            // Newest additions first; ISO strings sort as their dates.
            let posters = items.filter { $0.posterUrl != nil }
                .sorted { ($0.addedAt ?? "") != ($1.addedAt ?? "") ? ($0.addedAt ?? "") > ($1.addedAt ?? "") : $0.id < $1.id }
            kinds.append(V2HomeKind(kind: kind, count: items.count, items: Array(posters.prefix(Self.kindLimit))))
        }
        stack = Array(kinds.flatMap { $0.items.prefix(2) }.prefix(5))
    }

    /// The ground's art when Coming up is hidden: the newest title's.
    var groundArt: URL? {
        guard let first = recent.first ?? kinds.first?.items.first else { return nil }
        return PageArtSource.url(backdrop: first.backdropUrl, poster: first.posterUrl)
    }
}

/// One kind's row on Home: its count and newest posters.
struct V2HomeKind: Identifiable {
    let kind: LibraryKind
    let count: Int
    let items: [MediaItem]
    var id: LibraryKind { kind }
}

/// How All titles opens from Home: as it was, on a kind, on what needs
/// the owner, or on Recently added (sorted by date added).
enum V2AllTitlesEntry: Equatable {
    case asLeft
    case everything
    case kind(LibraryKind)
    case needsYou
    case recent
}
