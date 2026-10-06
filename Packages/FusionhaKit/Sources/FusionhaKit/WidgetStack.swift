import Foundation

/// The single-view widgets made for a Smart Stack: each is one page of the
/// paged Downloads widget on its own (Up next and Recently added have their own
/// widgets already). The raw value is the WidgetKit kind; never change it, or
/// placed widgets disappear from the Home Screen.
public enum WidgetStack: String, CaseIterable, Sendable {
    case downloading = "Downloading"
    case library = "Library"
    case indexers = "Indexers"
    case requests = "Requests"

    public var kind: String { rawValue }

    public var page: WidgetPage {
        switch self {
        case .downloading: return .downloading
        case .library: return .library
        case .indexers: return .indexers
        case .requests: return .requests
        }
    }

    /// The widget gallery's name.
    public var displayName: String { page.title }

    /// The widget gallery's description.
    public var summary: String {
        switch self {
        case .downloading: return "What's downloading now, with progress and time left. Rises in a Smart Stack while something downloads."
        case .library: return "Titles, versions and 4K coverage across movies, series and anime."
        case .indexers: return "Indexer health and 7-day success rate, with the busiest indexers."
        case .requests: return "Requests awaiting approval and open issues. For approvers and issue managers."
        }
    }

    /// Minutes to the next reload after a clean load. Short only while
    /// downloads move (the app also reloads the widget when its queue changes).
    public func refreshMinutes(active: Bool) -> Double {
        switch self {
        case .downloading: return active ? 15 : 60
        case .library: return 120
        case .indexers: return 60
        case .requests: return 30
        }
    }

    /// The single-view widget that shows `page` (Wanted has none: it lives
    /// only in the paged Downloads widget).
    public static func kind(for page: WidgetPage) -> String {
        switch page {
        case .upNext: return "UpNext"
        case .recent: return "RecentlyAdded"
        case .wanted: return "Downloads"
        default: return allCases.first { $0.page == page }?.kind ?? "Downloads"
        }
    }

    /// After a failed or timed-out load.
    public static let retryMinutes: Double = 15
}
