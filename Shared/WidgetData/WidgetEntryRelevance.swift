import WidgetKit

// Smart Stack relevance: each entry carries a plain score (`WidgetStackRelevance`
// rules in FusionhaKit) and hands WidgetKit the matching relevance.

extension DownloadsEntry {
    var relevance: TimelineEntryRelevance? { relevanceScore.map { TimelineEntryRelevance(score: $0) } }
}

extension UpNextEntry {
    var relevance: TimelineEntryRelevance? { relevanceScore.map { TimelineEntryRelevance(score: $0) } }
}

extension RecentEntry {
    var relevance: TimelineEntryRelevance? { relevanceScore.map { TimelineEntryRelevance(score: $0) } }
}
