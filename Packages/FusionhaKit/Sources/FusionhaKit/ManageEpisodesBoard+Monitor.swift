import Foundation

// "Stop monitoring these episodes" beyond the files being deleted (web
// `manage-files/cross-version.ts`, 0.4.240). The episode monitor flag is shared
// by every version of a title, so on a title with more than one monitored
// version, unmonitoring after clearing the HD files also stops the 4K searching.

/// What the clear-out's toggle says and where it starts.
public struct ManageMonitorImpact: Sendable, Equatable {
    /// The title has more than one monitored version: "… in every version".
    public let multiVersion: Bool
    /// The monitored versions not being cleared (they stop searching too), in tier order.
    public let otherVersionIds: [Int]
    /// The toggle's default.
    public let defaultStop: Bool

    public static let single = ManageMonitorImpact(multiVersion: false, otherVersionIds: [], defaultStop: true)
}

extension ManageEpisodes {
    /// OFF when any deleted episode still has a file, or a monitored wanted
    /// (fileless) slot, in a version not being cleared; ON for a one-version
    /// title and when every version of those episodes is being cleared.
    /// `allRows` is the title's whole file list, not the sheet's scope.
    public static func monitorImpact(detail: ItemDetail, allRows: [ManagedFileRow],
                                     deleting: [ManagedFileItem]) -> ManageMonitorImpact {
        let monitored = detail.orderedEditions.filter(\.monitored)
        guard monitored.count > 1 else { return .single }
        let deletingIds = Set(deleting.map(\.id))
        let clearing = Set(deleting.map(\.row.versionId))
        let others = monitored.filter { !clearing.contains($0.id) }.map(\.id)

        // Per deleted episode: the versions being cleared for it, and the
        // versions that still hold a file for it once the delete is done.
        var cleared: [String: Set<Int>] = [:]
        for item in deleting {
            for e in item.row.episodes { cleared[key(item.row.season, e), default: []].insert(item.row.versionId) }
        }
        var kept: [String: Set<Int>] = [:]
        for row in allRows where !deletingIds.contains(row.fileId) {
            for e in row.episodes {
                let k = key(row.season, e)
                if cleared[k] != nil { kept[k, default: []].insert(row.versionId) }
            }
        }
        let keepsElsewhere = cleared.contains { k, versions in
            let keeping = kept[k] ?? []
            if keeping.contains(where: { !versions.contains($0) }) { return true }
            return monitored.contains { !versions.contains($0.id) && !keeping.contains($0.id) }
        }
        return ManageMonitorImpact(multiVersion: true, otherVersionIds: others, defaultStop: !keepsElsewhere)
    }

    /// The sheet's rows with the episodes the server just unmonitored drawn
    /// unmonitored (the title's detail is a snapshot from when it opened).
    public static func unmonitoring(_ items: [ManagedFileItem], episodeIds: Set<Int>,
                                    detail: ItemDetail) -> [ManagedFileItem] {
        guard !episodeIds.isEmpty else { return items }
        let lookup = Lookup(detail)
        return items.map { item in
            guard item.monitored, let s = item.row.season else { return item }
            let hit = item.row.episodes.contains { lookup.episodes["\(s):\($0)"].map { episodeIds.contains($0.id) } ?? false }
            return hit ? ManagedFileItem(row: item.row, monitored: false) : item
        }
    }

    private static func key(_ season: Int?, _ episode: Int) -> String { "\(season ?? -1):\(episode)" }
}
