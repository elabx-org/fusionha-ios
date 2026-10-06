import Foundation
import WidgetKit
import FusionhaKit

/// The Smart Stack gallery's entries, per family, loaded through the widget
/// extension's own fetchers (`WidgetStackLoader.fill`, `WidgetLoader`).
struct WidgetStackGalleryData {
    var stack: [WidgetFamily: DownloadsEntry] = [:]
    var upNext: [WidgetFamily: UpNextEntry] = [:]
    var recent: [WidgetFamily: RecentEntry] = [:]

    static func load(_ variant: WidgetStackGalleryView.Variant) async -> WidgetStackGalleryData {
        var data = WidgetStackGalleryData()
        guard let server = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_SERVER"].flatMap(URL.init(string:)) else {
            return data
        }
        let client = APIClient(baseURL: server, token: "screenshot")
        for family in WidgetStackGalleryView.families {
            switch variant {
            case .upnext:
                let feed = try? await WidgetLoader.upNextFeed(client, limit: limit(family, 1, 4, 4), posterSize: "w154")
                data.upNext[family] = UpNextEntry(date: .now, rows: feed?.rows ?? [], signedIn: true, failed: false,
                                                  weekCount: feed?.week)
            case .recent:
                let rows = (try? await WidgetLoader.recent(client, limit: limit(family, 1, 8, 8),
                                                           posterSize: family == .systemSmall ? "w92" : "w154")) ?? []
                data.recent[family] = RecentEntry(date: .now, rows: rows, signedIn: true, failed: false)
            default:
                guard let stack = variant.stack else { continue }
                var entry = WidgetStackLoader.blank(stack)
                await WidgetStackLoader.fill(stack, into: &entry, client, family: family)
                data.stack[family] = entry
            }
        }
        return data
    }

    private static func limit(_ family: WidgetFamily, _ small: Int, _ medium: Int, _ large: Int) -> Int {
        family == .systemSmall ? small : (family == .systemMedium ? medium : large)
    }

    /// The small widget's other state: idle Downloading, a timed-out Library
    /// or Indexers (with its diagnostic), Requests for an account without approve rights.
    static func alternate(_ stack: WidgetStack) -> DownloadsEntry {
        var entry = WidgetStackLoader.blank(stack)
        switch stack {
        case .downloading:
            break
        case .requests:
            entry.restricted = true
        case .library, .indexers:
            entry.pageError = "timeout 6s"
            entry.diagnostic = WidgetRunLog(stage: "page", page: stack.page.rawValue, outcome: .timedOut,
                                            error: "timeout 6s", seconds: 8).line
        }
        return entry
    }
}
