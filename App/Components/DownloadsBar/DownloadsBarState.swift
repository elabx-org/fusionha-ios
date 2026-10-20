import Foundation
import FusionhaKit

/// What the downloads bar shows, derived from `AppModel.queue` (the shell's
/// existing `GET /api/v1/queue` poll; no polling of its own). Keeps the
/// "Imported" moment for a few seconds after the last download leaves.
@MainActor @Observable
final class DownloadsBarState {
    private(set) var summary: DownloadsBar.Summary?
    /// The lead that just imported, shown with the done wash, then cleared.
    private(set) var finished: DownloadsBar.Summary?
    private var finishTask: Task<Void, Never>?

    static let finishedFor: Duration = .seconds(6)

    var hasContent: Bool { summary != nil || finished != nil }

    func update(_ queue: [QueueItem]) {
        let next = DownloadsBar.summary(queue)
        if let done = DownloadsBar.finished(previous: summary, nowEmpty: queue.isEmpty) {
            showFinished(done)
        } else if next != nil, finished != nil {
            finishTask?.cancel()
            finished = nil
        }
        if summary != next { summary = next }
    }

    private func showFinished(_ done: DownloadsBar.Summary) {
        finished = done
        finishTask?.cancel()
        #if DEBUG
        // CI screenshots hold the moment so the shot can catch it.
        if DownloadsBarScreenshot.holdsFinished { return }
        #endif
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: Self.finishedFor)
            guard !Task.isCancelled else { return }
            self?.finished = nil
        }
    }
}

/// CI screenshots of the bar against `scripts/mock_server.py`, whose queue
/// leads with a held download (the needs-you state):
/// `FUSIONHA_SCREENSHOT_BAR=downloading` drops the downloads that need you;
/// `done` serves the moving downloads once, then an empty queue, so the bar
/// shows (and holds) "Imported".
/// Release builds pass the queue through untouched.
@MainActor
enum DownloadsBarScreenshot {
    /// The queue page as the shell should see it (and its total).
    static func shaped(_ items: [QueueItem], total: Int) -> ([QueueItem], Int) {
        #if DEBUG
        guard mode != nil else { return (items, total) }
        let shown = shape(items)
        return (shown, shown.count)
        #else
        return (items, total)
        #endif
    }

    #if DEBUG
    static let mode = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_BAR"]
    private static var polls = 0

    static var holdsFinished: Bool { mode == "done" }

    private static func shape(_ items: [QueueItem]) -> [QueueItem] {
        switch mode {
        case "downloading":
            return items.filter { DownloadsBar.need($0) == nil }
        case "done":
            polls += 1
            return polls <= 1 ? items.filter { DownloadsBar.need($0) == nil } : []
        default:
            return items
        }
    }
    #endif
}
