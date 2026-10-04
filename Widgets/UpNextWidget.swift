import SwiftUI
import WidgetKit
import FusionhaKit

/// "Up next": the next airing episodes and releases from the Calendar.
struct UpNextProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpNextEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        Task { completion(await Self.fetch(family: context.family)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        Task {
            let entry = await Self.fetch(family: context.family)
            let refresh = WidgetLoader.nextRefresh(idleMinutes: 60, nextAir: entry.rows.first?.item.airDate)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    static func fetch(family: WidgetFamily) async -> UpNextEntry {
        guard let client = CredentialStore.client() else {
            return UpNextEntry(date: .now, rows: [], signedIn: false, failed: false)
        }
        let limit = family == .systemSmall ? 1 : (family == .systemMedium ? 3 : 6)
        do {
            let rows = try await WidgetLoader.upNext(client, limit: limit, posterSize: "w92")
            return UpNextEntry(date: .now, rows: rows, signedIn: true, failed: false)
        } catch {
            return UpNextEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
    }
}

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpNext", provider: UpNextProvider()) { entry in
            UpNextWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Up next")
        .description("The next episodes and releases on your fusionha calendar.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct UpNextWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UpNextEntry

    var body: some View {
        UpNextWidgetView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(family == .systemSmall
                       ? (WidgetLink.item(entry.rows.first?.item.itemId) ?? WidgetLink.calendar)
                       : WidgetLink.calendar)
    }
}
