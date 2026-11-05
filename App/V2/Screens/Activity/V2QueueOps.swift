import SwiftUI
import FusionhaKit

/// The v2 queue's actions over v1's store and API calls (v1's
/// `QueueTabActions` lives on v1's view, so these are its v2 twins): held
/// overrides, remove (one or many), bulk re-grab, process now and clear.
@MainActor
struct V2QueueOps {
    let model: AppModel
    let toaster: ActToaster
    let store: QueueStore

    /// One held override. True when the server took it.
    func perform(_ choice: HeldChoice, on item: QueueItem) async -> Bool {
        switch choice {
        case .stay:
            return true
        case .removeSearch:
            guard await remove([item], deleteData: true, blocklist: false) else { return false }
            await ActActions.search(model.client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                    episodeId: item.episodeId, message: "Removed · searching again for \(item.title)")
            return true
        case .removeBlocklist:
            guard await remove([item], deleteData: true, blocklist: true, search: true) else { return false }
            toaster.show("Removed and blocklisted · searching for another", tone: .success)
            return true
        case .removeOnly:
            guard await remove([item], deleteData: true, blocklist: false) else { return false }
            toaster.show("Removed \(item.title) from the queue", tone: .success)
            return true
        }
    }

    /// Removes downloads; `deleteData` only touches rows with data on disk.
    @discardableResult
    func remove(_ items: [QueueItem], deleteData: Bool, blocklist: Bool, search: Bool = false) async -> Bool {
        guard let client = model.client, !items.isEmpty else { return false }
        var failure: Error?
        for item in items {
            do {
                try await client.removeQueueItem(id: item.id, deleteData: deleteData && item.hasDownloadedFile == true,
                                                 blocklist: blocklist, search: search)
            } catch { failure = failure ?? error }
        }
        await refresh()
        if let failure { toaster.error(failure); return false }
        return true
    }

    /// The bulk bar's Remove: one toast for the lot.
    func bulkRemove(_ items: [QueueItem], option: QueueBulkRemoveOption) async -> Bool {
        let ok = await remove(items, deleteData: option.deletesData, blocklist: option.blocklists)
        if ok {
            let n = ActFmt.plural(items.count, "download")
            toaster.show(option.blocklists ? "Blocklisted and removed \(n)" : "Removed \(n) from the queue", tone: .success)
        }
        return ok
    }

    /// Re-grab several releases one after another (no bulk endpoint: API
    /// gap), then one toast that names how many went through.
    func regrab(_ items: [QueueItem]) async {
        guard let client = model.client else { return }
        let grabs = items.compactMap(\.grabHistoryId)
        var ok = 0
        for id in grabs {
            if let result = try? await client.regrab(historyId: id, override: false), result.grabbed { ok += 1 }
        }
        let skipped = items.count - grabs.count
        var text = "Re-grabbed \(ok) of \(grabs.count)"
        if skipped > 0 { text += " · \(skipped) had no grab to repeat" }
        toaster.show(text, tone: ok == grabs.count && skipped == 0 ? .success : .warning)
        await refresh()
    }

    func processNow() async {
        guard let client = model.client else { return }
        do {
            let r = try await client.processQueueNow()
            if r.skipped {
                toaster.show(r.skipReason == "busy" ? "A queue pass is already running · try again in a moment"
                                                     : "Nothing to process right now")
            } else {
                toaster.show("Queue processed · \(r.imported) imported, \(r.resolved) reconciled, \(r.left) left",
                             tone: .success)
            }
            await refresh()
        } catch {
            toaster.error(error)
        }
    }

    /// Clear queue: every loaded download, files left on disk, nothing blocklisted.
    func clearAll() async {
        let items = store.items
        if await remove(items, deleteData: false, blocklist: false) {
            toaster.show("Cleared \(ActFmt.plural(items.count, "download")) from the queue", tone: .success)
        }
    }

    private func refresh() async {
        await store.refresh(model.client)
        await model.refreshQueue()
    }
}
