import SwiftUI
import WidgetKit
import FusionhaKit

/// Wanted: missing, 4K available and cutoff-unmet counts, then the latest
/// missing titles (each opens its item).
struct WidgetWantedPage: View {
    let summary: WidgetWantedSummary?
    let posters: [Data?]
    let large: Bool

    var body: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: large ? 8 : 6) {
                HStack(spacing: 6) {
                    WidgetStatTile(value: "\(s.missing)", label: "Missing", color: Theme.miss)
                    if let fourK = s.fourKAvailable {
                        WidgetStatTile(value: "\(fourK)", label: "4K available", color: Theme.grab)
                    }
                    if let cutoff = s.cutoffUnmet {
                        WidgetStatTile(value: "\(cutoff)", label: "Cutoff unmet", color: Theme.edition)
                    }
                }
                if large && !s.rows.isEmpty { WidgetSectionLabel("Latest missing") }
                ForEach(Array(s.rows.prefix(large ? 3 : 2).enumerated()), id: \.offset) { index, row in
                    WidgetWantedLine(row: row, poster: index < posters.count ? posters[index] : nil,
                                     posterHeight: large ? 36 : 28)
                }
                if s.rows.isEmpty { WidgetEmptyText("Nothing missing") }
            }
        } else {
            WidgetEmptyText("Wanted unavailable")
        }
    }
}

struct WidgetWantedLine: View {
    let row: WidgetWantedRow
    let poster: Data?
    var posterHeight: CGFloat = 36

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(row.itemId, fallback: .wanted)) {
            HStack(spacing: 8) {
                WidgetPoster(data: poster)
                    .frame(width: posterHeight * 2 / 3, height: posterHeight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(row.detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                WidgetTierPills(editions: row.tiers.map { (tier: $0, status: EditionStatus.missing) })
            }
        }
    }
}
