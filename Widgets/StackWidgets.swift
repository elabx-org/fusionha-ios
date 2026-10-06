import SwiftUI
import WidgetKit
import FusionhaKit

// The single-view widgets for a Smart Stack: each is one view of the paged
// Downloads widget on its own, so the owner can stack them and let the system
// rotate (Up next and Recently added are their own widgets already; Wanted
// stays in the paged widget). Plain `StaticConfiguration`s, like Downloads:
// they render on a build signed without the App Group.

struct DownloadingWidget: Widget {
    var body: some WidgetConfiguration { StackWidgetConfiguration.make(.downloading) }
}

struct LibraryWidget: Widget {
    var body: some WidgetConfiguration { StackWidgetConfiguration.make(.library) }
}

struct IndexersWidget: Widget {
    var body: some WidgetConfiguration { StackWidgetConfiguration.make(.indexers) }
}

struct RequestsWidget: Widget {
    var body: some WidgetConfiguration { StackWidgetConfiguration.make(.requests) }
}

enum StackWidgetConfiguration {
    static func make(_ stack: WidgetStack) -> some WidgetConfiguration {
        StaticConfiguration(kind: stack.kind, provider: StackPageProvider(stack: stack)) { entry in
            StackWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(stack.displayName)
        .description(stack.summary)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct StackWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DownloadsEntry

    var body: some View {
        WidgetJournal.markDrawn(entry.runId)
        return WidgetStackView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(url)
    }

    /// Small: the top download's title while downloading, else the view's
    /// screen. Medium and large: the view's screen (rows link to their items).
    private var url: URL {
        if family == .systemSmall, entry.page == .downloading, let row = entry.rows.first {
            return WidgetLink.item(row.itemId, fallback: .activity)
        }
        return WidgetRoute.page(entry.page).url
    }
}
