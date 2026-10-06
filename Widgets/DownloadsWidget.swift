import SwiftUI
import WidgetKit
import FusionhaKit

struct DownloadsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DownloadsEntry { .placeholder }

    func snapshot(for configuration: DownloadsPagesIntent, in context: Context) async -> DownloadsEntry {
        if context.isPreview { return .placeholder }
        return await Self.fetch(family: context.family, enabled: configuration.enabled)
    }

    func timeline(for configuration: DownloadsPagesIntent, in context: Context) async -> Timeline<DownloadsEntry> {
        let entry = await Self.fetch(family: context.family, enabled: configuration.enabled)
        // Refresh sooner while something is downloading (the app also reloads on
        // change) or after a failed load; when idle, every ~45 minutes or just
        // after the next item airs.
        let refresh: Date
        if entry.failed || entry.pageError != nil {
            refresh = .now.addingTimeInterval(5 * 60)
        } else if entry.idle {
            refresh = WidgetLoader.nextRefresh(idleMinutes: 45, nextAir: entry.upNext.first?.item.airDate)
        } else {
            refresh = .now.addingTimeInterval(15 * 60)
        }
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    /// Always returns within the reload budget: past it, the entry built so far.
    static func fetch(family: WidgetFamily, enabled: Set<WidgetPage>) async -> DownloadsEntry {
        guard let client = CredentialStore.client() else {
            return DownloadsEntry(date: .now, total: 0, rows: [], signedIn: false, failed: false,
                                  report: CredentialStore.sharingReport())
        }
        if family == .systemSmall {
            let entry = try? await withTimeout(seconds: WidgetRun.budget) {
                await WidgetLoader.downloads(client, limit: 2, idleUpNext: 1, idleRecent: 1)
            }
            return entry ?? DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: true)
        }
        let stored = WidgetPageStore.page(family: WidgetPageStore.familyKey(family))
        let run = WidgetRun(page: stored)
        var entry: DownloadsEntry
        var timedOut = false
        do {
            entry = try await withTimeout(seconds: WidgetRun.budget) {
                await WidgetPageLoader.entry(client, family: family, enabled: enabled, stored: stored, run: run)
            }
        } catch {
            timedOut = true
            entry = run.entry
            if entry.pageError == nil { entry.pageError = "timed out" }
        }
        let log = run.finish(timedOut: timedOut)
        entry.diagnostic = WidgetRunLog.diagnostic(current: log, previous: run.previous)
        return entry
    }
}

struct DownloadsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Downloads", intent: DownloadsPagesIntent.self, provider: DownloadsProvider()) { entry in
            DownloadsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Downloads")
        .description("Downloads, Up next, Recently added, Library, Indexers, Wanted and Requests in one widget. Tap the dots to switch views; Edit Widget picks which views show.")
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

    /// Small: Activity while downloading, else the title it shows. Medium and
    /// large: the current view's screen (rows and posters link to their items).
    private var url: URL {
        guard family == .systemSmall else { return WidgetRoute.page(entry.page).url }
        return WidgetRoute.downloads(
            idle: entry.idle, small: true,
            upNextIds: entry.upNext.map(\.item.itemId),
            recentIds: entry.recent.map(\.item.itemId)).url
    }
}
