import SwiftUI
import WidgetKit
import FusionhaKit

/// "Up next": the next airing episodes and releases from the Calendar. The
/// timeline repeats the entry at each Smart Stack step as the next airing
/// nears (`WidgetStackRelevance.upNextSteps`), and reloads just after it airs.
struct UpNextProvider: TimelineProvider {
    static let kind = "UpNext"

    func placeholder(in context: Context) -> UpNextEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        let family = context.family
        WidgetProviderRun.snapshot(kind: Self.kind, family: family, completion: completion,
                                   fallback: Self.watchdogEntry,
                                   fetch: { await Self.fetch(family: family, run: $0) })
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        let family = context.family
        WidgetProviderRun.timeline(kind: Self.kind, family: family, completion: completion,
                                   fallback: Self.watchdogEntry) { run in
            let entry = await Self.fetch(family: family, run: run)
            let refresh = entry.failed ? Date.now.addingTimeInterval(WidgetStack.retryMinutes * 60)
                : WidgetLoader.nextRefresh(idleMinutes: 60, nextAir: entry.rows.first?.item.airDate)
            let steps = WidgetStackRelevance.upNextSteps(airDate: entry.failed ? nil : entry.rows.first?.item.airDate,
                                                    now: entry.date, until: refresh)
            let entries: [UpNextEntry] = WidgetProviderRun.steps(steps) { date, score in
                var step = UpNextEntry(date: date, rows: entry.rows, signedIn: entry.signedIn, failed: entry.failed,
                                       runId: entry.runId, weekCount: entry.weekCount)
                step.relevanceScore = score
                return step
            }
            return Timeline(entries: entries, policy: .after(refresh))
        }
    }

    static func fetch(family: WidgetFamily, run: WidgetRun) async -> UpNextEntry {
        var entry: UpNextEntry
        var timedOut = false
        do {
            entry = try await withTimeout(seconds: WidgetRun.budget) { await load(family: family, run: run) }
        } catch {
            timedOut = true
            entry = UpNextEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
        run.finish(timedOut: timedOut)
        entry.runId = run.id
        return entry
    }

    private static func load(family: WidgetFamily, run: WidgetRun) async -> UpNextEntry {
        run.stage("auth")
        guard let client = CredentialStore.client() else {
            run.fail(APIError.notSignedIn)
            return UpNextEntry(date: .now, rows: [], signedIn: false, failed: false)
        }
        run.stage("calendar")
        let limit = family == .systemSmall ? 1 : 4
        do {
            let feed = try await WidgetLoader.upNextFeed(client, limit: limit, posterSize: family == .systemMedium ? "w154" : "w92",
                                                         deadline: run.deadline)
            return UpNextEntry(date: .now, rows: feed.rows, signedIn: true, failed: false, weekCount: feed.week)
        } catch {
            run.fail(error)
            return UpNextEntry(date: .now, rows: [], signedIn: true, failed: true)
        }
    }

    static func watchdogEntry(_ run: WidgetRun) -> UpNextEntry {
        WidgetProviderRun.watchdogLog(run)
        return UpNextEntry(date: .now, rows: [], signedIn: true, failed: true, runId: run.id,
                           relevanceScore: WidgetStackRelevance.low)
    }
}

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: UpNextProvider.kind, provider: UpNextProvider()) { entry in
            UpNextWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Up next")
        .description("The next episodes and releases on your calendar. Rises in a Smart Stack as the next one nears.")
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
