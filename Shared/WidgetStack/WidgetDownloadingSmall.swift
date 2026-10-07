import SwiftUI
import WidgetKit
import FusionhaKit

/// Downloading, small: a ring with the download count in it (the top
/// download's progress), its percentage, speed and time left beside it, and
/// the top title with its chip. Idle: a calm "All caught up".
struct WidgetDownloadingSmall: View {
    let entry: DownloadsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Downloading")
            if let row = entry.rows.first {
                Spacer(minLength: 6)
                HStack(spacing: 12) {
                    WidgetRing(fraction: row.fraction, tint: row.tint, lineWidth: 7) {
                        Text("\(entry.total)").font(WidgetStyle.numeral(22)).widgetAccentable()
                    }
                    .frame(width: 62, height: 62)
                    figures(row)
                }
                Spacer(minLength: 6)
                WidgetTitleChip(title: row.title, tier: row.tier, status: row.status, font: WidgetStyle.title)
            } else {
                WidgetStatusMessage(icon: "checkmark.circle.fill", text: "All caught up", tint: Theme.done)
            }
        }
    }

    private func figures(_ row: DownloadsEntry.Row) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(row.percent)%").font(WidgetStyle.numeral(18))
            if row.stalled {
                Text("Stalled").font(WidgetStyle.caption).foregroundStyle(Theme.stuck)
            } else {
                if let rate = row.rate {
                    Text(WidgetDownloadStats.rateLabel(rate)).font(WidgetStyle.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let left = row.timeLeft {
                    Text(left).font(WidgetStyle.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
    }
}
