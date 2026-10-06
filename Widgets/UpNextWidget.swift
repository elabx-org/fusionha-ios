import SwiftUI
import WidgetKit
import FusionhaKit

/// "Up next": the next airing episodes and releases from the Calendar.
struct UpNextProvider: TimelineProvider {
    static let kind = "UpNext"

    func placeholder(in context: Context) -> UpNextEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        let run = WidgetRun(kind: Self.kind, family: context.family, call: "snapshot")
        Task { completion(await Self.fetch(family: context.family, run: run)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        let run = WidgetRun(kind: Self.kind, family: context.family)
        Task {
            let entry = await Self.fetch(family: context.family, run: run)
            let refresh = WidgetLoader.nextRefresh(idleMinutes: 60, nextAir: entry.rows.first?.item.airDate)
            completion(Timeline(entries: [entry], policy: .after(refresh)))
        }
    }

    static func fetch(family: WidgetFamily, run: WidgetRun) async -> UpNextEntry {
        var entry = await load(family: family, run: run)
        run.finish(timedOut: false)
        entry.runId = run.id
        return entry
    }

    private static func load(family: WidgetFamily, run: WidgetRun) async -> UpNextEntry {
        guard let client = CredentialStore.client() else {
            run.fail(APIError.notSignedIn)
            return UpNextEntry(date: .now, rows: [], signedIn: false, failed: false)
        }
        run.stage("calendar")
        let limit = family == .systemSmall ? 1 : (family == .systemMedium ? 3 : 6)
        do {
            let rows = try await WidgetLoader.upNext(client, limit: limit, posterSize: "w92", deadline: run.deadline)
            return UpNextEntry(date: .now, rows: rows, signedIn: true, failed: false)
        } catch {
            run.fail(error)
            return UpNextEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
    }
}

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: UpNextProvider.kind, provider: UpNextProvider()) { entry in
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
        WidgetJournal.markDrawn(entry.runId)
        return UpNextWidgetView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(family == .systemSmall
                       ? (WidgetLink.item(entry.rows.first?.item.itemId) ?? WidgetLink.calendar)
                       : WidgetLink.calendar)
    }
}
