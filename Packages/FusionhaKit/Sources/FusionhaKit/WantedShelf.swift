import Foundation

/// One of All titles' wanted shelves (v2 mock browse.js / minimize.js:
/// "Missing episodes", "Upgrades waiting"): the library titles a
/// `GET /api/v1/wanted?state=` page names, in the server's order, narrowed
/// to the kind control's kind, with the count its header shows.
public struct WantedShelf: Sendable, Hashable, Identifiable {
    public enum Source: String, Sendable, Hashable, CaseIterable {
        case missing, upgrades

        public var state: WantedState { self == .missing ? .missing : .cutoffUnmet }
    }

    public let source: Source
    public let items: [MediaItem]
    /// The titles the shelf stands for (more than `items` when capped).
    public let count: Int

    public var id: Source { source }

    /// The posters a shelf shows at most.
    public static let limit = 20

    /// "Missing episodes" when every title is a series, "Missing movies"
    /// when every one is a movie, else "Missing"; "Upgrades waiting".
    public var title: String {
        switch source {
        case .upgrades: return "Upgrades waiting"
        case .missing:
            if items.allSatisfy({ $0.kind == .movie }) { return "Missing movies" }
            if items.allSatisfy({ $0.kind != .movie }) { return "Missing episodes" }
            return "Missing"
        }
    }

    /// nil when there is no page yet or none of its titles is in `library`
    /// under `kind` (the shelf hides). With every kind the count is the
    /// server's title total for the state; with one kind it is the matching
    /// titles of the page (the wanted feed has no kind filter).
    public static func make(_ source: Source, page: WantedPage?, library: [MediaItem],
                            kind: LibraryKind?, limit: Int = limit) -> WantedShelf? {
        guard let page else { return nil }
        let byId = Dictionary(library.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let matching = page.items.compactMap { byId[$0.id] }.filter { kind == nil || $0.libraryKind == kind }
        guard !matching.isEmpty else { return nil }
        let serverTitles = source == .missing ? page.missingTitles : page.cutoffUnmetTitles
        let count = kind == nil ? max(serverTitles ?? page.total, matching.count) : matching.count
        return WantedShelf(source: source, items: Array(matching.prefix(limit)), count: count)
    }
}
