import Foundation
import FusionhaKit

/// A title's detail and its art's palette, fetched from the moment a poster
/// is pressed (and at the latest when a title opens), so the page has both
/// by the time it is built. Before, the fetch started only once the title's
/// view appeared, and on the open Duo the slide-in waits for both
/// (`V2OpenReadiness`): the tap seemed to lag. The detail is used once, by
/// the next `DetailStore` for that title, and only while fresh.
@MainActor
enum V2TitlePrefetch {
    private struct Entry {
        let task: Task<ItemDetail?, Never>
        let started: Date
    }

    private static var entries: [Int: Entry] = [:]
    /// A prefetch older than this is dropped (the title may have changed since).
    private static let fresh: TimeInterval = 20
    private static let keep = 4

    /// Starts fetching `id` (once while one is fresh), and its palette.
    static func start(_ id: Int, model: AppModel) {
        let seed = model.library.first { $0.id == id }
        if let art = PageArtSource.url(backdrop: seed?.backdropUrl, poster: seed?.posterUrl),
           ArtPaletteExtractor.shared.cached(art) == nil {
            Task { _ = await ArtPaletteExtractor.shared.colors(for: art) }
        }
        let now = Date()
        entries = entries.filter { now.timeIntervalSince($0.value.started) < fresh }
        guard entries[id] == nil, let client = model.client else { return }
        if entries.count >= keep, let oldest = entries.min(by: { $0.value.started < $1.value.started }) {
            entries[oldest.key] = nil
        }
        entries[id] = Entry(task: Task { try? await client.item(id: id) }, started: now)
    }

    /// The prefetched detail for `id` (waiting for one in flight), if fresh; used once.
    static func take(_ id: Int) async -> ItemDetail? {
        guard let entry = entries.removeValue(forKey: id),
              Date().timeIntervalSince(entry.started) < fresh else { return nil }
        return await entry.task.value
    }
}
