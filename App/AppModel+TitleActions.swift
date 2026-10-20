import Foundation
import FusionhaKit

extension AppModel {
    // MARK: Opening titles

    /// `tab:` mirrors the web's `/library/{id}?tab=…` (e.g. History's "Why this decision").
    func open(_ itemId: Int, tab: DetailTab? = nil) {
        pendingDetailTab = tab
        presentedItem = ItemRef(id: itemId)
    }

    /// Opens the Add sheet, on a title's configure step when `pick` is set.
    func openAdd(_ pick: MediaSearchResult?, providerOverride: String? = nil) {
        addPrefill = pick
        addProviderOverride = providerOverride
        showingAdd = true
    }

    func openPreview(_ result: MediaSearchResult) {
        if let previewHandler {
            previewHandler(result)
        } else {
            addPrefill = result
            showingAdd = true
        }
    }

    // MARK: Title actions (poster kebab, detail, bulk bar)

    func autoSearch(_ id: Int) {
        Task {
            do {
                try await client?.searchItem(id: id)
            } catch {
                toast("Couldn't start the search", variant: .error)
            }
        }
    }

    func interactiveSearch(_ id: Int, tier: QualityTier?) {
        detailIntent = .interactiveSearch(tier)
        open(id)
    }

    func scopedSearch(_ id: Int, _ scope: ScopedSearch) {
        detailIntent = .scopedSearch(scope)
        open(id)
    }

    func edit(_ id: Int) {
        detailIntent = .edit
        open(id)
    }

    func setMonitored(_ id: Int, title: String, monitored: Bool) {
        Task {
            do {
                try await client?.bulkMonitor(BulkMonitorRequest(itemIds: [id], monitored: monitored))
                toast(monitored ? "Monitoring \(title)" : "Stopped monitoring \(title)")
                await loadLibrary()
            } catch {
                toast("Couldn't update \(title)", variant: .error)
            }
        }
    }

    /// Refresh metadata as a background run, polled every 1.5s like the web.
    func refreshMetadata(_ id: Int, title: String) {
        toast("Refreshing \(title)…")
        Task {
            guard let client else { return }
            do {
                let dispatch = try await client.refreshItem(id: id, metadataOnly: true)
                var state = try await client.run(id: dispatch.runId)
                while state.isRunning {
                    try await Task.sleep(for: .seconds(1.5))
                    state = try await client.run(id: dispatch.runId)
                }
                if state.failed {
                    toast("Couldn't refresh \(title)", variant: .error)
                } else {
                    toast("Refreshed \(title)")
                    await loadLibrary()
                }
            } catch {
                toast("Couldn't refresh \(title)", variant: .error)
            }
        }
    }

    func confirmDelete(_ id: Int, title: String) {
        deleteTarget = DeleteTarget(id: id, title: title)
    }

    func delete(_ target: DeleteTarget, deleteFiles: Bool) async -> Bool {
        guard let client else { return false }
        do {
            try await client.deleteItem(id: target.id, deleteFiles: deleteFiles)
            toast("\(target.title) deleted")
            if presentedItem?.id == target.id { presentedItem = nil }
            selection.remove(target.id)
            await loadLibrary()
            return true
        } catch {
            toast("Couldn't delete \(target.title)", variant: .error)
            return false
        }
    }

    func exitSelectMode() {
        selectMode = false
        selection = []
    }

    /// Runs one bulk call over the selection; on success leaves select mode
    /// (BulkActionBar `done`) and reloads the library.
    func bulk(_ success: String?, _ failure: String, _ call: @escaping (APIClient, [Int]) async throws -> Void) {
        let ids = Array(selection).sorted()
        guard let client, !ids.isEmpty else { return }
        Task {
            do {
                try await call(client, ids)
                if let success { toast(success) }
                exitSelectMode()
                await loadLibrary()
            } catch {
                toast(failure, variant: .error)
            }
        }
    }
}
