import SwiftUI
import FusionhaKit

/// The Blocklist scope's data and calls (v1 `ActivityBlocklistTab`'s, kept
/// as they are): the paged feed, the reason filter over the server's three
/// categories (`BlocklistCategory`: the wire has a free-text reason and no
/// category, so the mock's five reason chips are not built), grouping,
/// select mode, Unblock, Retry recoverable and Clear.
@MainActor
@Observable
final class V2BlocklistModel {
    let feed = ActFeed<BlocklistEntry> { _, _ in ([], 0) }
    var category: BlocklistCategory?
    var grouped = true
    var showReasons = false
    var selecting = false
    var selected: Set<Int> = []
    private(set) var busy = false

    var counts: [BlocklistCategory: Int] {
        Dictionary(grouping: feed.items) { BlocklistCategory(reason: $0.reason) }.mapValues(\.count)
    }

    var filtered: [BlocklistEntry] {
        guard let category else { return feed.items }
        return feed.items.filter { BlocklistCategory(reason: $0.reason) == category }
    }

    var chosen: [BlocklistEntry] { filtered.filter { selected.contains($0.id) } }

    func load(_ client: APIClient?, search: String) async {
        // A new search invalidates the reason picked over the old rows.
        category = nil
        feed.source(client) { c, page, size in
            let r = try await c.blocklistPage(page: page, pageSize: size, query: search)
            return (r.items, r.total)
        }
        await feed.reload(resetting: true)
    }

    /// Selection covers only what is visible.
    func prune() {
        selected = BlocklistGrouping.pruned(selected, visible: filtered)
    }

    func toggle(_ ids: [Int]) {
        let set = Set(ids)
        if set.isSubset(of: selected) { selected.subtract(set) } else { selected.formUnion(set) }
    }

    func endSelecting() {
        selecting = false
        selected = []
    }

    func unblock(_ entries: [BlocklistEntry], search: Bool, client: APIClient?, toaster: ActToaster, motion: Bool) async {
        guard let client, !entries.isEmpty else { return }
        do {
            try await BlocklistOps.remove(client, entries, search: search)
            let ids = Set(entries.map(\.id))
            withAnimation(motion ? ActMotion.rows : nil) { feed.remove { ids.contains($0.id) } }
            selected.subtract(ids)
            if entries.count == 1 {
                toaster.show(search ? "Un-blocklisted, searching for a replacement" : "Removed from the blocklist", tone: .success)
            } else {
                toaster.show("Removed \(ActFmt.plural(entries.count, "release")) from the blocklist", tone: .success)
            }
        } catch {
            toaster.error(error)
        }
    }

    /// Searches each distinct title / version / episode again, leaving the
    /// blocked releases blocked.
    func searchAgain(_ entries: [BlocklistEntry], client: APIClient?, toaster: ActToaster) async {
        guard let client else { return }
        var keys = Set<String>()
        var started = 0
        for e in entries {
            guard let item = e.mediaItemId, keys.insert("\(item)-\(e.editionId ?? -1)-\(e.episodeId ?? -1)").inserted else { continue }
            if (try? await client.runSearch(itemId: item, editionId: e.editionId, episodeId: e.episodeId)) != nil { started += 1 }
        }
        toaster.show(started == 0 ? "Couldn't start a search — try again" : "Searching again for \(ActFmt.plural(started, "title"))",
                     tone: started == 0 ? .error : .success)
    }

    func retryRecoverable(_ client: APIClient?, toaster: ActToaster) async {
        let recoverable = feed.items.filter { BlocklistCategory(reason: $0.reason) == .recoverable }
        guard !recoverable.isEmpty, let client else { return }
        busy = true
        defer { busy = false }
        do {
            try await BlocklistOps.remove(client, recoverable, search: true)
            toaster.show("Un-blocklisted \(recoverable.count) dead-NZB release\(recoverable.count == 1 ? "" : "s") — re-searching", tone: .success)
            await feed.refreshLoaded()
        } catch {
            toaster.error(error)
        }
    }

    func clearAll(_ client: APIClient?, toaster: ActToaster) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            let r = try await client.clearBlocklist()
            toaster.show("Cleared \(r.deleted) blocklist \(r.deleted == 1 ? "entry" : "entries").", tone: .success)
            await feed.reload()
        } catch {
            toaster.error(error)
        }
    }
}
