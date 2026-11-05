import Foundation
import FusionhaKit

/// What the Library home's poster shelf shows; its header is a menu of these
/// (mock browse.js `shelfMenu`). Sources the server can't answer yet
/// (missing episodes, upgrades waiting, airing this week) stay out, and an
/// empty source hides from the menu.
enum V2LibraryShelfSource: String, CaseIterable, Identifiable {
    case recentlyAdded, missing, needsYou, upcoming

    var id: Self { self }

    var title: String {
        switch self {
        case .recentlyAdded: return "Recently added"
        case .missing: return "Missing"
        case .needsYou: return "Needs you"
        case .upcoming: return "Upcoming"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyAdded: return "sparkles"
        case .missing: return "circle.dashed"
        case .needsYou: return "exclamationmark.triangle"
        case .upcoming: return "clock"
        }
    }

    /// The grid filter "See all" applies for this shelf.
    var seeAll: (status: LibraryStatus, sort: LibrarySort) {
        switch self {
        case .recentlyAdded: return (.all, .addedDesc)
        case .missing: return (.missing, .title)
        case .needsYou: return (.attention, .title)
        case .upcoming: return (.upcoming, .title)
        }
    }
}

/// The Library home above the grid, derived once per filter change with the
/// grid (never per render): the hero cards, each shelf's titles and the
/// needs-attention titles, all from the titles the filters left.
struct V2LibraryHome {
    var heroes: [MediaItem] = []
    var shelves: [V2LibraryShelfSource: [MediaItem]] = [:]
    var attention: [MediaItem] = []

    static let heroLimit = 6
    static let shelfLimit = 12

    init() {}

    /// `visible`: the filtered titles; `recent`: the grid's Recently added
    /// pick; `held`: titles with a held download in the queue.
    init(visible: [MediaItem], recent: [MediaItem], held: Set<Int>, now: Date = Date()) {
        func date(_ iso: String?) -> Date? { Format.timestamp(iso) ?? Format.day(iso) }
        // Heroes: what is moving first (downloading), then the newest
        // releases already out, then the newest additions.
        let moving = visible.filter { $0.cardStatus == .downloading }
        var dated: [(item: MediaItem, date: Date)] = []
        for item in visible {
            if let released = date(item.releaseDate), released <= now { dated.append((item, released)) }
        }
        let released = dated.sorted { $0.date > $1.date }.map { $0.item }
        var seen = Set<Int>()
        heroes = (moving + released + recent)
            .filter { ($0.backdropUrl ?? $0.posterUrl) != nil && seen.insert($0.id).inserted }
            .prefix(Self.heroLimit)
            .map { $0 }
        attention = visible.filter { $0.hasAttention == true || held.contains($0.id) }
        let missing = visible.filter { $0.cardStatus == .missing && ($0.monitored ?? true) }
        let upcoming = visible
            .filter { $0.cardStatus == .upcoming }
            .sorted { (date($0.nextRelease) ?? .distantFuture) < (date($1.nextRelease) ?? .distantFuture) }
        shelves = [
            .recentlyAdded: recent,
            .missing: Array(missing.prefix(Self.shelfLimit)),
            .needsYou: Array(attention.prefix(Self.shelfLimit)),
            .upcoming: Array(upcoming.prefix(Self.shelfLimit)),
        ]
    }

    /// The sources with something to show, in menu order.
    var sources: [V2LibraryShelfSource] {
        V2LibraryShelfSource.allCases.filter { !(shelves[$0] ?? []).isEmpty }
    }

    /// The art the page's ground samples: the first hero (plan S4).
    var groundArt: URL? {
        guard let first = heroes.first else { return nil }
        return PageArtSource.url(backdrop: first.backdropUrl, poster: first.posterUrl)
    }
}
