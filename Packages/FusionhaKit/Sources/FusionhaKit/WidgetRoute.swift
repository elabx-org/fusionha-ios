import Foundation

/// Where a widget tap lands: `fusionha://item/{id}` or a tab
/// (`fusionha://activity`, `calendar`, `library`).
public enum WidgetRoute: Sendable, Hashable {
    case item(Int)
    case activity
    case calendar
    case library
    case wanted
    /// Activity › Indexers.
    case indexers
    /// Discover › Requests.
    case requests

    public var url: URL {
        switch self {
        case .item(let id): return URL(string: "fusionha://item/\(id)")!
        case .activity: return URL(string: "fusionha://activity")!
        case .calendar: return URL(string: "fusionha://calendar")!
        case .library: return URL(string: "fusionha://library")!
        case .wanted: return URL(string: "fusionha://wanted")!
        case .indexers: return URL(string: "fusionha://activity/indexers")!
        case .requests: return URL(string: "fusionha://discover/requests")!
        }
    }

    /// A paged widget's whole-widget URL (anywhere outside a row link).
    public static func page(_ page: WidgetPage) -> WidgetRoute {
        switch page {
        case .downloading: return .activity
        case .upNext: return .calendar
        case .recent, .library: return .library
        case .indexers: return .indexers
        case .wanted: return .wanted
        case .requests: return .requests
        }
    }

    /// The title's detail sheet, or `fallback` when the row has no usable id.
    /// Widget tiles always link somewhere so a tap never falls through to the
    /// widget's own URL (Activity on the Downloads widget).
    public static func item(_ id: Int?, fallback: WidgetRoute) -> WidgetRoute {
        guard let id, id > 0 else { return fallback }
        return .item(id)
    }

    /// The Downloads widget's whole-widget URL (anywhere outside a row link).
    /// Downloading → Activity. Idle small → the one title it shows. Idle
    /// medium/large → Library (Calendar when only Up next shows): idle shows no
    /// downloads, so Activity would be a surprising place to land.
    public static func downloads(idle: Bool, small: Bool, upNextIds: [Int], recentIds: [Int?]) -> WidgetRoute {
        guard idle else { return .activity }
        if small {
            if let next = upNextIds.first { return item(next, fallback: .calendar) }
            if let latest = recentIds.first { return item(latest, fallback: .library) }
            return .activity
        }
        if recentIds.isEmpty && !upNextIds.isEmpty { return .calendar }
        return .library
    }
}
