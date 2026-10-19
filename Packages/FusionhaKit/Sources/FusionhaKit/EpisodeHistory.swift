import Foundation

/// The episode sheet's History tab (EpisodeDetailDialog `episodeHistory`):
/// the episode's own events, plus season-pack events that cover it (a pack
/// grab names the season in `data.season`, or shares a download id with one
/// of the episode's own rows). Newest first; scoped to the page's versions.
public enum EpisodeHistory {
    public static func rows(_ history: [HistoryEntry], episodeId: Int, seasonNumber: Int,
                            versionIds: Set<Int>? = nil) -> [HistoryEntry] {
        func inScope(_ entry: HistoryEntry) -> Bool {
            guard let versionIds, let id = entry.editionId else { return true }
            return versionIds.contains(id)
        }
        let direct = history.filter { $0.episodeId == episodeId && inScope($0) }
        let downloads = Set(direct.compactMap(\.downloadId))
        let packs = history.filter { entry in
            guard entry.episodeId == nil, inScope(entry) else { return false }
            if case .number(let season)? = entry.data?["season"], Int(season) == seasonNumber { return true }
            if let id = entry.downloadId, downloads.contains(id) { return true }
            return false
        }
        return (direct + packs).sorted { $0.createdAt > $1.createdAt }
    }
}
