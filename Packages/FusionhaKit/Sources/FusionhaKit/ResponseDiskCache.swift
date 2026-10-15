import Foundation
import CryptoKit

/// The last answer of each page-level GET (queue, calendar, wanted, history,
/// discover rails…), kept on this phone so a screen can draw at once on a
/// cold launch while the real request runs, as the web's query cache does.
/// Only JSON answers under `/api/v1/` are kept; sign-in, tokens and searches
/// never are. Signing out and Reset cache remove everything.
public enum ResponseDiskCache {
    private static let skipped = ["/api/v1/auth", "/api/v1/tokens", "/api/v1/library", "/api/v1/search",
                                  "/api/v1/backup", "/api/v1/users"]
    private static let lock = NSLock()
    nonisolated(unsafe) private static var lastWrite: [String: Date] = [:]
    /// A polled answer (the queue every 2s) is written at most this often.
    static let minInterval: TimeInterval = 10

    static func directory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("responses", isDirectory: true)
    }

    static func cacheable(_ url: URL) -> Bool {
        let path = url.path
        guard path.hasPrefix("/api/v1/") || url.path.contains("/api/v1/") else { return false }
        let tail = path.range(of: "/api/v1/").map { String(path[$0.lowerBound...]) } ?? path
        return !skipped.contains { tail.hasPrefix($0) } && !tail.contains("/search")
    }

    static func key(_ url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func fileURL(_ url: URL) -> URL? {
        directory()?.appendingPathComponent(key(url) + ".json")
    }

    static func read(_ url: URL) -> Data? {
        guard cacheable(url), let file = fileURL(url) else { return nil }
        return try? Data(contentsOf: file)
    }

    static func write(_ data: Data, for url: URL, response: HTTPURLResponse) {
        guard cacheable(url), let dir = directory(), let file = fileURL(url),
              (response.value(forHTTPHeaderField: "Content-Type") ?? "").contains("json") else { return }
        let k = key(url)
        let now = Date()
        lock.lock()
        let due = lastWrite[k].map { now.timeIntervalSince($0) >= minInterval } ?? true
        if due { lastWrite[k] = now }
        lock.unlock()
        guard due else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    public static func clear() {
        lock.lock()
        lastWrite = [:]
        lock.unlock()
        if let dir = directory() { try? FileManager.default.removeItem(at: dir) }
    }
}

struct NotCached: Error {}

extension APIClient {
    /// What `call` returned the last time it reached the server, read from
    /// this phone's cache without any network; nil when nothing is kept.
    /// `let cached = await client.cached { try await $0.queue() }`.
    public func cached<T>(_ call: (APIClient) async throws -> T) async -> T? {
        try? await call(cacheReader)
    }
}
