import SwiftUI
import WidgetKit
import FusionhaKit

/// Downloads: small shows the top download (or what's next / just added when
/// idle); medium and large flick through every view with the header's dots.
/// A `StaticConfiguration`, as before the paged views: the dots are a
/// `Button(intent:)`, which needs no configuration intent.
struct DownloadsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DownloadsProvider.kind, provider: DownloadsProvider()) { entry in
            DownloadsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Downloads")
        .description("Downloads, Up next, Recently added, Library, Indexers, Wanted and Requests in one widget. Tap the dots to switch views.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct DownloadsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DownloadsEntry

    var body: some View {
        WidgetJournal.markDrawn(entry.runId)
        return DownloadsWidgetView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(url)
    }

    /// Small: Activity while downloading, else the title it shows. Medium and
    /// large: the current view's screen (rows and posters link to their items).
    private var url: URL {
        guard family == .systemSmall else { return WidgetRoute.page(entry.page).url }
        return WidgetRoute.downloads(
            idle: entry.idle, small: true,
            upNextIds: entry.upNext.map(\.item.itemId),
            recentIds: entry.recent.map(\.item.itemId)).url
    }
}
