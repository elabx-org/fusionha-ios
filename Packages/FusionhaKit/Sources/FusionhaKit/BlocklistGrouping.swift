import Foundation

/// Blocklist rows collapsed for display (web `activity-format.ts` `groupBlocklist`
/// and BlocklistTab's `groupByTitle`). First-appearance order is preserved.
public enum BlocklistGrouping {

    /// Copies sharing (item title + release name + reason), each removable on its own.
    public struct Release: Identifiable, Sendable, Equatable {
        public let key: String
        public let entries: [BlocklistEntry]
        public var id: String { key }
        public var lead: BlocklistEntry { entries[0] }
        public var count: Int { entries.count }
        public var ids: [Int] { entries.map(\.id) }
    }

    /// Every release of one title, for the "Group by title" view.
    public struct Title: Identifiable, Sendable, Equatable {
        public let key: String
        public let entries: [BlocklistEntry]
        public var id: String { key }
        public var releases: [Release] { BlocklistGrouping.releases(entries) }
    }

    /// The web's `groupBlocklist`: collapses across the whole list, not just neighbours.
    public static func releases(_ items: [BlocklistEntry]) -> [Release] {
        var order: [String] = []
        var map: [String: [BlocklistEntry]] = [:]
        for entry in items {
            let title = entry.itemTitle ?? entry.title
            let release = entry.sourceTitle ?? entry.title
            let key = "\(title)\u{0}\(release)\u{0}\(entry.reason ?? "")"
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(entry)
        }
        return order.map { Release(key: $0, entries: map[$0] ?? []) }
    }

    /// Releases clustered under their owning title.
    public static func titles(_ items: [BlocklistEntry]) -> [Title] {
        var order: [String] = []
        var map: [String: [BlocklistEntry]] = [:]
        for entry in items {
            let key = entry.mediaItemId.map { "item:\($0)" } ?? "title:\(entry.itemTitle ?? entry.title)"
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(entry)
        }
        return order.map { Title(key: $0, entries: map[$0] ?? []) }
    }

    /// Selection scoped to what is visible: hidden rows never stay selected.
    public static func pruned(_ selected: Set<Int>, visible: [BlocklistEntry]) -> Set<Int> {
        selected.intersection(visible.map(\.id))
    }
}
