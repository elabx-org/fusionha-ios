import SwiftUI
import WidgetKit
import FusionhaKit

/// The v2 widget gallery's data: Up next and Downloads from the mock server
/// through the extension's loaders; Needs you and the Live Activity staged
/// from the mock queue's titles and posters (the default mock holds nothing),
/// as the v2 mock stages its 17:16 holds.
struct V2WidgetGalleryData {
    var upNext: [WidgetFamily: UpNextEntry] = [:]
    var downloads = DownloadsEntry.placeholder
    var needs = NeedsYouEntry.placeholder
    var activities: [DownloadsActivityAttributes.ContentState] = []

    static func load() async -> V2WidgetGalleryData {
        var data = V2WidgetGalleryData()
        guard let server = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"].flatMap(URL.init(string:)) else {
            data.activities = V2WidgetGalleryStates.make(items: [], thumbs: [:])
            return data
        }
        let client = APIClient(baseURL: server, token: "screenshot")
        for family in [WidgetFamily.systemMedium, .systemLarge] {
            let limit = V2UpNextLayout.limit(family) ?? 4
            let feed = try? await WidgetLoader.upNextFeed(client, limit: limit,
                                                          posterSize: V2UpNextLayout.posterSize(family) ?? "w92")
            upNextEntry(feed, family: family, into: &data)
        }
        data.downloads = await WidgetLoader.downloads(client, limit: 2, idleUpNext: 0, idleRecent: 0)
        let items = (try? await client.queue(pageSize: 10).items) ?? []
        let posters = await WidgetLoader.fetchPosters(items.map(\.posterUrl), size: "w154")
        var thumbs: [String: Data] = [:]
        for (item, poster) in zip(items, posters) { thumbs["\(item.mediaItemId)"] = poster }
        data.needs = V2WidgetGalleryStates.needs(items: items, posters: posters)
        data.activities = V2WidgetGalleryStates.make(items: items, thumbs: thumbs)
        LiveActivityThumbs.current = thumbs
        return data
    }

    private static func upNextEntry(_ feed: (rows: [UpNextRow], week: Int)?, family: WidgetFamily,
                                    into data: inout V2WidgetGalleryData) {
        guard let feed else { return }
        data.upNext[family] = UpNextEntry(date: .now, rows: feed.rows, signedIn: true, failed: false, weekCount: feed.week)
    }
}
