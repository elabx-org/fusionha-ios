import Foundation

/// Where the unified search's provider lanes come from. Today the client fans
/// out over `/search`, `/search/tvdb` and `/search/by-id`
/// (`ClientUnifiedSearchSource`); a later server `GET /search/unified` is one
/// more conforming type, with no UI change.
///
/// The stream yields the whole provider side after each change (a provider
/// answered, was skipped or failed) and finishes when every provider settled.
/// Stopping iteration (the term changed) cancels the in-flight calls.
public protocol UnifiedSearchSource: Sendable {
    func lanes(for term: String) -> AsyncStream<UnifiedSearchLanes>
}

/// The client-side fan-out: TMDB (`kind=all`) and TheTVDB run concurrently, and
/// an id-shaped term also asks the id lookup. A provider without a key (409)
/// is skipped silently; each provider's rows land as soon as it answers.
public struct ClientUnifiedSearchSource: UnifiedSearchSource {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    private enum Arrival: Sendable {
        case tmdb([MediaSearchResult])
        case tvdb([TvdbSearchResult])
        case exact([MediaSearchResult])
        case unavailable(UnifiedSearchProvider)
        case failed(UnifiedSearchProvider)
        case none
    }

    public func lanes(for term: String) -> AsyncStream<UnifiedSearchLanes> {
        let client = self.client
        let idQuery = SearchIdQuery.parse(term)
        return AsyncStream { continuation in
            let task = Task {
                var acc = UnifiedSearchAccumulator()
                await withTaskGroup(of: Arrival.self) { group in
                    group.addTask { await Self.tmdb(client, term) }
                    group.addTask { await Self.tvdb(client, term) }
                    if let idQuery {
                        for kind in idQuery.kinds {
                            group.addTask { await Self.byId(client, idQuery.id, kind) }
                        }
                    }
                    for await arrival in group {
                        guard !Task.isCancelled else { break }
                        switch arrival {
                        case .tmdb(let rows): acc.receive(tmdb: rows)
                        case .tvdb(let rows): acc.receive(tvdb: rows)
                        case .exact(let rows): acc.receive(exact: rows)
                        case .unavailable(let p): acc.unavailable(p)
                        case .failed(let p): acc.fail(p)
                        case .none: continue
                        }
                        continuation.yield(acc.lanes)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func tmdb(_ client: APIClient, _ term: String) async -> Arrival {
        do {
            return .tmdb(try await client.search(term: term, kind: .all))
        } catch {
            return isNotConfigured(error) ? .unavailable(.tmdb) : .failed(.tmdb)
        }
    }

    private static func tvdb(_ client: APIClient, _ term: String) async -> Arrival {
        do {
            return .tvdb(try await client.searchTVDB(term: term))
        } catch {
            return isNotConfigured(error) ? .unavailable(.tvdb) : .failed(.tvdb)
        }
    }

    /// 404 (nothing there) and 422 (not an id after all) just mean no exact match.
    private static func byId(_ client: APIClient, _ id: String, _ kind: SearchKind) async -> Arrival {
        guard let hit = try? await client.searchById(id, kind: kind) else { return .none }
        return .exact([hit])
    }

    /// 409 `tmdb_not_configured` / `tvdb_not_configured`: no API key.
    static func isNotConfigured(_ error: Error) -> Bool {
        if case APIError.http(status: 409, body: let body) = error, body.contains("not_configured") { return true }
        return false
    }
}
