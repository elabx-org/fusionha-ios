import Foundation

// My requests' "From source" filter (fusionha 0.4.209 / 0.4.213; the web's
// `source-query.ts` and `SourceFilter.tsx`): a provider segment (all
// automatic, Plex, Letterboxd), then one segment per source of that provider
// from `GET /requests/counts` `by_source[]`.

/// One `by_source[]` bucket.
public struct RequestSourceCount: Decodable, Sendable, Hashable {
    public let kind: String
    public let label: String?
    public let owner: String?
    public let sourceId: Int?
    public let count: Int

    public init(kind: String, label: String? = nil, owner: String? = nil, sourceId: Int? = nil, count: Int) {
        self.kind = kind
        self.label = label
        self.owner = owner
        self.sourceId = sourceId
        self.count = count
    }
}

public struct RequestSourceFilter: Sendable, Hashable {
    public enum Provider: String, Sendable, Hashable, CaseIterable {
        case all, plex, letterboxd

        public var title: String {
            switch self {
            case .all: return "All automatic"
            case .plex: return "Plex"
            case .letterboxd: return "Letterboxd"
            }
        }

        public var allTitle: String { self == .plex ? "All Plex" : "All Letterboxd" }
    }

    /// One source of a provider: by id when the bucket carries one, else by
    /// list name (Plex rows from 0.4.209), else by kind.
    public struct Sub: Sendable, Hashable {
        public let kind: String
        public let sourceId: Int?
        public let label: String?

        public init(_ c: RequestSourceCount) {
            let single = c.kind == "LETTERBOXD_RSS" || c.kind == "PLEX_WATCHLIST"
            kind = c.kind
            sourceId = single ? nil : c.sourceId
            label = single ? nil : c.label
        }
    }

    public var provider: Provider
    public var sub: Sub?

    public init(provider: Provider, sub: Sub? = nil) {
        self.provider = provider
        self.sub = sub
    }

    /// The `GET /requests` + `/requests/counts` query items.
    public var query: [URLQueryItem] {
        guard let sub else {
            return [URLQueryItem(name: "source", value: provider == .all ? "plex,letterboxd" : provider.rawValue)]
        }
        var items = [URLQueryItem(name: "source", value: sub.kind)]
        if let id = sub.sourceId {
            items.append(URLQueryItem(name: "source_id", value: String(id)))
        } else if let label = sub.label {
            items.append(URLQueryItem(name: "source_label", value: label))
        }
        return items
    }

    public static func provider(of kind: String) -> Provider? {
        if RequestSourceWords.plexKinds.contains(kind) { return .plex }
        if RequestSourceWords.letterboxdKinds.contains(kind) { return .letterboxd }
        return nil
    }

    /// Every automatic request, for the chip ("From source 12").
    public static func total(_ bySource: [RequestSourceCount]) -> Int {
        bySource.filter { RequestSourceWords.isAutomatic($0.kind) }.reduce(0) { $0 + $1.count }
    }

    /// The segment label for one bucket.
    public static func subLabel(_ c: RequestSourceCount) -> String {
        switch c.kind {
        case "LETTERBOXD_RSS": return "Diary"
        case "LETTERBOXD_CSV": return "Import"
        case "PLEX_WATCHLIST": return "Watchlist"
        case "LETTERBOXD_WATCHLIST": return c.owner.map { "@\($0) · watchlist" } ?? "Watchlist"
        default: return c.label.map { "List · \($0)" } ?? "List"
        }
    }

    /// One provider's buckets in segment order: the diary or Plex watchlist,
    /// the own watchlist, the import, lists, then other people's watchlists.
    public static func subs(_ bySource: [RequestSourceCount], provider: Provider) -> [RequestSourceCount] {
        guard provider != .all else { return [] }
        return bySource.enumerated()
            .filter { self.provider(of: $0.element.kind) == provider }
            .sorted { a, b in
                let ra = rank(a.element), rb = rank(b.element)
                return ra != rb ? ra < rb : a.offset < b.offset
            }
            .map(\.element)
    }

    private static func rank(_ c: RequestSourceCount) -> Int {
        switch c.kind {
        case "PLEX_WATCHLIST", "LETTERBOXD_RSS": return 0
        case "LETTERBOXD_WATCHLIST": return c.owner != nil ? 4 : 1
        case "LETTERBOXD_CSV": return 2
        default: return 3
        }
    }

    public static let note = "These were requested automatically from your sources. Removing a title from a list or watchlist never cancels a request; withdraw it here."
}
