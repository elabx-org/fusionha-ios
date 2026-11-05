import Foundation
import FusionhaKit

/// The network mark of library titles that only came with a `MediaItem` (the
/// Library hero cards), read from each title's detail once per session and
/// kept in memory, so scrolling and re-renders never refetch. A title with no
/// logo is remembered too; a failed fetch is not, so it retries next time.
@MainActor
final class V2StudioMarkCache {
    static let shared = V2StudioMarkCache()

    private struct Key: Hashable {
        let server: URL
        let item: Int
    }

    /// The pick per title; a stored `nil` is "no logo".
    private var known: [Key: Studio?] = [:]
    private var inflight: [Key: Task<Studio??, Never>] = [:]

    /// The title's mark if it is already known (outer nil = not fetched yet).
    func cached(_ item: Int, server: URL) -> Studio?? {
        known[Key(server: server, item: item)]
    }

    /// The title's mark, fetching its detail the first time; concurrent asks
    /// for one title share one request.
    func mark(for item: Int, client: APIClient) async -> Studio? {
        let key = Key(server: client.baseURL, item: item)
        if let hit = known[key] { return hit }
        let task = inflight[key] ?? Task<Studio??, Never> {
            guard let detail = try? await client.item(id: item) else { return .none }
            return .some(detail.networkMark)
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        guard let result else { return nil }
        known.updateValue(result, forKey: key)
        return result
    }
}
