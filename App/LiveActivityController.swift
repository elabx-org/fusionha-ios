import ActivityKit
import Foundation
import FusionhaKit

/// Starts, updates and ends the single "Downloads" Live Activity from app-side
/// polling. Updating it while the app is closed needs server pushes (see the plan).
@MainActor
enum LiveActivityController {
    private static var lastState: DownloadsActivityAttributes.ContentState?

    static func sync(with items: [QueueItem]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let current = Activity<DownloadsActivityAttributes>.activities.first

        guard let top = items.first else {
            if let current, var finished = lastState {
                finished.finished = true
                finished.activeCount = 0
                finished.overallFraction = 1
                let content = ActivityContent(state: finished, staleDate: nil)
                Task { await current.end(content, dismissalPolicy: .after(.now + 15 * 60)) }
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

        let content = ActivityContent(state: state, staleDate: .now + 120)
        if let current {
            Task { await current.update(content) }
        } else {
            _ = try? Activity.request(attributes: DownloadsActivityAttributes(), content: content, pushType: nil)
        }
    }

    static func endAll() {
        for activity in Activity<DownloadsActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        lastState = nil
    }
}
