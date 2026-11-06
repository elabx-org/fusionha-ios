import Foundation
import FusionhaKit

/// v2 widget placeholders and the gallery's staged queue (the v2 mock's
/// 17:16 snapshot: two holds, one download, one import).
enum WidgetV2Samples {
    static let needs: [NeedsYouEntry.Row] = [
        NeedsYouEntry.Row(line: WidgetNeedsYou.Line(downloadId: 1, mediaItemId: 0, short: "VisionQuest E7 4K",
                                                    title: "VisionQuest · S01E07", detail: "not really 2160p",
                                                    tier: .uhd, posterUrl: nil), poster: nil),
        NeedsYouEntry.Row(line: WidgetNeedsYou.Line(downloadId: 2, mediaItemId: 0, short: "The Office S5 pack HD",
                                                    title: "The Office · S05", detail: "splits an episode pair",
                                                    tier: .hd, posterUrl: nil), poster: nil),
    ]
}
