import Foundation

/// The Activity tabs' poll pacing. The tab bar keeps Activity alive behind
/// the other tabs, and its polls kept refreshing (and re-rendering) the queue
/// and tasks there while the user was on Library. A hidden Activity tab now
/// waits until it is selected again, then polls within half a second.
enum ActivityPoll {
    /// Sleeps `interval`, then waits while Activity is not the selected tab.
    /// Returns false once the task is cancelled.
    @MainActor
    static func next(after interval: Duration, model: AppModel) async -> Bool {
        try? await Task.sleep(for: interval)
        while !Task.isCancelled, model.tab != .activity {
            try? await Task.sleep(for: .milliseconds(500))
        }
        return !Task.isCancelled
    }
}
