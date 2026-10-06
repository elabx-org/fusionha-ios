import Foundation
import WidgetKit
import FusionhaKit

/// The single-view widgets' placeholders: what the Add Widget gallery shows
/// and what WidgetKit redacts while loading.
enum WidgetStackSamples {
    static func entry(_ stack: WidgetStack) -> DownloadsEntry {
        var entry = WidgetStackLoader.blank(stack)
        switch stack {
        case .downloading:
            var sample = DownloadsEntry.placeholder
            sample.page = .downloading
            sample.pages = [.downloading]
            return sample
        case .library:
            entry.pageData.library = library
        case .indexers:
            entry.pageData.indexers = indexers
        case .requests:
            entry.pageData.requests = requests
        }
        return entry
    }

    private static var library: WidgetLibrarySummary {
        var s = WidgetLibrarySummary()
        s.titles = 248
        s.versions = 311
        s.movies = 120
        s.series = 86
        s.anime = 42
        s.complete = 201
        s.downloading = 4
        s.missing = 31
        s.upcoming = 12
        s.fourKTitles = 63
        return s
    }

    private static var indexers: WidgetIndexerSummary {
        var s = WidgetIndexerSummary()
        s.healthy = 5
        s.backingOff = 1
        s.total = 6
        s.successPercent = 94
        s.grabs = 70
        s.queries = 1_300
        s.top = [
            WidgetIndexerRow(name: "NZBgeek", state: "healthy", successPercent: 97, grabs: 40, series: [3, 5, 2, 6, 4, 7, 5]),
            WidgetIndexerRow(name: "DrunkenSlug", state: "healthy", successPercent: 92, grabs: 22, series: [2, 1, 3, 2, 4, 3, 2]),
            WidgetIndexerRow(name: "Nyaa", state: "backoff", successPercent: 71, grabs: 8, series: [1, 0, 2, 1, 0, 1, 1]),
        ]
        return s
    }

    private static var requests: WidgetRequestsSummary {
        var s = WidgetRequestsSummary()
        s.pending = 3
        s.inProgress = 2
        s.openIssues = 1
        return s
    }
}
