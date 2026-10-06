import Foundation
import WidgetKit
import FusionhaKit

/// The Downloads widget's timeline. A plain `TimelineProvider` (no
/// configuration intent): every call hands WidgetKit an entry within
/// `WidgetRun.watchdog` seconds, whatever the network or the keychain does,
/// and journals each stage for the app's Widget diagnostics.
struct DownloadsProvider: TimelineProvider {
    static let kind = "Downloads"

    func placeholder(in context: Context) -> DownloadsEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (DownloadsEntry) -> Void) {
        if context.isPreview { completion(.placeholder); return }
        let family = context.family
        let once = WidgetOnce(completion)
        let run = WidgetRun(kind: Self.kind, family: family, call: "snapshot")
        once.watchdog(after: WidgetRun.watchdog) { Self.watchdogEntry(run) }
        Task { once(await Self.fetch(family: family, run: run)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DownloadsEntry>) -> Void) {
        let family = context.family
        let once = WidgetOnce(completion)
        let run = WidgetRun(kind: Self.kind, family: family)
        once.watchdog(after: WidgetRun.watchdog) {
            Timeline(entries: [Self.watchdogEntry(run)], policy: .after(.now.addingTimeInterval(5 * 60)))
        }
        Task {
            let entry = await Self.fetch(family: family, run: run)
            once(Timeline(entries: [entry], policy: .after(Self.refresh(after: entry))))
        }
    }

    /// Sooner while something downloads (the app also reloads on change) or
    /// after a failed load; when idle, every ~45 minutes or just after the next
    /// item airs.
    static func refresh(after entry: DownloadsEntry) -> Date {
        if entry.failed || entry.pageError != nil { return .now.addingTimeInterval(5 * 60) }
        if entry.idle { return WidgetLoader.nextRefresh(idleMinutes: 45, nextAir: entry.upNext.first?.item.airDate) }
        return .now.addingTimeInterval(15 * 60)
    }

    /// Always returns within the reload budget: past it, the entry built so far.
    static func fetch(family: WidgetFamily, run: WidgetRun) async -> DownloadsEntry {
        run.stage("auth")
        guard let client = CredentialStore.client() else {
            run.fail(APIError.notSignedIn)
            run.finish(timedOut: false)
            var entry = DownloadsEntry(date: .now, total: 0, rows: [], signedIn: false, failed: false,
                                       report: CredentialStore.sharingReport())
            entry.runId = run.id
            return entry
        }
        var entry: DownloadsEntry
        var timedOut = false
        do {
            entry = try await withTimeout(seconds: WidgetRun.budget) {
                if family == .systemSmall { return await small(client, run: run) }
                return await paged(client, family: family, run: run)
            }
        } catch {
            timedOut = true
            entry = run.entry
            if entry.pageError == nil { entry.pageError = "timed out" }
        }
        let log = run.finish(timedOut: timedOut)
        entry.diagnostic = WidgetRunLog.diagnostic(current: log, previous: run.previous)
        entry.runId = run.id
        return entry
    }

    private static func small(_ client: APIClient, run: WidgetRun) async -> DownloadsEntry {
        run.stage("queue")
        let entry = await WidgetLoader.downloads(client, limit: 2, idleUpNext: 1, idleRecent: 1, deadline: run.deadline)
        if entry.failed { run.fail(WidgetRunNote("queue unreachable")) }
        run.keep(entry)
        return entry
    }

    private static func paged(_ client: APIClient, family: WidgetFamily, run: WidgetRun) async -> DownloadsEntry {
        run.stage("pages")
        let stored = WidgetPageStore.page(family: WidgetPageStore.familyKey(family))
        return await WidgetPageLoader.entry(client, family: family, enabled: Set(WidgetPage.allCases),
                                            stored: stored, run: run)
    }

    /// What the watchdog hands WidgetKit: the entry built so far, marked timed out.
    static func watchdogEntry(_ run: WidgetRun) -> DownloadsEntry {
        let log = run.finish(timedOut: true, reason: "watchdog \(Int(WidgetRun.watchdog))s")
        var entry = run.entry
        if entry.pageError == nil { entry.pageError = "timed out" }
        entry.diagnostic = log.line
        entry.runId = run.id
        return entry
    }
}
