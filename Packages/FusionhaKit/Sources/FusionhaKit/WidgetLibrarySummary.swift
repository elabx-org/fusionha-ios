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
        for item in items {
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
        titles = items.count
    }

    /// 4K coverage, 0–100.
    public var fourKPercent: Int {
        titles > 0 ? Int((Double(fourKTitles) / Double(titles) * 100).rounded()) : 0
    }
}
