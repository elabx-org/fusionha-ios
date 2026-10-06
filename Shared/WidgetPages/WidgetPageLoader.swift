import Foundation
import WidgetKit
import FusionhaKit

/// Builds the paged Downloads widget's entry: the queue (always, it decides
/// whether Downloading shows), then only the current page's data. Every step
/// runs against the reload's deadline; a failed step leaves the pages and dots
/// in place and the page shows a retry line.
enum WidgetPageLoader {
    static func entry(_ client: APIClient, family: WidgetFamily, enabled: Set<WidgetPage>,
                      stored: WidgetPage?, run: WidgetRun) async -> DownloadsEntry {
        let large = family == .systemLarge
        run.stage("queue")
        var entry: DownloadsEntry
        do {
            entry = try await WidgetLoader.queue(client, limit: large ? 4 : 2, deadline: run.deadline)
        } catch {
            run.fail(error)
            entry = DownloadsEntry(date: .now, total: 0, rows: [], signedIn: true, failed: true)
            entry.pageError = WidgetRunLog.describe(error)
        }
        run.stage("pages")
        var allowed = false
        if !entry.failed, enabled.contains(.requests) { allowed = await requestsAllowed(client, run.deadline) }
        entry.pages = WidgetPage.available(enabled: enabled, downloading: !entry.idle, requestsAllowed: allowed)
        entry.page = WidgetPage.current(stored: stored, in: entry.pages)
        run.keep(entry)
        guard !entry.failed else { return entry }
        if run.previous?.died(loading: entry.page.rawValue) == true {
            // The last reload was killed loading this page: show the retry line
            // once rather than risk the same again; a tap (or the next reload) loads it.
            entry.pageError = "stopped last time"
            return entry
        }
        run.stage("page", page: entry.page)
        await load(entry.page, into: &entry, client, large: large, deadline: run.deadline, onError: run.fail)
        return entry
    }

    /// Fills one page's data (also used by the gallery to shoot every page). On
    /// failure the page keeps what it has and records why in `pageError`.
    static func load(_ page: WidgetPage, into entry: inout DownloadsEntry, _ client: APIClient, large: Bool,
                     deadline: WidgetDeadline = WidgetDeadline(seconds: 20),
                     onError: (Error) -> Void = { _ in }) async {
        do {
            try await fill(page, into: &entry, client, large: large, deadline: deadline)
        } catch {
            onError(error)
            entry.pageError = WidgetRunLog.describe(error)
        }
    }

    private static func fill(_ page: WidgetPage, into entry: inout DownloadsEntry, _ client: APIClient,
                             large: Bool, deadline: WidgetDeadline) async throws {
        switch page {
        case .downloading:
            break
        case .upNext:
            let feed = try await WidgetLoader.upNextFeed(client, limit: 4, posterSize: "w154", deadline: deadline)
            entry.upNext = feed.rows
            entry.weekCount = feed.week
        case .recent:
            entry.recent = try await WidgetLoader.recent(client, limit: 8, posterSize: "w154", deadline: deadline)
        case .library:
            // The Wanted line rides along, best-effort.
            async let wanted = try? WidgetPageFetch.wantedCounts(client, deadline: deadline)
            entry.pageData.library = try await WidgetPageFetch.library(client, deadline: deadline)
            entry.pageData.wanted = await wanted
        case .indexers:
            entry.pageData.indexers = try await WidgetPageFetch.indexers(client, top: large ? 4 : 3, deadline: deadline)
        case .wanted:
            let (summary, posters) = try await WidgetPageFetch.wanted(client, rows: large ? 3 : 2, deadline: deadline)
            entry.pageData.wanted = summary
            entry.pageData.wantedPosters = posters
        case .requests:
            entry.pageData = try await WidgetPageFetch.requests(client, rows: large ? 4 : 2, into: entry.pageData,
                                                                deadline: deadline)
        }
    }

    /// Approvers and issue managers see Requests & issues (cached 6h; a
    /// timeout hides the page this once without caching the answer).
    static func requestsAllowed(_ client: APIClient, _ deadline: WidgetDeadline) async -> Bool {
        if let cached = WidgetPageStore.cached(Bool.self, "requestsAllowed", maxAge: 6 * 3600) { return cached }
        guard let me = try? await withTimeout(seconds: deadline.slice(2, reserve: 4), { try await client.me() }) else { return false }
        let allowed = me.hasPermission("requests.approve") || me.hasPermission("issues.manage")
        WidgetPageStore.cache(allowed, "requestsAllowed")
        return allowed
    }
}
