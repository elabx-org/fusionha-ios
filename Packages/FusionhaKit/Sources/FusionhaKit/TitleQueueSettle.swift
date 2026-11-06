import Foundation

/// When an open title page should re-fetch its item because one of its
/// downloads finished. The server has no push, so the page watches the queue
/// the app already polls (`GET /api/v1/queue`): a row of this title that
/// leaves the queue (imported, removed) or stops working (completed, failed,
/// a terminal phase) means the item's files and edition statuses moved.
public enum TitleQueueSettle {
    /// The row is still on its way: not completed, failed or terminal.
    public static func isWorking(_ item: QueueItem) -> Bool {
        let status = item.status.lowercased()
        return status != "completed" && status != "failed" && item.phaseTerminal != true
    }

    /// True when a row of `itemId` in `before` is gone from `after`, or was
    /// working in `before` and no longer is in `after`. A new row, or progress
    /// on a working one, is not a reason to reload.
    public static func shouldReload(itemId: Int, before: [QueueItem], after: [QueueItem]) -> Bool {
        var now: [Int: QueueItem] = [:]
        for item in after where item.mediaItemId == itemId && now[item.id] == nil { now[item.id] = item }
        return before.contains { old in
            guard old.mediaItemId == itemId else { return false }
            guard let new = now[old.id] else { return true }
            return isWorking(old) && !isWorking(new)
        }
    }
}
