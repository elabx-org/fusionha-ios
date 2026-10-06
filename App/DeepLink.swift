import Foundation

/// `fusionha://` deep links from the widgets, the Live Activity and notifications:
/// `activity`, `calendar`, `library`, `wanted`, `discover` switch tabs (with an
/// optional sub-tab: `activity/indexers`, `discover/requests`), and `item/{id}`
/// opens that title's detail sheet.
extension AppModel {
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "fusionha" else { return }
        let path = url.pathComponents.filter { $0 != "/" }
        switch url.host() ?? "" {
        case "activity" where !requestScoped:
            pendingActivityTab = path.first.flatMap(ActivityTab.init(rawValue:))
            tab = .activity
        case "calendar" where !requestScoped: tab = .calendar
        case "library" where !requestScoped: tab = .library
        case "wanted" where !requestScoped: tab = .wanted
        case "discover":
            pendingDiscoverTab = path.first.flatMap(DiscoverTab.init(rawValue:))
            tab = requestScoped && pendingDiscoverTab == .requests ? .requests : .discover
        case "item":
            guard let id = path.first.flatMap(Int.init), !requestScoped else { return }
            showingOmni = false
            presentedItem = ItemRef(id: id)
        default: break
        }
    }
}
