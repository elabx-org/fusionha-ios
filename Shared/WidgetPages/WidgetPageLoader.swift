import Foundation
import WidgetKit
import FusionhaKit

/// Builds the paged Downloads widget's entry: the queue (always, it decides
/// whether Downloading shows), then only the current page's data.
enum WidgetPageLoader {
    static func entry(_ client: APIClient, family: WidgetFamily, enabled: Set<WidgetPage>,
                      stored: WidgetPage?) async -> DownloadsEntry {
        let large = family == .systemLarge
        var entry = await WidgetLoader.downloads(client, limit: large ? 4 : 2, idleUpNext: 0, idleRecent: 0)
        guard entry.signedIn, !entry.failed else { return entry }
        let allowed = enabled.contains(.requests) ? await requestsAllowed(client) : false
        entry.pages = WidgetPage.available(enabled: enabled, downloading: !entry.idle, requestsAllowed: allowed)
        entry.page = WidgetPage.current(stored: stored, in: entry.pages)
        let page = entry.page
        await load(page, into: &entry, client, large: large)
        return entry
    }

    /// Fills one page's data (also used by the gallery to shoot every page).
    static func load(_ page: WidgetPage, into entry: inout DownloadsEntry, _ client: APIClient, large: Bool) async {
        switch page {
        case .downloading:
            break
        case .upNext:
            entry.upNext = (try? await WidgetLoader.upNext(client, limit: large ? 6 : 2, posterSize: "w92")) ?? []
        case .recent:
            entry.recent = (try? await WidgetLoader.recent(client, limit: large ? 8 : 5, posterSize: "w154")) ?? []
        case .library:
            entry.pageData.library = await WidgetPageFetch.library(client)
        case .indexers:
            entry.pageData.indexers = await WidgetPageFetch.indexers(client, top: large ? 4 : 2)
        case .wanted:
            let (summary, posters) = await WidgetPageFetch.wanted(client, rows: large ? 3 : 2)
            entry.pageData.wanted = summary
            entry.pageData.wantedPosters = posters
        case .requests:
            entry.pageData = await WidgetPageFetch.requests(client, rows: large ? 3 : 1, into: entry.pageData)
        }
    }

    /// Approvers and issue managers see Requests & issues (cached 6h).
    static func requestsAllowed(_ client: APIClient) async -> Bool {
        if let cached = WidgetPageStore.cached(Bool.self, "requestsAllowed", maxAge: 6 * 3600) { return cached }
        guard let me = try? await client.me() else { return false }
        let allowed = me.hasPermission("requests.approve") || me.hasPermission("issues.manage")
        WidgetPageStore.cache(allowed, "requestsAllowed")
        return allowed
    }
}
