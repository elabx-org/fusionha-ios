import SwiftUI
import WidgetKit
import FusionhaKit

/// "Recently added": the latest imports (Activity › History), as posters. A
/// fresh import raises it in a Smart Stack; the score fades as it ages
/// (`WidgetStackRelevance.recentSteps`), within one reload.
struct RecentProvider: TimelineProvider {
    static let kind = "RecentlyAdded"

    func placeholder(in context: Context) -> RecentEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        let family = context.family
        WidgetProviderRun.snapshot(kind: Self.kind, family: family, completion: completion,
                                   fallback: Self.watchdogEntry,
                                   fetch: { await Self.fetch(family: family, run: $0) })
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        let family = context.family
        WidgetProviderRun.timeline(kind: Self.kind, family: family, completion: completion,
                                   fallback: Self.watchdogEntry) { run in
            let entry = await Self.fetch(family: family, run: run)
            let refresh = Date.now.addingTimeInterval((entry.failed ? WidgetStack.retryMinutes : 45) * 60)
            let newest = entry.rows.compactMap(\.item.importedAt).max()
            let steps = WidgetStackRelevance.recentSteps(newest: entry.failed ? nil : newest, now: entry.date, until: refresh)
            let entries: [RecentEntry] = WidgetProviderRun.steps(steps) { date, score in
                var step = RecentEntry(date: date, rows: entry.rows, signedIn: entry.signedIn, failed: entry.failed,
                                       runId: entry.runId)
                step.relevanceScore = score
                return step
            }
            return Timeline(entries: entries, policy: .after(refresh))
        }
    }

    static func fetch(family: WidgetFamily, run: WidgetRun) async -> RecentEntry {
        var entry: RecentEntry
        var timedOut = false
        do {
            entry = try await withTimeout(seconds: WidgetRun.budget) { await load(family: family, run: run) }
        } catch {
            timedOut = true
            entry = RecentEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
        run.finish(timedOut: timedOut)
        entry.runId = run.id
        return entry
    }

    private static func load(family: WidgetFamily, run: WidgetRun) async -> RecentEntry {
        run.stage("auth")
        guard let client = CredentialStore.client() else {
            run.fail(APIError.notSignedIn)
            return RecentEntry(date: .now, rows: [], signedIn: false, failed: false)
        }
        run.stage("history")
        let limit = family == .systemSmall ? 1 : 8
        do {
            let rows = try await WidgetLoader.recent(client, limit: limit, posterSize: family == .systemSmall ? WidgetLoader.heroPosterSize : "w154",
                                                     deadline: run.deadline)
            return RecentEntry(date: .now, rows: rows, signedIn: true, failed: false)
        } catch {
            run.fail(error)
            return RecentEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
    }

    static func watchdogEntry(_ run: WidgetRun) -> RecentEntry {
        WidgetProviderRun.watchdogLog(run)
        return RecentEntry(date: .now, rows: [], signedIn: true, failed: true, runId: run.id,
                           relevanceScore: WidgetStackRelevance.low)
    }
}

struct RecentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: RecentProvider.kind, provider: RecentProvider()) { entry in
            RecentWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recently added")
        .description("The latest titles fusionha imported, with their HD and 4K versions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The small poster runs edge to edge; medium and large pad by the margins.
        .contentMarginsDisabled()
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
