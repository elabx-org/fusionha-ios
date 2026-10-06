import Foundation
import FusionhaKit

/// The per-page fetches behind `WidgetPageLoader`, each kept small for the
/// widget extension's memory and time limits. The page's main read throws (the
/// page then offers a retry); extras like titles and names are best-effort.
enum WidgetPageFetch {
    /// The Library summary, tallied item by item from the list (never held
    /// decoded) and cached for an hour.
    static func library(_ client: APIClient, deadline: WidgetDeadline) async throws -> WidgetLibrarySummary {
        if let cached = WidgetPageStore.cached(WidgetLibrarySummary.self, "library", maxAge: 3600) { return cached }
        let summary = try await withTimeout(seconds: deadline.slice(6, reserve: 0.5)) { try await client.widgetLibrarySummary() }
        WidgetPageStore.cache(summary, "library")
        return summary
    }

    static func indexers(_ client: APIClient, top: Int, deadline: WidgetDeadline) async throws -> WidgetIndexerSummary {
        let slice = deadline.slice(5, reserve: 0.5)
        async let stats = withTimeout(seconds: slice) { try await client.activityIndexerStats(range: "7d") }
        async let unavailable = try? withTimeout(seconds: slice) { try await client.stoppedIndexers() }
        return WidgetIndexerSummary(stats: try await stats, unavailable: await unavailable ?? [], top: top)
    }

    static func wanted(_ client: APIClient, rows: Int, deadline: WidgetDeadline) async throws -> (WidgetWantedSummary, [Data?]) {
        let slice = deadline.slice(4, reserve: 2)
        async let missing = withTimeout(seconds: slice) { try await client.wantedPage(state: .missing, pageSize: rows) }
        async let fourK = try? withTimeout(seconds: slice) { try await client.fourKAvailable(pageSize: 1) }
        let summary = WidgetWantedSummary(missing: try await missing, fourK: await fourK, limit: rows)
        let posters = await WidgetLoader.fetchPosters(summary.rows.map(\.posterUrl), size: "w92", deadline: deadline)
        return (summary, posters)
    }

    /// Requests and the newest open issue, then (best-effort, in parallel)
    /// their titles and the requesters' names.
    static func requests(_ client: APIClient, rows: Int, into data: WidgetPageData,
                         deadline: WidgetDeadline) async throws -> WidgetPageData {
        var data = data
        let slice = deadline.slice(4, reserve: 2)
        async let requests = withTimeout(seconds: slice) { try await client.requests(status: nil) }
        async let issues = try? withTimeout(seconds: slice) { try await client.issues(status: "open") }
        let summary = WidgetRequestsSummary(requests: try await requests, openIssues: await issues ?? [], limit: rows)
        data.requests = summary
        let extras = deadline.slice(3, reserve: 0.5)
        async let titles = titles(client, summary.newest, timeout: extras)
        async let issueTitle = itemTitle(client, summary.issue?.mediaItemId, timeout: extras)
        async let names = userNames(client, timeout: extras)
        data.requestTitles = await titles
        data.issueTitle = await issueTitle
        data.userNames = await names
        return data
    }

    /// Request id → title, two TMDB previews at a time.
    private static func titles(_ client: APIClient, _ rows: [WidgetRequestRow], timeout: TimeInterval) async -> [Int: String] {
        let found = await concurrentMap(rows, maxConcurrent: 2) { row -> String? in
            let kind: PreviewKind = row.kind == .movie ? .movie : .series
            return try? await withTimeout(seconds: timeout) { try await client.previewDetail(kind: kind, tmdbId: row.tmdbId).title }
        }
        var out: [Int: String] = [:]
        for (row, title) in zip(rows, found) { if let title { out[row.id] = title } }
        return out
    }

    private static func itemTitle(_ client: APIClient, _ id: Int?, timeout: TimeInterval) async -> String? {
        guard let id else { return nil }
        return try? await withTimeout(seconds: timeout) { try await client.widgetItemTitle(id: id) }
    }

    /// Requester names (user managers only), cached 6h. A refusal caches no
    /// names; a timeout caches nothing, so the next reload asks again.
    private static func userNames(_ client: APIClient, timeout: TimeInterval) async -> [Int: String] {
        if let cached = WidgetPageStore.cached([Int: String].self, "userNames", maxAge: 6 * 3600) { return cached }
        let names: [Int: String]
        do {
            names = try await withTimeout(seconds: timeout) { try await client.widgetUserNames() }
        } catch is WidgetTimedOut {
            return [:]
        } catch {
            names = [:]
        }
        WidgetPageStore.cache(names, "userNames")
        return names
    }
}
