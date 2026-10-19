import Foundation
import FusionhaKit

/// The Add-collection sheet opened from the detail page, preselected to `tmdbIds`.
struct CollectionAddTarget: Identifiable {
    let id = UUID()
    let summary: CollectionSummary
    let tmdbIds: [Int]
}

// The movie Collection tab and rail (MovieCollectionTab, DetailRailStack's
// CollectionRail): one fetch shared by both.
extension DetailStore {
    func loadCollection() async {
        guard let client, let id = detail?.collection?.collectionTmdbId else { return }
        do {
            collection = try await client.collection(id: id)
            collectionFailed = false
        } catch {
            if collection == nil { collectionFailed = true }
        }
    }

    /// Opens the shared Add-collection sheet on these films.
    func addFromCollection(_ tmdbIds: [Int]) {
        guard let collection, !tmdbIds.isEmpty else { return }
        let summary = CollectionSummary(collectionTmdbId: collection.collectionTmdbId, name: collection.name,
                                        posterUrl: collection.posterUrl, ownedCount: collection.ownedCount,
                                        totalCount: collection.totalCount)
        collectionAdd = CollectionAddTarget(summary: summary, tmdbIds: tmdbIds)
    }

    /// "Monitor whole collection": `PATCH /api/v1/library/{id}` `{monitored}` on
    /// every film already in the library (MovieCollectionTab v1).
    func monitorCollection(_ on: Bool) async {
        guard let client, let collection else { return }
        let ids = CollectionProgress.ownedLibraryIds(collection)
        guard !ids.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { try? await client.updateItem(id: id, ItemUpdate(monitored: on)) }
            }
        }
        await reload()
    }
}
