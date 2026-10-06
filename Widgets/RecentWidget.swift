import SwiftUI
import WidgetKit
import FusionhaKit

/// "Recently added": the latest imports (Activity › History), as posters.
struct RecentProvider: TimelineProvider {
    static let kind = "RecentlyAdded"

    func placeholder(in context: Context) -> RecentEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        let run = WidgetRun(kind: Self.kind, family: context.family, call: "snapshot")
        Task { completion(await Self.fetch(family: context.family, run: run)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        let run = WidgetRun(kind: Self.kind, family: context.family)
        Task {
            let entry = await Self.fetch(family: context.family, run: run)
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(45 * 60))))
        }
    }

    static func fetch(family: WidgetFamily, run: WidgetRun) async -> RecentEntry {
        var entry = await load(family: family, run: run)
        run.finish(timedOut: false)
        entry.runId = run.id
        return entry
    }

    private static func load(family: WidgetFamily, run: WidgetRun) async -> RecentEntry {
        guard let client = CredentialStore.client() else {
            run.fail(APIError.notSignedIn)
            return RecentEntry(date: .now, rows: [], signedIn: false, failed: false)
        }
        run.stage("history")
        let limit = family == .systemSmall ? 1 : (family == .systemMedium ? 5 : 8)
        do {
            let rows = try await WidgetLoader.recent(client, limit: limit, posterSize: family == .systemSmall ? "w92" : "w154",
                                                     deadline: run.deadline)
            return RecentEntry(date: .now, rows: rows, signedIn: true, failed: false)
        } catch {
            run.fail(error)
            return RecentEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
    }
}

struct RecentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RecentProvider.kind, provider: RecentProvider()) { entry in
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
        WidgetJournal.markDrawn(entry.runId)
        return RecentWidgetView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(family == .systemSmall
                       ? (WidgetLink.item(entry.rows.first?.item.itemId) ?? WidgetLink.library)
                       : WidgetLink.library)
    }
}
