import SwiftUI
import WidgetKit
import FusionhaKit

/// "Recently added": the latest imports (Activity › History), as posters.
struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        Task { completion(await Self.fetch(family: context.family)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        Task {
            let entry = await Self.fetch(family: context.family)
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(45 * 60))))
        }
    }

    static func fetch(family: WidgetFamily) async -> RecentEntry {
        guard let client = CredentialStore.client() else {
            return RecentEntry(date: .now, rows: [], signedIn: false, failed: false)
        }
        let limit = family == .systemSmall ? 1 : (family == .systemMedium ? 5 : 8)
        do {
            let rows = try await WidgetLoader.recent(client, limit: limit, posterSize: family == .systemSmall ? "w92" : "w154")
            return RecentEntry(date: .now, rows: rows, signedIn: true, failed: false)
        } catch {
            return RecentEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
    }
}

struct RecentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RecentlyAdded", provider: RecentProvider()) { entry in
            RecentWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recently added")
        .description("The latest titles fusionha imported.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct RecentWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RecentEntry

    var body: some View {
        RecentWidgetView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(family == .systemSmall
                       ? (WidgetLink.item(entry.rows.first?.item.itemId) ?? WidgetLink.library)
                       : WidgetLink.library)
    }
}
