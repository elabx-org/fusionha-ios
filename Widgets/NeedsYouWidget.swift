import SwiftUI
import WidgetKit
import FusionhaKit

/// v2 "Needs you": the downloads waiting on the person (held imports, failed
/// or stuck downloads), from the same queue call as Downloads. Every 15
/// minutes while something waits (the app also reloads widgets when its
/// queue changes), else hourly. Only in v2's bundle (`FusionhaWidgetsBundle`).
struct NeedsYouProvider: TimelineProvider {
    static let kind = NeedsYouEntry.kind

    func placeholder(in context: Context) -> NeedsYouEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NeedsYouEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        let family = context.family
        WidgetProviderRun.snapshot(kind: Self.kind, family: family, completion: completion,
                                   fallback: Self.watchdogEntry,
                                   fetch: { await Self.fetch(family: family, run: $0) })
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NeedsYouEntry>) -> Void) {
        let family = context.family
        WidgetProviderRun.timeline(kind: Self.kind, family: family, completion: completion,
                                   fallback: Self.watchdogEntry) { run in
            let entry = await Self.fetch(family: family, run: run)
            let minutes = entry.failed ? WidgetStack.retryMinutes : (entry.needCount > 0 ? 15 : 60)
            return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(minutes * 60)))
        }
    }

    static func fetch(family: WidgetFamily, run: WidgetRun) async -> NeedsYouEntry {
        run.stage("auth")
        guard let client = CredentialStore.client() else {
            run.fail(APIError.notSignedIn)
            run.finish(timedOut: false)
            return NeedsYouEntry(date: .now, signedIn: false, runId: run.id)
        }
        run.stage("queue")
        var entry: NeedsYouEntry
        var timedOut = false
        do {
            entry = try await withTimeout(seconds: WidgetRun.budget) {
                await NeedsYouLoader.entry(client, posters: family == .systemSmall ? 0 : 3, deadline: run.deadline)
            }
        } catch {
            timedOut = true
            entry = NeedsYouEntry(date: .now, failed: true)
        }
        if entry.failed && !timedOut { run.fail(WidgetRunNote("queue unreachable")) }
        run.finish(timedOut: timedOut)
        entry.runId = run.id
        if entry.failed { entry.relevanceScore = WidgetStackRelevance.low }
        return entry
    }

    static func watchdogEntry(_ run: WidgetRun) -> NeedsYouEntry {
        WidgetProviderRun.watchdogLog(run)
        return NeedsYouEntry(date: .now, failed: true, runId: run.id, relevanceScore: WidgetStackRelevance.low)
    }
}

struct NeedsYouWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: NeedsYouProvider.kind, provider: NeedsYouProvider()) { entry in
            NeedsYouWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Needs you")
        .description("Held imports and failed downloads waiting on you. Rises in a Smart Stack while something waits.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct NeedsYouWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NeedsYouEntry

    var body: some View {
        WidgetJournal.markDrawn(entry.runId)
        return NeedsYouWidgetView(entry: entry, family: family)
            .fusionhaWidgetBackground()
            .widgetURL(family == .systemSmall && entry.needCount == 1
                       ? (WidgetLink.item(entry.rows.first?.line.mediaItemId) ?? WidgetLink.activity)
                       : WidgetLink.activity)
    }
}
