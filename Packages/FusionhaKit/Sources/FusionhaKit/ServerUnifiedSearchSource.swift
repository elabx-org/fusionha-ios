import Foundation

/// The unified search over the server's `GET /search/unified` (fusionha
/// 0.4.236): one call answers the library lane and TMDB, with how TMDB went
/// (`ok`, `skipped`, `timeout`, `unavailable`, `not_configured`). TheTVDB (not
/// for Movies) and an id-shaped term's lookup still run beside it, as in the
/// client fan-out. A server without the route (404) falls back to `/search`.
///
/// The Search tab sends `.always`: the approved spec searches every provider
/// as you type, with no "Search to add" step.
public struct ServerUnifiedSearchSource: UnifiedSearchSource {
    let client: APIClient
    let tmdb: UnifiedTmdbMode

    public init(client: APIClient, tmdb: UnifiedTmdbMode = .always) {
        self.client = client
        self.tmdb = tmdb
    }

    public func lanes(for term: String, kind: SearchKind) -> AsyncStream<UnifiedSearchLanes> {
        let client = self.client
        let mode = self.tmdb
        let idKinds = ClientUnifiedSearchSource.idKinds(SearchIdQuery.parse(term), kind: kind)
        let asked = UnifiedSearchProvider.asked(for: kind)
        return AsyncStream { continuation in
            let task = Task {
                var acc = UnifiedSearchAccumulator(pending: asked)
                await withTaskGroup(of: UnifiedSearchArrival.self) { group in
                    group.addTask { await Self.unified(client, term, kind, mode) }
                    if asked.contains(.tvdb) {
                        group.addTask { await ClientUnifiedSearchSource.tvdb(client, term) }
                    }
                    for (id, idKind) in idKinds {
                        group.addTask { await ClientUnifiedSearchSource.byId(client, id, idKind) }
                    }
                    for await arrival in group {
                        guard !Task.isCancelled else { break }
                        guard acc.receive(arrival) else { continue }
                        continuation.yield(acc.lanes)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func unified(_ client: APIClient, _ term: String, _ kind: SearchKind,
                        _ mode: UnifiedTmdbMode) async -> UnifiedSearchArrival {
        do {
            return .unified(try await client.searchUnified(term: term, kind: kind, tmdb: mode))
        } catch {
            if case APIError.http(status: 404, body: _) = error {
                return await ClientUnifiedSearchSource.tmdb(client, term, kind)
            }
            return .failed(.tmdb)
        }
    }
}
