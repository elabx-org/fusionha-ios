import Foundation

/// v2's "Needs you" widget and "Downloads" small widget (v2 mock, Browse ›
/// Widgets): the queue's downloads that wait on the person (held, failed or
/// stuck, ranked as the downloads bar ranks them) and those still moving,
/// each as a short line ("VisionQuest E7 4K", "Wicked importing").
public enum WidgetNeedsYou {
    public struct Line: Sendable, Hashable {
        public let downloadId: Int
        public let mediaItemId: Int
        /// "VisionQuest E7 4K": title, short episode, version.
        public let short: String
        /// "VisionQuest · S01E07": the row's title.
        public let title: String
        /// The need in words ("not an upgrade", "Download failed"), or for a
        /// moving download its percent or phase ("62%", "importing").
        public let detail: String
        public let tier: QualityTier
        public let posterUrl: String?

        public init(downloadId: Int, mediaItemId: Int, short: String, title: String, detail: String,
                    tier: QualityTier, posterUrl: String?) {
            self.downloadId = downloadId
            self.mediaItemId = mediaItemId
            self.short = short
            self.title = title
            self.detail = detail
            self.tier = tier
            self.posterUrl = posterUrl
        }
    }

    public struct Summary: Sendable, Hashable {
        public let needCount: Int
        public let needs: [Line]
        public let movingCount: Int
        public let moving: [Line]

        /// The small widget's line: up to two shorts joined by " · ".
        public static func joined(_ lines: [Line], withDetail: Bool) -> String {
            lines.prefix(2).map { withDetail ? "\($0.short) \($0.detail)" : $0.short }.joined(separator: " · ")
        }
    }

    public static func summary(_ items: [QueueItem]) -> Summary {
        var needs: [Line] = []
        for kind in [DownloadsBar.Need.held, .failed, .stuck] {
            for item in items where DownloadsBar.need(item) == kind {
                needs.append(line(item, detail: DownloadsBar.reason(kind, item)))
            }
        }
        var moving: [Line] = []
        for item in items where DownloadsBar.need(item) == nil {
            moving.append(line(item, detail: movingDetail(item)))
        }
        return Summary(needCount: needs.count, needs: needs, movingCount: moving.count, moving: moving)
    }

    static func line(_ item: QueueItem, detail: String) -> Line {
        let code = DownloadsBar.episodeCode(item.episodeLabel)
        let parts = [item.title, code.map(shortEpisode), item.tier.badgeLetters].compactMap { $0 }
        return Line(downloadId: item.id, mediaItemId: item.mediaItemId,
                    short: parts.joined(separator: " "),
                    title: code.map { "\(item.title) · \($0)" } ?? item.title,
                    detail: detail, tier: item.tier, posterUrl: item.posterUrl)
    }

    static func movingDetail(_ item: QueueItem) -> String {
        if item.phase?.lowercased() == "importing" { return "importing" }
        if item.stalled { return "stalled" }
        return "\(DownloadsBar.clampPercent(item.progress))%"
    }

    /// `S01E07` → `E7`; a full-season pack (`S05`) stays `S5 pack`. Anything
    /// else is kept as it is.
    static func shortEpisode(_ code: String) -> String {
        if let m = code.wholeMatch(of: #/S(\d+)E(\d+)/#), let e = Int(m.2) { return "E\(e)" }
        if let m = code.wholeMatch(of: #/S(\d+)/#), let s = Int(m.1) { return "S\(s) pack" }
        return code
    }
}
