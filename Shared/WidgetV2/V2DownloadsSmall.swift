import SwiftUI
import WidgetKit
import FusionhaKit

/// v2 Downloads, small (mock Browse › Widgets): the download count big, and
/// the first two in words ("VisionQuest HD 62% · Wicked 4K importing").
/// Idle: "All caught up".
struct V2DownloadsSmall: View {
    let entry: DownloadsEntry

    var body: some View {
        if entry.rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                WidgetCountHeader(symbol: "arrow.down.circle.fill", title: "Downloads", tint: .secondary)
                WidgetStatusMessage(icon: "checkmark.circle", text: "All caught up")
            }
        } else {
            WidgetCountFace(symbol: "arrow.down.circle.fill", title: "Downloads", count: max(entry.total, entry.rows.count),
                            detail: entry.rows.prefix(2).map(Self.words).joined(separator: " · "))
        }
    }

    /// "VisionQuest HD 62%": the title without its episode, the version, then
    /// the percent, or the phase while it imports or stalls.
    static func words(_ row: DownloadsEntry.Row) -> String {
        let title = row.title.components(separatedBy: " · ").first ?? row.title
        let state: String
        if row.stalled { state = "stalled" }
        else if row.timeLeft == "Importing" { state = "importing" }
        else { state = "\(Int((row.fraction * 100).rounded()))%" }
        return "\(title) \(row.tier.badgeLetters) \(state)"
    }
}
