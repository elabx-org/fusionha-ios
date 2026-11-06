import Foundation
import WidgetKit
import FusionhaKit

/// v2's "Needs you" widget: the queue's held, failed and stuck downloads
/// (`WidgetNeedsYou` in FusionhaKit), the first few with posters.
struct NeedsYouEntry: TimelineEntry, Sendable {
    /// The widget's kind. New in v2 (v1 never had it), so nothing a v1
    /// Home Screen placed depends on it when v2 takes v1's place.
    static let kind = "NeedsYou"

    struct Row: Hashable, Sendable {
        let line: WidgetNeedsYou.Line
        let poster: Data?
    }

    let date: Date
    var needCount = 0
    var rows: [Row] = []
    /// Downloads still moving (the medium widget's foot).
    var movingCount = 0
    var signedIn = true
    var failed = false
    var runId: String?
    var relevanceScore: Float?

    var relevance: TimelineEntryRelevance? { relevanceScore.map { TimelineEntryRelevance(score: $0) } }

    /// High while something waits on the person, so a Smart Stack brings it up.
    static func score(needs: Int) -> Float { needs > 0 ? 0.8 : WidgetStackRelevance.low }

    static let placeholder = NeedsYouEntry(date: .now, needCount: 2, rows: WidgetV2Samples.needs, movingCount: 1)
}

enum NeedsYouLoader {
    /// One queue page (the same call as Downloads), then up to `posters` of the
    /// first three needs' posters (small shows none).
    static func entry(_ client: APIClient, posters: Int, deadline: WidgetDeadline) async -> NeedsYouEntry {
        let page: QueuePage
        do {
            page = try await withTimeout(seconds: deadline.slice(4, reserve: 3)) { try await client.queue(pageSize: 50) }
        } catch {
            return NeedsYouEntry(date: .now, failed: true)
        }
        let summary = WidgetNeedsYou.summary(page.items)
        let lines = Array(summary.needs.prefix(3))
        var images: [Data?] = []
        if posters > 0 {
            images = await WidgetLoader.fetchPosters(lines.prefix(posters).map(\.posterUrl), size: "w92", deadline: deadline)
        }
        let rows = lines.enumerated().map { i, line in
            NeedsYouEntry.Row(line: line, poster: i < images.count ? images[i] : nil)
        }
        return NeedsYouEntry(date: .now, needCount: summary.needCount, rows: rows,
                             movingCount: summary.movingCount,
                             relevanceScore: NeedsYouEntry.score(needs: summary.needCount))
    }
}
