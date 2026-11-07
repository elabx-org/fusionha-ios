import Foundation
import WidgetKit
import FusionhaKit

extension AppSession {
    // MARK: Queue polling (no stream on the server, so poll like the web does)

    /// Runs while a window is active (`AppSession+Polling`): one loop for the
    /// whole app, however many windows show the queue.
    func pollQueue() async {
        // The queue as this phone last saw it, at once (badge, Activity, Live Activity
        // wait for the first poll otherwise).
        if queue.isEmpty, let kept = await client?.cached({ try await $0.queue() }) {
            if queue.isEmpty {
                queueLoaded = true
                queue = kept.items
                queueTotal = kept.total
                queueHeldIds = kept.items.filter { $0.status.lowercased() == "held" }.map(\.id)
                queueHeld = queueHeldIds.count
            }
        }
        while !Task.isCancelled {
            await refreshQueue()
            let interval: Double = queue.isEmpty ? 6 : 2
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    func refreshQueue() async {
        PerfCount.hit("AppModel.refreshQueue")
        guard let client else { return }
        do {
            let page = try await client.queue()
            let (items, total) = DownloadsBarScreenshot.shaped(page.items, total: page.total)
            // Polled every 2s: assign only what changed, so observers of the
            // total / held count (Activity's header, the tab badge) don't
            // re-render on every tick while progress moves.
            if queue != items { queue = items }
            if queueTotal != total { queueTotal = total }
            let heldIds = items.filter { $0.status.lowercased() == "held" }.map(\.id)
            if queueHeldIds != heldIds { queueHeldIds = heldIds }
            if queueHeld != heldIds.count { queueHeld = heldIds.count }
            if queueError != nil { queueError = nil }
            if !queueLoaded { queueLoaded = true }
            if queuePaused != (page.paused == true) { queuePaused = page.paused == true }
            LiveActivityController.sync(with: items, paused: page.paused == true)
            let ids = items.map(\.id)
            if ids != lastQueueIds {
                if !Set(lastQueueIds).isSubset(of: ids) { reloadLibraryAfterQueue() }
                lastQueueIds = ids
                WidgetCenter.shared.reloadTimelines(ofKind: "Downloads")
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetStack.downloading.kind)
            }
        } catch {
            queueError = error.localizedDescription
        }
    }

    /// A download left the queue (imported, failed or removed): the title's
    /// versions and its Needs you flag changed on the server, so the library
    /// reloads once the queue has been quiet for 3 s (a season pack leaving
    /// item by item reloads once). Home, All titles and their cards follow.
    private func reloadLibraryAfterQueue() {
        libraryAfterQueue?.cancel()
        libraryAfterQueue = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            await self.loadLibrary()
        }
    }
}
