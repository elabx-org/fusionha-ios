import Foundation
import WidgetKit
import FusionhaKit

// Timeline entries for the home-screen widgets. In Shared so the app's debug
// widget gallery (CI screenshots) renders the same views with the same data.

struct DownloadsEntry: TimelineEntry, Sendable {
    struct Row: Hashable, Sendable {
        let itemId: Int
        let title: String
        let tier: QualityTier
        let fraction: Double
        let stalled: Bool
        let poster: Data?
        /// `12m left`, `Importing`; nil when unknown.
        var timeLeft: String? = nil
    }

    let date: Date
    let total: Int
    let rows: [Row]
    let signedIn: Bool
    let failed: Bool
    var report: String = ""
    /// Shown while nothing is downloading.
    var upNext: [UpNextRow] = []
    var recent: [RecentImportRow] = []
    /// The paged medium/large widget: the views to flick through, the one
    /// shown, and that view's data (only the current page is fetched).
    var pages: [WidgetPage] = []
    var page: WidgetPage = .downloading
    var pageData = WidgetPageData()
    /// Why the current page's data is missing (`timeout 6s`, `HTTP 502`): the
    /// page then shows a tap-to-retry line instead.
    var pageError: String?
    /// A failed, timed-out or killed reload, in a few monospaced words; nil
    /// after a clean one.
    var diagnostic: String?
    /// The journal record of the reload that built this entry (marked drawn
    /// when the entry view renders it).
    var runId: String?

    var idle: Bool { total == 0 && rows.isEmpty }

    static let placeholder = DownloadsEntry(
        date: .now, total: 2,
        rows: [
            Row(itemId: 0, title: "Dune: Part Two", tier: .uhd, fraction: 0.62, stalled: false, poster: nil),
            Row(itemId: 0, title: "Shōgun · S01E04", tier: .hd, fraction: 0.18, stalled: false, poster: nil),
        ],
        signedIn: true, failed: false,
        pages: [.downloading, .upNext, .recent, .library, .indexers, .wanted, .requests])
}

struct UpNextRow: Hashable, Sendable {
    let item: UpNextItem
    let poster: Data?
}

struct RecentImportRow: Hashable, Sendable {
    let item: RecentImport
    let poster: Data?
}

struct UpNextEntry: TimelineEntry {
    let date: Date
    let rows: [UpNextRow]
    let signedIn: Bool
    let failed: Bool
    /// The journal record of the reload that built this entry.
    var runId: String? = nil

    static let placeholder = UpNextEntry(date: .now, rows: WidgetSamples.upNext, signedIn: true, failed: false)
}

struct RecentEntry: TimelineEntry {
    let date: Date
    let rows: [RecentImportRow]
    let signedIn: Bool
    let failed: Bool
    /// The journal record of the reload that built this entry.
    var runId: String? = nil

    static let placeholder = RecentEntry(date: .now, rows: WidgetSamples.recent, signedIn: true, failed: false)
}
