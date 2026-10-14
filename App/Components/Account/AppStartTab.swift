import Foundation

/// Which tab the app opens on (Account › This iPhone › Open on), stored on
/// this phone. "Last used" reopens the tab you were on.
enum AppStartTab: String, CaseIterable, Identifiable {
    case library, discover, calendar, activity, wanted, last

    static let key = "app.openOn"
    static let lastKey = "app.lastTab"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .library: return "Library"
        case .discover: return "Discover"
        case .calendar: return "Calendar"
        case .activity: return "Activity"
        case .wanted: return "Wanted"
        case .last: return "Last used"
        }
    }

    static var current: AppStartTab {
        UserDefaults.standard.string(forKey: key).flatMap(AppStartTab.init(rawValue:)) ?? .library
    }

    /// The tab to open at launch.
    static func launchTab() -> AppTab {
        let choice = current == .last
            ? UserDefaults.standard.string(forKey: lastKey).flatMap(AppStartTab.init(rawValue:)) ?? .library
            : current
        switch choice {
        case .discover: return .discover
        case .calendar: return .calendar
        case .activity, .wanted: return .activity
        case .library, .last: return .library
        }
    }

    /// Wanted is an Activity sub-tab, so "Open on Wanted" picks it there.
    static func launchActivityTab() -> ActivityTab? {
        current == .wanted ? .wanted : nil
    }

    /// Remembers the tab in use, for "Last used".
    static func remember(_ tab: AppTab) {
        let raw: String?
        switch tab {
        case .library: raw = "library"
        case .discover: raw = "discover"
        case .calendar: raw = "calendar"
        case .activity: raw = "activity"
        case .requests, .you, .search: raw = nil
        }
        if let raw { UserDefaults.standard.set(raw, forKey: lastKey) }
    }
}
