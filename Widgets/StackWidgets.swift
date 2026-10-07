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

    /// Anywhere outside a row: the view's screen (Downloading → Activity,
    /// Library → Library, Indexers → Activity › Indexers, Requests & issues →
    /// Discover › Requests). Rows and posters carry their own item links.
    private var url: URL { WidgetRoute.page(entry.page).url }
}
