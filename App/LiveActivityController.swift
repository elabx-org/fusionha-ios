import ActivityKit
import Foundation
import FusionhaKit

/// Starts, updates and ends the single "Downloads" Live Activity from app-side
/// polling. Updating it while the app is closed needs server pushes (see the plan).
///
/// The queue is polled every 2 s on the main actor. ActivityKit's
/// `areActivitiesEnabled` and `Activity.activities` are synchronous IPC, so
/// they run on `LiveActivityWorker` (off the main thread), and only when the
/// state actually changed.
@MainActor
enum LiveActivityController {
    private static var lastState: DownloadsActivityAttributes.ContentState?
    private static let worker = LiveActivityWorker()

    static func sync(with items: [QueueItem]) {
        guard let top = items.first else {
            if var finished = lastState {
                finished.finished = true
                finished.activeCount = 0
                finished.overallFraction = 1
                let state = finished
                Task { await worker.end(with: state) }
            }
            lastState = nil
            return
        }

        let totalSize = items.reduce(0) { $0 + $1.size }
        let left = items.reduce(0) { $0 + $1.sizeleft }
        let fraction = totalSize > 0 ? 1 - left / totalSize : top.fraction
        let state = DownloadsActivityAttributes.ContentState(
            activeCount: items.count,
            overallFraction: min(max(fraction, 0), 1),
            topTitle: top.episodeLabel.map { "\(top.title) · \($0)" } ?? top.title,
            topTierLabel: top.tier.chipLabel,
            topPhase: top.phase,
            topPosterURL: TMDBImage.resized(top.posterUrl, to: "w185"),
            stuck: items.contains { $0.stalled },
            finished: false)
        guard state != lastState else { return }
        lastState = state
        Task { await worker.apply(state) }
    }

    static func endAll() {
        lastState = nil
        Task { await worker.endAll() }
    }
}

/// Runs the ActivityKit calls in order, off the main thread.
actor LiveActivityWorker {
    private var current: Activity<DownloadsActivityAttributes>? {
        Activity<DownloadsActivityAttributes>.activities.first
    }

    func apply(_ state: DownloadsActivityAttributes.ContentState) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: .now + 120)
        if let current {
            await current.update(content)
        } else {
            _ = try? Activity.request(attributes: DownloadsActivityAttributes(), content: content, pushType: nil)
        }
    }

    func end(with state: DownloadsActivityAttributes.ContentState) async {
        guard let current else { return }
        await current.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 15 * 60))
    }

    func endAll() async {
        for activity in Activity<DownloadsActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
