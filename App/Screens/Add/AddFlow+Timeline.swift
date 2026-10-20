import SwiftUI
import FusionhaKit

extension AddFlow {
    // MARK: Monitor counts + timeline

    /// The master's (or a mode's) episode count for the sentence; nil without seasons.
    func monitorSummary(_ mode: String, withCustom: Bool) -> AddSentence.Monitor? {
        guard let seasons, !seasons.isEmpty else { return nil }
        let base = MonitorPreview.compute(seasons, mode: mode)
        let p = withCustom ? SeasonSlider.apply(seasons, base, seasonFrom) : base
        return AddSentence.Monitor(mode: mode, count: p.count, exact: p.exact)
    }

    func timeline(today: Date = Date()) -> ReleaseTimelineModel {
        ReleaseTimelineModel.build(preview?.timelineDates ?? TimelineDates(), today: today)
    }

    /// Nothing is out yet, so a 4K miss means "searched on release".
    func notOutYet(_ timeline: ReleaseTimelineModel) -> Bool {
        if isSeries {
            guard let seasons, !seasons.isEmpty else { return false }
            return seasons.allSatisfy { $0.airedCount == 0 }
        }
        return preview?.status != "Released" && !timeline.releasedOut()
    }
}
