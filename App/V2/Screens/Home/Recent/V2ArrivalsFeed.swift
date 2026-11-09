import SwiftUI
import FusionhaKit

/// Recently arrived's reads: imports from History (`event_type=imported`),
/// newest first, grouped per title per day (`RecentArrivals`). Home keeps
/// the first page fresh (`watch`, every two minutes while Home is up); the
/// full timeline page asks for more as it scrolls (`loadMore`).
@MainActor
@Observable
final class V2ArrivalsFeed {
    private(set) var rows: [ArrivalRow] = []
    /// Nothing fetched yet, or the first fetch failed.
    private(set) var loaded = false
    private(set) var loadingMore = false
    private var history: [HistoryEntry] = []
    private var pages = 0
    private var total = 0

    var hasMore: Bool { history.count < total }

    func watch(_ client: APIClient?) async {
        while !Task.isCancelled {
            await refresh(client)
            try? await Task.sleep(for: .seconds(120))
        }
    }

    /// The first page again; older pages already loaded are kept (a later
    /// page that now overlaps is de-duplicated by id).
    func refresh(_ client: APIClient?) async {
        guard let client else { return }
        do {
            let page = try await client.importsPage(page: 1)
            let fresh = page.items
            let known = Set(fresh.map(\.id))
            let oldest = fresh.map(\.id).min() ?? .max
            let older = pages > 1 ? history.filter { !known.contains($0.id) && $0.id < oldest } : []
            set(fresh + older, total: page.total, pages: older.isEmpty ? 1 : pages)
        } catch {
            // Keep what is shown; Home hides the page until a first fetch works.
        }
    }

    func loadMore(_ client: APIClient?) async {
        guard let client, hasMore, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page = try? await client.importsPage(page: pages + 1) else { return }
        let known = Set(history.map(\.id))
        set(history + page.items.filter { !known.contains($0.id) }, total: page.total, pages: pages + 1)
    }

    private func set(_ next: [HistoryEntry], total: Int, pages: Int) {
        self.total = total
        self.pages = pages
        loaded = true
        guard next != history else { return }
        history = next
        rows = RecentArrivals.rows(next)
    }
}
