import Foundation
import FusionhaKit

/// Everything that decides what the Library grid shows. Equatable, so the page
/// re-derives once per real change (never per render: with thousands of
/// titles, re-filtering on every frame of a scrub froze the app).
struct LibraryInputs: Equatable {
    var version: Int
    var kind: String
    var tier: LibraryTier
    var status: LibraryStatus
    var sort: LibrarySort
    var recency: LibraryRecency
    var group: Bool
    var query: String
    var compact: Bool
    var columns: Int
    var compactSort: CompactSort
    /// Past 720 the A–Z grid gets letter headers (the desktop sections).
    var letterHeaders: Bool

    /// Filtering, counting and row building for one set of inputs.
    func derive(from library: [MediaItem], now: Date = Date()) -> LibraryDerived {
        let needle = query.lowercased()
        let recentWindow: TimeInterval = 30 * 86_400
        func recent(_ iso: String?) -> Bool {
            guard let date = Format.timestamp(iso) ?? Format.day(iso) else { return false }
            return date <= now && now.timeIntervalSince(date) <= recentWindow
        }
        // Tier + recency + search, before the kind narrowing (the kinds card counts this set).
        let kindBase = library.filter { item in
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
        let kind = LibraryKind(rawValue: self.kind)
        let base = LibraryView.sorted(kind.map { k in kindBase.filter { $0.libraryKind == k } } ?? kindBase, by: sort)
        next.pulse = PulseStats(base)
        next.attentionCount = base.filter { $0.hasAttention == true }.count
        let visible = status == .all ? base : base.filter(status.matches)
        next.visibleIds = visible.map(\.id)
        next.titleCount = visible.count
        next.editionCount = visible.reduce(0) { $0 + $1.editions.count }
        next.columns = columns
        next.recent = RecentShelf.pick(visible) { Format.timestamp($0) ?? Format.day($0) }
        if compact {
            next.rows = LibraryRowModel.table(compactSort.sorted(visible))
        } else if group {
            next.rows = LibraryRowModel.grouped(visible, columns: columns)
        } else if sort == .title {
            (next.rows, next.alpha) = LibraryRowModel.alpha(visible, columns: columns, headers: letterHeaders)
        } else {
            next.rows = LibraryRowModel.plain(visible, columns: columns)
        }
        return next
    }
}
