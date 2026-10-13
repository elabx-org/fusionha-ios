import Foundation

/// One page of a cursor-paged list (`/requests`, `/issues`): the items, and the
/// cursor for the next page from the `X-Next-Cursor` response header (nil on
/// the last page). A stale cursor answers `422 bad_cursor`.
public struct CursorPage<Item: Decodable & Sendable>: Sendable {
    public let items: [Item]
    public let nextCursor: String?

    public init(items: [Item], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

extension APIClient {
    /// GETs one page of a header-cursor list. `limit` is 1-200 on the server.
    func cursorPage<Item: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [],
                                                limit: Int, cursor: String?) async throws -> CursorPage<Item> {
        var items = query
        items.append(URLQueryItem(name: "limit", value: "\(min(max(limit, 1), 200))"))
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        let (data, http) = try await data(for: request(method: "GET", path: path, query: items))
        let next = http.value(forHTTPHeaderField: "X-Next-Cursor").flatMap { $0.isEmpty ? nil : $0 }
        return CursorPage(items: try Self.decoder.decode([Item].self, from: data), nextCursor: next)
    }
}
