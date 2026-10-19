import SwiftUI
import FusionhaKit

// The Queue tab's actions: each row's actions, Process queue now, remove
// (single, bulk and a group's Remove all), Clear queue and the select-mode bar.

extension ActivityQueueTab {
    func actions(for item: QueueItem) -> QueueRowActions {
        QueueRowActions(
            remove: { offerSearch in removingOfferSearch = offerSearch; removing = item },
            manualImport: { router.manualImport(rescue: item.id) },
            search: {
                Task { await ActActions.search(model.client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                               message: "Searching again for \(item.title)") }
            },
            interactive: { model.open(item.mediaItemId) },
            blocklist: { search in
                // Blocklist & search is one tap with Undo on the toast (web `useBlocklistAction.quick`).
                Task { await ActActions.blocklist(model.client, toaster, BlocklistCreate(downloadId: item.id, search: search),
                                                  offerUndo: search) {
                    Task { await store.refresh(model.client) }
                } }
            },
            copy: { ActActions.copy(item.releaseTitle, toaster) },
            regrab: item.grabHistoryId.map { historyId -> () -> Void in
                return {
                    Task { await ActActions.regrab(model.client, toaster, historyId: historyId) {
                        Task { await store.refresh(model.client) }
                    } }
                }
            })
    }

    func processNow() async {
        guard let client = model.client else { return }
        processing = true
        defer { processing = false }
        do {
            let r = try await client.processQueueNow()
            if r.skipped {
                switch r.skipReason {
                case "busy": toaster.show("A queue pass is already running — try again in a moment")
                case "removed_mid_pass": toaster.show("The queue changed while processing — refreshed")
                default: toaster.show("Real integrations are off — nothing to process")
                }
            } else {
                toaster.show("Queue processed — \(r.imported) imported, \(r.resolved) reconciled, \(r.left) left", tone: .success)
            }
            await store.refresh(client)
            await model.refreshQueue()
        } catch {
            toaster.error(error)
        }
    }

    func remove(_ items: [QueueItem], deleteData: Bool, blocklist: Bool, search: Bool, single: Bool) async {
        guard let client = model.client, !items.isEmpty else { return }
        busy = true
        defer { busy = false }
        var firstError: Error?
        await withTaskGroup(of: Error?.self) { group in
            for item in items {
                group.addTask {
                    do {
                        try await client.removeQueueItem(id: item.id, deleteData: deleteData && item.hasDownloadedFile == true,
                                                         blocklist: blocklist, search: search)
                        return nil
                    } catch { return error }
                }
            }
            for await result in group where firstError == nil { firstError = result }
        }
        dropLocally(items)
        if let firstError {
            toaster.error(firstError)
        } else if !single {
            let n = items.count
            toaster.show(blocklist ? "Blocklisted & removed \(ActFmt.plural(n, "download"))"
                                   : "Removed \(ActFmt.plural(n, "download")) from the queue", tone: .success)
        }
        // The server only searches with a blocklist; without one, search the
        // version here, as the web's card does (`use-search-again`).
        if firstError == nil, search, !blocklist {
            for item in items {
                await ActActions.search(client, toaster, itemId: item.mediaItemId, editionId: item.editionId,
                                        message: "Searching again for \(item.title)")
            }
        }
        await store.refresh(client)
        await model.refreshQueue()
    }

    /// A group's Remove all (web `use-remove-all.ts`): the single remove once per
    /// download, one after another, then one combined toast naming any that failed.
    func removeAll(_ items: [QueueItem], deleteData: Bool, blocklist: Bool) async {
        guard let client = model.client, !items.isEmpty else { return }
        busy = true
        defer { busy = false }
        var failed: [QueueItem] = []
        for item in items {
            do {
                try await client.removeQueueItem(id: item.id, deleteData: deleteData && item.hasDownloadedFile == true,
                                                 blocklist: blocklist, search: false)
            } catch { failed.append(item) }
        }
        let failedIds = Set(failed.map(\.id))
        dropLocally(items.filter { !failedIds.contains($0.id) })
        let message = QueueRemoveAllCopy.message(total: items.count,
                                                 failedNames: failed.map { QueueRemoveAllCopy.stripLabel($0.episodeLabel) ?? $0.title },
                                                 blocklist: blocklist)
        toaster.show(message.text, tone: message.isError ? .error : .success)
        await store.refresh(client)
        await model.refreshQueue()
    }

    private func dropLocally(_ items: [QueueItem]) {
        let ids = Set(items.map(\.id))
        if reduce { store.dropLocally(ids) } else {
            withAnimation(ActMotion.rows) { store.dropLocally(ids) }
        }
    }

    func clearAll() async {
        guard let client = model.client else { return }
        let ids = store.items
        busy = true
        var failure: Error?
        for item in ids {
            do { try await client.removeQueueItem(id: item.id) } catch { failure = failure ?? error }
        }
        busy = false
        clearing = false
        if let failure { toaster.error(failure) } else {
            toaster.show("Cleared \(ActFmt.plural(ids.count, "download")) from the queue", tone: .success)
        }
        selected = []
        await store.refresh(client)
        await model.refreshQueue()
    }

    func publishBulk() {
        guard selecting else { bulk.config = nil; return }
        let count = selected.count
        bulk.config = ActBulk.Config(
            count: count,
            hint: store.hasMore ? "Select all covers the \(store.items.count) loaded — scroll to load the rest" : nil,
            onSelectAll: { selected = Set(store.items.map(\.id)) },
            actions: [
                ActBulk.Action(label: "Blocklist & remove", icon: "nosign", kind: .warn, disabled: count == 0 || busy) { bulkRemove = true },
                ActBulk.Action(label: "Remove from queue", kind: .danger, disabled: count == 0 || busy) { bulkRemove = false },
            ])
    }
}

struct QueuePrimary {
    let icon: String
    let label: String
    let run: () -> Void
}

struct QueueRowActions {
    var remove: (_ offerSearch: Bool) -> Void
    var manualImport: () -> Void
    var search: () -> Void
    var interactive: () -> Void
    var blocklist: (_ search: Bool) -> Void
    var copy: () -> Void
    /// Re-grab this release (0.4.189); nil when no grab record survives.
    var regrab: (() -> Void)? = nil
}
