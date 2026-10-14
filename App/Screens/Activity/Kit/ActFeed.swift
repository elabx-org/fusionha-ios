import SwiftUI
import FusionhaKit

// MARK: Paged feed (the web's useInfiniteList)

@MainActor
@Observable
final class ActFeed<Item: Identifiable & Equatable> {
    private(set) var items: [Item] = []
    /// Bumps on every change of `items`, so views can rebuild derived data once
    /// per change (`.task(id: feed.revision)`) instead of on every body evaluation.
    private(set) var revision = 0
    private(set) var total = 0
    private(set) var loaded = false
    private(set) var error: String?
    private(set) var loadingMore = false
    private(set) var pages = 1
    private var generation = 0
    let pageSize: Int
    @ObservationIgnored var fetch: (_ page: Int, _ pageSize: Int) async throws -> ([Item], Int)

    init(pageSize: Int = 50, fetch: @escaping (_ page: Int, _ pageSize: Int) async throws -> ([Item], Int)) {
        self.pageSize = pageSize
        self.fetch = fetch
    }

    var hasMore: Bool { items.count < total }

    private func setItems(_ new: [Item]) {
        items = new
        revision &+= 1
    }

    /// Loads the first page again (a new search or a pull to refresh).
    func reload(resetting: Bool = false) async {
        generation += 1
        let gen = generation
        if resetting { loaded = false; setItems([]); total = 0 }
        do {
            let (page, total) = try await fetch(1, pageSize)
            guard gen == generation else { return }
            setItems(page)
            self.total = total
            pages = 1
            error = nil
        } catch is CancellationError {
            return
        } catch {
            guard gen == generation else { return }
            if (error as? URLError)?.code == .cancelled { return }
            self.error = error.localizedDescription
        }
        loaded = true
    }

    /// Re-reads every loaded page in one request (live polling).
    func refreshLoaded() async {
        let size = min(pageSize * pages, 500)
        let gen = generation
        guard let (page, total) = try? await fetch(1, size), gen == generation else { return }
        // Live polling: an unchanged page must not invalidate every row.
        if items != page { setItems(page) }
        if self.total != total { self.total = total }
        if error != nil { error = nil }
        if !loaded { loaded = true }
    }

    func loadMore() async {
        guard hasMore, !loadingMore, loaded else { return }
        loadingMore = true
        defer { loadingMore = false }
        let gen = generation
        do {
            let (page, total) = try await fetch(pages + 1, pageSize)
            guard gen == generation else { return }
            let seen = Set(items.map { AnyHashable($0.id) })
            let fresh = page.filter { !seen.contains(AnyHashable($0.id)) }
            if !fresh.isEmpty { setItems(items + fresh) }
            // A page that adds nothing (rows shifted while paging) ends the list
            // instead of asking for the same page forever.
            self.total = fresh.isEmpty ? items.count : total
            pages += 1
        } catch {}
    }

    /// Drops rows locally (optimistic remove).
    func remove(where predicate: (Item) -> Bool) {
        let before = items.count
        setItems(items.filter { !predicate($0) })
        total = max(0, total - (before - items.count))
    }
}
