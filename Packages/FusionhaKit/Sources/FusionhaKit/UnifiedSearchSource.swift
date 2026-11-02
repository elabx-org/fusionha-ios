import Foundation

/// Where the unified search's provider lanes come from: the server's
/// `GET /search/unified` for the library and TMDB plus TheTVDB and the id
/// lookup (`ServerUnifiedSearchSource`, fusionha 0.4.236+), or the older
/// client fan-out over `/search`, `/search/tvdb` and `/search/by-id`
/// (`ClientUnifiedSearchSource`).
///
/// The stream yields the whole provider side after each change (a provider
/// answered, was skipped or failed) and finishes when every provider settled.
/// Stopping iteration (the term changed) cancels the in-flight calls.
public protocol UnifiedSearchSource: Sendable {
    /// `kind` is the page's kind filter (All / Movies / Series / Anime).
    func lanes(for term: String, kind: SearchKind) -> AsyncStream<UnifiedSearchLanes>
}

/// The client-side fan-out: TMDB (`/search` with the kind) and TheTVDB (not for
/// Movies) run concurrently, and
/// an id-shaped term also asks the id lookup. A provider without a key (409)
/// is skipped silently; each provider's rows land as soon as it answers.
public struct ClientUnifiedSearchSource: UnifiedSearchSource {
    let client: APIClient

    public init(client: APIClient) {
        self.client = client
    }

    public func lanes(for term: String, kind: SearchKind) -> AsyncStream<UnifiedSearchLanes> {
        let client = self.client
        let idKinds = Self.idKinds(SearchIdQuery.parse(term), kind: kind)
        let asked = UnifiedSearchProvider.asked(for: kind)
        return AsyncStream { continuation in
            let task = Task {
                var acc = UnifiedSearchAccumulator(pending: asked)
                await withTaskGroup(of: UnifiedSearchArrival.self) { group in
                    group.addTask { await Self.tmdb(client, term, kind) }
                    if asked.contains(.tvdb) {
                        group.addTask { await Self.tvdb(client, term) }
                    }
                    for (id, idKind) in idKinds {
                        group.addTask { await Self.byId(client, id, idKind) }
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

    /// The id lookups to make: each kind the id can be, narrowed to the filter.
    static func idKinds(_ query: SearchIdQuery?, kind: SearchKind) -> [(String, SearchKind)] {
        guard let query else { return [] }
        let kinds = kind == .all ? query.kinds
            : query.kinds.filter { $0 == (kind == .movie ? .movie : .series) }
        return kinds.map { (query.id, kind == .anime ? .anime : $0) }
    }

    static func tmdb(_ client: APIClient, _ term: String, _ kind: SearchKind) async -> UnifiedSearchArrival {
        do {
            return .tmdb(try await client.search(term: term, kind: kind))
        } catch {
            return isNotConfigured(error) ? .unavailable(.tmdb) : .failed(.tmdb)
        }
    }

    static func tvdb(_ client: APIClient, _ term: String) async -> UnifiedSearchArrival {
        do {
            return .tvdb(try await client.searchTVDB(term: term))
        } catch {
            return isNotConfigured(error) ? .unavailable(.tvdb) : .failed(.tvdb)
        }
    }

    /// 404 (nothing there) and 422 (not an id after all) just mean no exact match.
    static func byId(_ client: APIClient, _ id: String, _ kind: SearchKind) async -> UnifiedSearchArrival {
        guard let hit = try? await client.searchById(id, kind: kind) else { return .none }
        return .exact([hit])
    }

    /// 409 `tmdb_not_configured` / `tvdb_not_configured`: no API key.
    static func isNotConfigured(_ error: Error) -> Bool {
        if case APIError.http(status: 409, body: let body) = error, body.contains("not_configured") { return true }
        return false
    }
}

/// One provider call's answer, for the sources' task groups.
enum UnifiedSearchArrival: Sendable {
    case unified(UnifiedSearchResponse)
    case tmdb([MediaSearchResult])
    case tvdb([TvdbSearchResult])
    case exact([MediaSearchResult])
    case unavailable(UnifiedSearchProvider)
    case failed(UnifiedSearchProvider)
    case none
}

extension UnifiedSearchAccumulator {
    /// Applies one arrival; false when it changed nothing.
    mutating func receive(_ arrival: UnifiedSearchArrival) -> Bool {
        switch arrival {
        case .unified(let response): receive(unified: response)
        case .tmdb(let rows): receive(tmdb: rows)
        case .tvdb(let rows): receive(tvdb: rows)
        case .exact(let rows): receive(exact: rows)
        case .unavailable(let p): unavailable(p)
        case .failed(let p): fail(p)
        case .none: return false
        }
        return true
    }
}
