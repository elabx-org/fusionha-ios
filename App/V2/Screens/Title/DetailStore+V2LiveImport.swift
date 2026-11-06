import SwiftUI
import FusionhaKit

/// A visible title page notices its downloads finishing. There is no push
/// from the server: the app already polls `GET /api/v1/queue` (every 2s while
/// anything is in it) for as long as a window is active, and every page of
/// the title (the title, a pushed season, a pushed episode) feeds this
/// title's rows into the store. When a row leaves the queue (imported,
/// removed) or stops working (failed), the item is fetched once more, so
/// the File card, the tickets, the season rows and the Files tab change on
/// their own instead of only on reopen.
extension DetailStore {
    /// How long a finished download settles before the re-fetch: the poll that
    /// drops a row can land just before the server commits the file, and a
    /// pack finishing several rows in a row costs one fetch.
    static let settleDelay: Duration = .seconds(1.5)

    /// This title's rows of the polled queue, and a re-fetch when one finished.
    func takeQueue(_ queue: [QueueItem]) {
        let mine = queue.filter { $0.mediaItemId == itemId }
        guard self.queue != mine else { return }
        let finished = TitleQueueSettle.shouldReload(itemId: itemId, before: self.queue, after: mine)
        self.queue = mine
        if finished { scheduleSettleReload() }
    }

    /// One re-fetch after `settleDelay`; a later finish restarts the wait.
    private func scheduleSettleReload() {
        settleReload?.cancel()
        settleReload = Task { [weak self] in
            try? await Task.sleep(for: DetailStore.settleDelay)
            guard !Task.isCancelled, let self else { return }
            await self.reload()
        }
    }
}

extension View {
    /// Feeds the polled queue to the title's store while this page is on
    /// screen (`DetailStore.takeQueue`). On the title and on its pushed pages,
    /// so a season or episode on top still sees the import land.
    func v2TitleLiveImport(_ store: DetailStore) -> some View {
        modifier(V2TitleLiveImport(store: store))
    }
}

private struct V2TitleLiveImport: ViewModifier {
    @Environment(AppModel.self) private var model
    let store: DetailStore

    func body(content: Content) -> some View {
        content.onQueueChange(model) { [store] queue in store.takeQueue(queue) }
    }
}
