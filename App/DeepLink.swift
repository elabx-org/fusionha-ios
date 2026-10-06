import Foundation
import FusionhaKit

/// `fusionha://` deep links from the widgets, the Live Activity and notifications:
/// `activity`, `calendar`, `library`, `wanted`, `discover` switch tabs (with an
/// optional sub-tab: `activity/indexers`, `discover/requests`), and `item/{id}`
/// opens that title's detail sheet.
///
/// A link is received at the app's root (`FusionhaApp`), which exists from the
/// first frame of a cold launch, and kept in `pendingLink` until the shell is on
/// screen and signed in; `RootView` then applies it. Anything presented over
/// the shell (Add, Account, Settings, the omni search, another title) is closed
/// first, since a sheet can't present over another one.
extension AppModel {
    func receiveDeepLink(_ url: URL) {
        guard url.scheme == "fusionha" else { return }
        DeepLinkProbe.log("received \(url.absoluteString)")
        pendingLink = url
    }

    /// Applies the pending link, if the shell can show it now.
    func applyPendingLink() async {
        guard credentials != nil, let url = pendingLink else { return }
        pendingLink = nil
        let closed = closePresentations(keeping: itemId(in: url))
        // Let a cold launch's first frame, or the sheets just closed, settle:
        // presenting during either is silently dropped.
        try? await Task.sleep(for: .milliseconds(closed ? 700 : 300))
        handleDeepLink(url)
        DeepLinkProbe.log("applied \(url.absoluteString) tab=\(tab) item=\(presentedItem?.id ?? 0)")
    }

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
            guard let id = itemId(in: url), !requestScoped else { return }
            presentedItem = ItemRef(id: id)
        default: break
        }
    }

    private func itemId(in url: URL) -> Int? {
        guard url.host() == "item" else { return nil }
        return url.pathComponents.filter { $0 != "/" }.first.flatMap(Int.init)
    }

    /// Closes what covers the shell (keeping the title the link opens, if it
    /// is already showing); true when something was open.
    private func closePresentations(keeping itemId: Int?) -> Bool {
        var closed = avatarCoverOpen
        if showingAdd { showingAdd = false; closed = true }
        if showingAccount { showingAccount = false; closed = true }
        if deleteTarget != nil { deleteTarget = nil; closed = true }
        if showingOmni { showingOmni = false; closed = true }
        if let open = presentedItem, open.id != itemId { presentedItem = nil; closed = true }
        linkCloseTick += 1
        return closed
    }
}
