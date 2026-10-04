import ActivityKit
import Foundation

/// One aggregate Live Activity for the whole queue (not one per download), which
/// keeps us inside Apple's update budget and mirrors the web's single activity pulse.
struct DownloadsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var activeCount: Int
        /// 0–1 across all active downloads, weighted by size.
        var overallFraction: Double
        var topTitle: String
        var topTierLabel: String
        var topPhase: String?
        var topPosterURL: URL?
        var stuck: Bool
        var finished: Bool
    }
}
