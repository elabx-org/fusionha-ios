import SwiftUI
import FusionhaKit

/// A title's "Open in Queue": Activity › Queue with the download brought
/// forward and flashed (the same `focus` a `fusionha://activity/queue?focus=`
/// link carries). When the queue the app holds doesn't have it, the Queue tab
/// still opens.
extension AppModel {
    func openInQueue(editionId: Int?, episodeId: Int? = nil) {
        openInQueue(downloadId: queueDownloadId(editionId: editionId, episodeId: episodeId))
    }

    /// Activity › Queue with this download brought forward and flashed.
    func openInQueue(downloadId: Int?) {
        if let id = downloadId {
            pendingQueueFocus = (downloadId: id, block: false)
            pendingQueueScroll = id
        }
        pendingActivityTab = .queue
        presentedItem = nil
        tab = .activity
    }

    /// The version's download: the episode's own first, else the version's pack.
    private func queueDownloadId(editionId: Int?, episodeId: Int?) -> Int? {
        guard let editionId else { return nil }
        let mine = queue.filter { $0.editionId == editionId }
        return (mine.first { $0.episodeId == episodeId } ?? mine.first)?.id
    }
}
