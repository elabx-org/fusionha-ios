import SwiftUI
import WidgetKit
import FusionhaKit

struct DownloadsProvider: TimelineProvider {
    func placeholder(in context: Context) -> DownloadsEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (DownloadsEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        Task { completion(await Self.fetch(family: context.family)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadsEntry>) -> Void) {
        Task {
            let entry = await Self.fetch(family: context.family)
            // Refresh sooner while something is downloading (the app also reloads on
            // change); when idle, every ~45 minutes or just after the next item airs.
            let refresh = entry.idle
                ? WidgetLoader.nextRefresh(idleMinutes: 45, nextAir: entry.upNext.first?.item.airDate)
                : Date.now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    static func fetch(family: WidgetFamily) async -> DownloadsEntry {
        guard let client = CredentialStore.client() else {
            return DownloadsEntry(date: .now, total: 0, rows: [], signedIn: false, failed: false,
                                  report: CredentialStore.sharingReport())
        }
        let large = family == .systemLarge
        return await WidgetLoader.downloads(
            client, limit: large ? 4 : 2,
            idleUpNext: family == .systemSmall ? 1 : (large ? 3 : 2),
            idleRecent: family == .systemSmall ? 1 : 5)
    }
}

struct DownloadsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Downloads", provider: DownloadsProvider()) { entry in
            DownloadsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Downloads")
        .description("What fusionha is downloading, or what's up next and just added when it's idle.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct DownloadsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DownloadsEntry

    var body: some View {
        DownloadsWidgetView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(url)
    }

    /// Idle small widgets open the item they show; everything else opens Activity
    /// (medium and large rows link to their own items).
    private var url: URL {
        guard entry.idle, family == .systemSmall else { return WidgetLink.activity }
        if let next = entry.upNext.first { return WidgetLink.item(next.item.itemId) ?? WidgetLink.calendar }
        if let latest = entry.recent.first { return WidgetLink.item(latest.item.itemId) ?? WidgetLink.library }
        return WidgetLink.activity
    }
}
