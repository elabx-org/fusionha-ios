import SwiftUI
import WidgetKit
import FusionhaKit

/// Downloading, small: the top download's progress ring with its percentage,
/// chip and time left, and its title. Idle: a calm "All caught up".
struct WidgetDownloadingSmall: View {
    let entry: DownloadsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Downloading", figure: entry.idle ? nil : "\(entry.total)", tint: Theme.grab)
            if let row = entry.rows.first {
                Spacer(minLength: 6)
                ring(row)
                Spacer(minLength: 6)
                Text(row.title).font(WidgetStyle.title).lineLimit(2)
            } else {
                WidgetStatusMessage(icon: "checkmark.circle.fill", text: "All caught up", tint: Theme.done)
            }
        }
    }

    private func ring(_ row: DownloadsEntry.Row) -> some View {
        HStack(spacing: 10) {
            WidgetRing(fraction: row.fraction, tint: row.tint, lineWidth: 6) {
                Text("\(row.percent)%").font(WidgetStyle.numeral(15)).minimumScaleFactor(0.7)
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 5) {
                WidgetTierPill(tier: row.tier, status: row.status)
                if let note = row.timeNote {
                    Text(note)
                        .font(WidgetStyle.caption.monospacedDigit())
                        .foregroundStyle(row.stalled ? Theme.stuck : .secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
