import Foundation
import Observation
import FusionhaKit

/// The details the poster context menu drills into (seasons, episodes,
/// versions), fetched once a press has stayed put on a poster, so the menu
/// that opens at the end of the hold already has them. Kept briefly: a title
/// may change, and the next hold fetches again. Observed, so a menu that
/// opened before its detail arrived fills in.
@MainActor
@Observable
final class V2PosterMenuDetails {
    static let shared = V2PosterMenuDetails()

    private struct Entry {
        let detail: ItemDetail
        let loaded: Date
    }

    private var entries: [Int: Entry] = [:]
    @ObservationIgnored private var inflight: Set<Int> = []
    /// A detail older than this is fetched again on the next hold.
    @ObservationIgnored private let fresh: TimeInterval = 60
    @ObservationIgnored private let keep = 8

    /// The title's detail, if one is loaded (stale or not: a menu shows what it has).
    func detail(_ id: Int) -> ItemDetail? { entries[id]?.detail }

    /// Fetches `id` unless a fresh copy is here or one is on its way.
    func load(_ id: Int, client: APIClient?) {
        guard let client, !inflight.contains(id) else { return }
        if let entry = entries[id], Date().timeIntervalSince(entry.loaded) < fresh { return }
        inflight.insert(id)
        Task {
            let loaded = try? await client.item(id: id)
            inflight.remove(id)
            guard let loaded else { return }
            if entries.count >= keep, entries[id] == nil,
               let oldest = entries.min(by: { $0.value.loaded < $1.value.loaded }) {
                entries[oldest.key] = nil
            }
            entries[id] = Entry(detail: loaded, loaded: Date())
        }
    }
}
