import Foundation

// The paged Downloads widget (medium and large): which pages exist and the
// order they flick through. The page summaries live beside this file.

/// One view of the paged Downloads widget, in display order.
public enum WidgetPage: String, CaseIterable, Codable, Sendable, Hashable {
    case downloading, upNext = "upnext", recent, library, indexers, wanted, requests

    public var title: String {
        switch self {
        case .downloading: return "Downloading"
        case .upNext: return "Up next"
        case .recent: return "Recently added"
        case .library: return "Library"
        case .indexers: return "Indexers"
        case .wanted: return "Wanted"
        case .requests: return "Requests & issues"
        }
    }

    /// The pages to flick through: the enabled ones, in order. Downloading
    /// shows only while something downloads; Requests only for approvers or
    /// issue managers. Never empty: with nothing left, Up next stands in.
    public static func available(enabled: Set<WidgetPage>, downloading: Bool, requestsAllowed: Bool) -> [WidgetPage] {
        let pages = allCases.filter { page in
            guard enabled.contains(page) else { return false }
            switch page {
            case .downloading: return downloading
            case .requests: return requestsAllowed
            default: return true
            }
        }
        if pages.isEmpty { return downloading ? [.downloading] : [.upNext] }
        return pages
    }

    /// The stored page when it is still available, else the first page.
    public static func current(stored: WidgetPage?, in pages: [WidgetPage]) -> WidgetPage {
        if let stored, pages.contains(stored) { return stored }
        return pages.first ?? .upNext
    }

    /// The page after `page`, wrapping round.
    public static func next(after page: WidgetPage, in pages: [WidgetPage]) -> WidgetPage {
        guard let index = pages.firstIndex(of: page) else { return pages.first ?? page }
        return pages[(index + 1) % pages.count]
    }
}
