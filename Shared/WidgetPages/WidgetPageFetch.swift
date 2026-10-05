import Foundation
import FusionhaKit

/// The per-page fetches behind `WidgetPageLoader`, each kept small for the
/// widget extension's memory and time limits.
enum WidgetPageFetch {
    /// The Library summary. It needs the whole library list, so the summary is
    /// computed once and cached for an hour; the list itself is never kept.
    static func library(_ client: APIClient) async -> WidgetLibrarySummary? {
        if let cached = WidgetPageStore.cached(WidgetLibrarySummary.self, "library", maxAge: 3600) { return cached }
        guard let items = try? await client.library() else { return nil }
        let summary = WidgetLibrarySummary(items)
        WidgetPageStore.cache(summary, "library")
        return summary
    }

    static func indexers(_ client: APIClient, top: Int) async -> WidgetIndexerSummary? {
        async let stats = try? client.activityIndexerStats(range: "7d")
        async let unavailable = try? client.stoppedIndexers()
        guard let stats = await stats else { return nil }
        return WidgetIndexerSummary(stats: stats, unavailable: await unavailable ?? [], top: top)
    }

    static func wanted(_ client: APIClient, rows: Int) async -> (WidgetWantedSummary?, [Data?]) {
        async let missing = try? client.wantedPage(state: .missing, pageSize: rows)
        async let fourK = try? client.fourKAvailable(pageSize: 1)
        guard let page = await missing else { return (nil, []) }
        let summary = WidgetWantedSummary(missing: page, fourK: await fourK, limit: rows)
        let posters = await WidgetLoader.fetchPosters(summary.rows.map(\.posterUrl), size: "w92")
        return (summary, posters)
    }

    /// Requests and the newest open issue, with their titles and requester names.
    static func requests(_ client: APIClient, rows: Int, into data: WidgetPageData) async -> WidgetPageData {
        var data = data
        async let requests = try? client.requests(status: nil)
        async let issues = try? client.issues(status: "open")
        guard let list = await requests else { return data }
        let summary = WidgetRequestsSummary(requests: list, openIssues: await issues ?? [], limit: rows)
        data.requests = summary
        data.requestTitles = await titles(client, summary.newest)
        if let issue = summary.issue { data.issueTitle = try? await client.widgetItemTitle(id: issue.mediaItemId) }
        data.userNames = await userNames(client)
        return data
    }

    private static func titles(_ client: APIClient, _ rows: [WidgetRequestRow]) async -> [Int: String] {
        await withTaskGroup(of: (Int, String?).self) { group in
            for row in rows {
                group.addTask {
                    let kind: PreviewKind = row.kind == .movie ? .movie : .series
                    return (row.id, try? await client.previewDetail(kind: kind, tmdbId: row.tmdbId).title)
                }
            }
            var out: [Int: String] = [:]
            for await (id, title) in group { if let title { out[id] = title } }
            return out
        }
    }

    /// Requester names (user managers only), cached 6h.
    private static func userNames(_ client: APIClient) async -> [Int: String] {
        if let cached = WidgetPageStore.cached([Int: String].self, "userNames", maxAge: 6 * 3600) { return cached }
        let names = (try? await client.widgetUserNames()) ?? [:]
        WidgetPageStore.cache(names, "userNames")
        return names
    }
}
