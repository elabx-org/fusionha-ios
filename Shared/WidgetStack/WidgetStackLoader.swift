import Foundation
import WidgetKit
import FusionhaKit

/// Builds a single-view widget's entry: only that view's data, inside the
/// reload budget, journalled like the Downloads widget. Never throws: a failed
/// or timed-out load is an entry with `pageError` (the view's retry line).
enum WidgetStackLoader {
    static func entry(_ stack: WidgetStack, family: WidgetFamily, run: WidgetRun) async -> DownloadsEntry {
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
            entry = try await withTimeout(seconds: WidgetRun.budget) { await load(stack, family: family, client, run: run) }
        } catch {
            timedOut = true
            entry = run.entry
            if entry.pageError == nil { entry.pageError = "timed out" }
        }
        let log = run.finish(timedOut: timedOut)
        entry.diagnostic = WidgetRunLog.diagnostic(current: log, previous: run.previous)
        entry.runId = run.id
        entry.relevanceScore = relevance(stack, entry)
        return entry
    }

    private static func load(_ stack: WidgetStack, family: WidgetFamily, _ client: APIClient,
                             run: WidgetRun) async -> DownloadsEntry {
        var entry = blank(stack)
        run.keep(entry)
        if run.previous?.died(loading: stack.page.rawValue) == true {
            // The last reload was killed loading this view: show the retry line
            // once rather than risk the same again.
            entry.pageError = "stopped last time"
            return entry
        }
        run.stage("page", page: stack.page)
        await fill(stack, into: &entry, client, family: family, deadline: run.deadline, onError: run.fail)
        run.keep(entry)
        return entry
    }

    /// An empty entry showing `stack`'s view.
    static func blank(_ stack: WidgetStack) -> DownloadsEntry {
        var entry = DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: false)
        entry.page = stack.page
        entry.pages = [stack.page]
        return entry
    }

    /// Fills one widget's data (also used by the CI gallery). On failure the
    /// entry records why in `pageError`.
    static func fill(_ stack: WidgetStack, into entry: inout DownloadsEntry, _ client: APIClient, family: WidgetFamily,
                     deadline: WidgetDeadline = WidgetDeadline(seconds: 20),
                     onError: (Error) -> Void = { _ in }) async {
        let large = family == .systemLarge
        switch stack {
        case .downloading:
            do {
                var queue = try await WidgetLoader.queue(client, limit: large ? 4 : 2, deadline: deadline)
                queue.page = entry.page
                queue.pages = entry.pages
                entry = queue
            } catch {
                onError(error)
                entry.pageError = WidgetRunLog.describe(error)
            }
        case .requests:
            guard await WidgetPageLoader.requestsAllowed(client, deadline) else {
                entry.restricted = true
                return
            }
            await WidgetPageLoader.load(.requests, into: &entry, client, large: large, deadline: deadline, onError: onError)
        case .library, .indexers:
            await WidgetPageLoader.load(stack.page, into: &entry, client, large: large, deadline: deadline, onError: onError)
        }
    }

    /// The Smart Stack score (`WidgetStackRelevance`): low after a failed load.
    static func relevance(_ stack: WidgetStack, _ entry: DownloadsEntry) -> Float {
        guard entry.signedIn, !entry.failed, entry.pageError == nil else { return WidgetStackRelevance.low }
        switch stack {
        case .downloading:
            return WidgetStackRelevance.downloading(active: entry.total, stalled: entry.rows.filter(\.stalled).count)
        case .library:
            return WidgetStackRelevance.low
        case .indexers:
            return WidgetStackRelevance.indexers(flagged: entry.pageData.indexers?.flagged.count ?? 0)
        case .requests:
            let s = entry.pageData.requests
            return WidgetStackRelevance.requests(pending: s?.pending ?? 0, openIssues: s?.openIssues ?? 0)
        }
    }
}
