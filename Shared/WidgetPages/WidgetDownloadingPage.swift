import SwiftUI
import WidgetKit
import FusionhaKit

/// Downloading: each download's poster, title, HD/4K chip, progress and time left.
struct WidgetDownloadingPage: View {
    let rows: [DownloadsEntry.Row]
    let large: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 8 : 6) {
            if rows.isEmpty {
                WidgetEmptyText("Nothing downloading")
            }
            ForEach(Array(rows.prefix(large ? 4 : 2).enumerated()), id: \.offset) { _, row in
                WidgetRowLink(url: WidgetLink.item(row.itemId, fallback: .activity)) {
                    WidgetDownloadRow(row: row)
                }
            }
        }
    }
}

struct WidgetDownloadRow: View {
    let row: DownloadsEntry.Row

    var body: some View {
        HStack(spacing: 8) {
            WidgetPoster(data: row.poster)
                .frame(width: 26, height: 39)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(row.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    WidgetTierPill(tier: row.tier, status: row.stalled ? .stuck : .downloading)
                }
                ProgressView(value: row.fraction).tint(row.stalled ? Theme.stuck : Theme.grab)
                Text(caption)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(row.stalled ? Theme.stuck : .secondary)
                    .lineLimit(1)
            }
        }
    }

    private var caption: String {
        let percent = "\(Int((row.fraction * 100).rounded()))%"
        if row.stalled { return "\(percent) · Stalled" }
        return row.timeLeft.map { "\(percent) · \($0)" } ?? percent
    }
}
