import Foundation

// Pure rules behind the Library's phone layout (B6): the poster art badges,
// the compact table's column sort, the kind badge subtitle, the no-matches
// copy and the stats sheet's connection line.

// MARK: - Poster badges (PosterCard.tsx)

/// What the web paints on a Library poster: the 4K flag (top right), the
/// Monitor bookmark (top left), the attention glyph and the live download
/// state (bottom left).
public struct PosterBadges: Equatable, Sendable {
    public enum Attention: Equatable, Sendable {
        /// Every flagged edition is a pure dead link (broken chain, `stuck`).
        case deadLink
        /// Files were not found on the last scan (⚠, `missing`).
        case notFound
    }

    public enum Live: Equatable, Sendable {
        case downloading, upgrading
    }

    public let has4k: Bool
    public let monitored: Bool
    public let attention: Attention?
    public let live: Live?

    public init(has4k: Bool, monitored: Bool, attention: Attention?, live: Live?) {
        self.has4k = has4k
        self.monitored = monitored
        self.attention = attention
        self.live = live
    }

    public init(_ item: MediaItem) {
        has4k = item.editions.contains { $0.tier == .uhd }
        // Any edition monitored → the filled bookmark (arr convention).
        monitored = item.editions.isEmpty ? (item.monitored ?? true) : item.editions.contains(where: \.monitored)
        if item.hasAttention == true {
            let flagged = item.editions.filter { $0.attention == true }
            let allDead = !flagged.isEmpty && flagged.allSatisfy {
                ($0.deadLinkCount ?? 0) > 0 && $0.deadLinkCount == $0.unresolvedFileCount
            }
            attention = allDead ? .deadLink : .notFound
        } else {
            attention = nil
        }
        // A fresh grab wins the corner over a calm upgrade.
        if item.editions.contains(where: { $0.status == .downloading }) {
            live = .downloading
        } else if item.editions.contains(where: { $0.status == .upgrading }) {
            live = .upgrading
        } else {
            live = nil
        }
    }
}

// MARK: - Compact table sort (library-compact.ts)

public enum CompactSortColumn: String, Sendable {
    case title, size
}

public struct CompactSort: Equatable, Sendable {
    public var column: CompactSortColumn
    public var ascending: Bool

    public init(column: CompactSortColumn = .title, ascending: Bool = true) {
        self.column = column
        self.ascending = ascending
    }

    /// A header tap: the active column flips direction; a new column starts
    /// ascending, except Size, which starts largest first.
    public func tapped(_ next: CompactSortColumn) -> CompactSort {
        if next == column { return CompactSort(column: column, ascending: !ascending) }
        return CompactSort(column: next, ascending: next != .size)
    }

    /// `compareCompact`: the direction flips the primary key only; ties keep
    /// an ascending title order.
    public func sorted(_ items: [MediaItem]) -> [MediaItem] {
        items.sorted { a, b in
            let byTitle = a.title.localizedCompare(b.title)
            switch column {
            case .title:
                return ascending ? byTitle == .orderedAscending : byTitle == .orderedDescending
            case .size:
                let x = a.totalSize, y = b.totalSize
                if x != y { return ascending ? x < y : x > y }
                return byTitle == .orderedAscending
            }
        }
    }
}

// MARK: - Kinds bar and empty copy

public enum LibraryPhoneCopy {
    /// The kind badge's subtitle: how many kinds are present for "All kinds",
    /// else the selected kind's version count.
    public static func kindSubtitle(allKinds: Bool, kindsPresent: Int, versions: Int) -> String {
        if allKinds { return "\(kindsPresent) \(kindsPresent == 1 ? "kind" : "kinds")" }
        return "\(versions) \(versions == 1 ? "version" : "versions")"
    }

    /// `library-no-matches`: "these filters" whenever anything narrows the
    /// grid (the search box counts, as in `hasActiveFilters`).
    public static func noMatches(filtersActive: Bool) -> String {
        "No titles match \(filtersActive ? "these filters" : "your search"). Try clearing a filter or the search box."
    }
}

// MARK: - Connection line (LibraryPulse.tsx `sheetConn`)

public enum ConnectionLine: String, Sendable {
    case connecting, ok, offline, unknown

    /// `/health`: still loading, failed, or the server's own status word.
    public init(loading: Bool, failed: Bool, status: String?) {
        if loading { self = .connecting } else if failed { self = .offline } else if status == "ok" { self = .ok } else { self = .unknown }
    }

    public var label: String {
        switch self {
        case .ok: return "All systems connected"
        case .offline: return "Backend offline"
        case .connecting: return "Connecting…"
        case .unknown: return "Connection status unknown"
        }
    }
}
