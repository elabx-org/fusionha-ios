import SwiftUI
import FusionhaKit

/// The board's data (web `useBoardColumns`): one paged query per server
/// bucket, merged and placed by each row's derived column, plus the counts
/// for the headers. Polls every 30 s; while a poll is in flight the last
/// settled rows stay, so a card moving between buckets never blinks out.
@MainActor
@Observable
final class BoardModel {
    struct Bucket {
        var items: [MediaRequest] = []
        var cursor: String?
        var pages = 0
        var failed = false
        var loadingMore = false
    }

    private(set) var buckets: [RequestBoard.Bucket: Bucket] = [:]
    private(set) var columns: [RequestBoard.Column: [MediaRequest]] = [:]
    private(set) var people: [RequestPerson] = []
    private(set) var live: RequestCounts?
    private(set) var recent: RequestCounts?
    private(set) var loaded = false
    var search = ""
    var userId: Int?
    /// The filter sheet's source (`source=`), added to every bucket and count.
    var extra: [URLQueryItem] = []

    @ObservationIgnored private var seen: [Int: RequestPerson] = [:]

    func poll(_ client: APIClient?) async {
        while !Task.isCancelled {
            await refresh(client)
            try? await Task.sleep(for: .seconds(30))
        }
    }

    func refresh(_ client: APIClient?) async {
        guard let client else { return }
        let filters = RequestBoard.filterItems(search: search.trimmingCharacters(in: .whitespaces), userId: userId) + extra
        await withTaskGroup(of: (RequestBoard.Bucket, Result<RequestPage, Error>).self) { group in
            for bucket in RequestBoard.Bucket.allCases {
                let q = bucket.query(search: search.trimmingCharacters(in: .whitespaces), userId: userId)
                group.addTask {
                    do {
                        return (bucket, .success(try await client.requestsPage(view: "all", filter: q.filter, sort: "last_event",
                                                                               limit: RequestBoard.page, extra: q.extra + extra)))
                    } catch {
                        return (bucket, .failure(error))
                    }
                }
            }
            for await (bucket, result) in group {
                var state = buckets[bucket] ?? Bucket()
                switch result {
                case .success(let page):
                    state = Bucket(items: page.items, cursor: page.nextCursor, pages: 1)
                case .failure:
                    state.failed = true
                }
                buckets[bucket] = state
            }
        }
        live = (try? await client.requestCounts(view: "all", extra: filters)) ?? live
        recent = (try? await client.requestCounts(view: "all", extra: filters + [URLQueryItem(name: "since_days", value: String(RequestBoard.terminalDays))])) ?? recent
        loaded = true
        rebuild()
    }

    func loadMore(_ client: APIClient?, bucket: RequestBoard.Bucket) async {
        guard let client, var state = buckets[bucket], let cursor = state.cursor, !state.loadingMore else { return }
        state.loadingMore = true
        buckets[bucket] = state
        let q = bucket.query(search: search.trimmingCharacters(in: .whitespaces), userId: userId)
        if let page = try? await client.requestsPage(view: "all", filter: q.filter, sort: "last_event", limit: RequestBoard.page,
                                                     cursor: cursor, extra: q.extra + extra) {
            let known = Set(state.items.map(\.id))
            state.items += page.items.filter { !known.contains($0.id) }
            state.cursor = page.nextCursor
            state.pages += 1
        }
        state.loadingMore = false
        buckets[bucket] = state
        rebuild()
    }

    private func rebuild() {
        let merged = RequestBoard.merge(buckets.mapValues(\.items))
        columns = RequestBoard.group(merged)
        for p in RequestBoard.people(merged) where p.id != nil { seen[p.id!] = p }
        people = seen.values.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: Column state

    func hasMore(_ column: RequestBoard.Column) -> Bool {
        let b = buckets[column.bucket]
        return b?.cursor != nil && (b?.pages ?? 0) < RequestBoard.maxPages
    }

    func capped(_ column: RequestBoard.Column) -> Bool {
        let b = buckets[column.bucket]
        return b?.cursor != nil && (b?.pages ?? 0) >= RequestBoard.maxPages
    }

    func failed(_ column: RequestBoard.Column) -> Bool { buckets[column.bucket]?.failed == true }

    /// The header figure: server totals where the server can give one.
    func countLabel(_ column: RequestBoard.Column) -> String {
        let loadedCount = columns[column]?.count ?? 0
        switch column {
        case .pending:
            return live.map { String($0.inbox) } ?? String(loadedCount)
        case .declined:
            return recent.map { String($0.declined) } ?? String(loadedCount)
        case .available:
            guard let recent else { return String(loadedCount) }
            let c = RequestBoard.availableCount(serverTotal: recent.available, buckets: buckets.mapValues(\.items),
                                                availableLoaded: buckets[.available]?.cursor == nil,
                                                activeLoaded: buckets[.active]?.cursor == nil)
            return RequestBoard.countLabel(c.count, exact: c.exact)
        case .approved, .downloading:
            return RequestBoard.countLabel(loadedCount, exact: buckets[.active]?.cursor == nil)
        }
    }

    /// The header figure as a number, for the summary line and section headers.
    func count(_ column: RequestBoard.Column) -> Int {
        Int(countLabel(column).filter(\.isNumber)) ?? 0
    }

    /// Pending only: rows held for quota, counted beside the figure.
    var waiting: Int { live?.waiting ?? 0 }
}
