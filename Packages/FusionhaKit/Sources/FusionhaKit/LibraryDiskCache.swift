import Foundation

/// The last `GET /api/v1/library` answer, kept on this phone (Caches, one
/// file per server) so a cold launch draws the library at once and refreshes
/// it from the server behind. The cache is a copy of the server's JSON, never
/// edited locally; signing out or "Reset cache" removes it.
public enum LibraryDiskCache {
    static func directory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("library", isDirectory: true)
    }

    static func fileURL(server: URL) -> URL? {
        let key = (server.host ?? "server") + (server.port.map { "-\($0)" } ?? "") + server.path
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        return directory()?.appendingPathComponent("library-\(String(safe)).json")
    }

    /// The cached library for this server, or nil (none yet, or unreadable).
    public static func load(server: URL) -> [MediaItem]? {
        guard let url = fileURL(server: server), let data = try? Data(contentsOf: url) else { return nil }
        return try? APIClient.decoder.decode([MediaItem].self, from: data)
    }

    public static func save(_ data: Data, server: URL) {
        guard let dir = directory(), let url = fileURL(server: server) else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    public static func clear() {
        guard let dir = directory() else { return }
        try? FileManager.default.removeItem(at: dir)
    }
}

extension APIClient {
    /// The library with its raw JSON, so the caller can keep the answer on disk.
    public func libraryWithData() async throws -> (items: [MediaItem], data: Data) {
        let (body, _) = try await self.data(for: request(method: "GET", path: "/api/v1/library", query: []))
        return (try Self.decoder.decode([MediaItem].self, from: body), body)
    }
}
