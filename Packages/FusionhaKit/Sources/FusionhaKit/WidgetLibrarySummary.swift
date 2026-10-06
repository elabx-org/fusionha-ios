import Foundation

/// The Library page: what the web's LibraryPulse card and stats sheet count.
public struct WidgetLibrarySummary: Codable, Sendable, Hashable {
    public var titles = 0
    public var versions = 0
    public var movies = 0
    public var series = 0
    /// Anime and non-anime animation, like the kind bar's pink segment.
    public var anime = 0
    public var complete = 0
    public var downloading = 0
    public var missing = 0
    public var upcoming = 0
    public var fourKTitles = 0

    public init() {}

    public init(_ items: [MediaItem]) {
        for item in items { add(item) }
    }

    public mutating func add(_ item: MediaItem) {
        titles += 1
        switch item.libraryKind {
        case .movie: movies += 1
        case .series: series += 1
        case .anime, .animation: anime += 1
        }
        switch item.cardStatus {
        case .complete: complete += 1
        case .downloading: downloading += 1
        case .missing: missing += 1
        case .upcoming: upcoming += 1
        }
        versions += item.editions.count
        if item.editions.contains(where: { $0.tier == .uhd }) { fourKTitles += 1 }
    }

    /// 4K coverage, 0–100.
    public var fourKPercent: Int {
        titles > 0 ? Int((Double(fourKTitles) / Double(titles) * 100).rounded()) : 0
    }

    /// Tallies a `GET /api/v1/library` body one item at a time, so the list is
    /// never held decoded. Items that don't decode are skipped and counted.
    public static func tally(_ data: Data) throws -> (summary: WidgetLibrarySummary, skipped: Int) {
        var summary = WidgetLibrarySummary()
        var skipped = 0
        try WidgetJSONArray.forEachElement(in: data) { element in
            if let item = try? APIClient.decoder.decode(MediaItem.self, from: element) {
                summary.add(item)
            } else {
                skipped += 1
            }
            if (summary.titles + skipped) % 256 == 0 { try Task.checkCancellation() }
        }
        return (summary, skipped)
    }
}

/// A response too big for the widget extension to read.
public struct WidgetPayloadTooLarge: Error, Equatable, Sendable {
    public let bytes: Int
}

extension APIClient {
    /// The Library page's summary without the library in memory: the body is
    /// downloaded to a file, mapped rather than loaded, and tallied item by item.
    public func widgetLibrarySummary(maxBytes: Int = 48 << 20) async throws -> WidgetLibrarySummary {
        let (file, response) = try await session.download(for: request(method: "GET", path: "/api/v1/library", query: []))
        defer { try? FileManager.default.removeItem(at: file) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw APIError.http(status: status, body: "") }
        let data = try Data(contentsOf: file, options: .alwaysMapped)
        guard data.count <= maxBytes else { throw WidgetPayloadTooLarge(bytes: data.count) }
        return try WidgetLibrarySummary.tally(data).summary
    }
}
