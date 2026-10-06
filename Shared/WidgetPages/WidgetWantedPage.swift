import SwiftUI
import WidgetKit
import FusionhaKit

/// Wanted (paged widget only). Medium: the missing count big, 4K available and
/// cutoff unmet beneath it, beside the latest missing titles. Large: the
/// three counts as tiles, then the latest missing titles.
struct WidgetWantedPage: View {
    let summary: WidgetWantedSummary?
    let posters: [Data?]
    let large: Bool

    var body: some View {
        if let s = summary {
            if large { largeBody(s) } else { mediumBody(s) }
        } else {
            WidgetStatusMessage(icon: "exclamationmark.magnifyingglass", text: "Wanted unavailable")
        }
    }

    private func mediumBody(_ s: WidgetWantedSummary) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetNumber(value: "\(s.missing)", caption: "missing", size: 38, tint: Theme.miss)
                Spacer(minLength: 4)
                if let fourK = s.fourKAvailable { WidgetDotLine(color: Theme.grab, text: "\(fourK) 4K available") }
                if let cutoff = s.cutoffUnmet { WidgetDotLine(color: Theme.edition, text: "\(cutoff) cutoff unmet") }
            }
            .frame(width: 112, alignment: .leading)
            VStack(alignment: .leading, spacing: WidgetStyle.rowGap) {
                rows(s, limit: 2)
                if s.rows.isEmpty { WidgetEmptyText("Nothing missing") }
            }
        }
    }

    private func largeBody(_ s: WidgetWantedSummary) -> some View {
        VStack(alignment: .leading, spacing: WidgetStyle.rowGap + 2) {
            HStack(spacing: 8) {
                WidgetStatTile(value: "\(s.missing)", label: "Missing", color: Theme.miss)
                if let fourK = s.fourKAvailable { WidgetStatTile(value: "\(fourK)", label: "4K available", color: Theme.grab) }
                if let cutoff = s.cutoffUnmet { WidgetStatTile(value: "\(cutoff)", label: "Cutoff unmet", color: Theme.edition) }
            }
            if s.rows.isEmpty {
                WidgetStatusMessage(icon: "checkmark.circle.fill", text: "Nothing missing", tint: Theme.done)
            } else {
                WidgetSectionLabel("Latest missing").padding(.top, 4)
                rows(s, limit: 3)
            }
        }
    }

    private func rows(_ s: WidgetWantedSummary, limit: Int) -> some View {
        ForEach(Array(s.rows.prefix(limit).enumerated()), id: \.offset) { index, row in
            WidgetWantedLine(row: row, poster: index < posters.count ? posters[index] : nil)
        }
    }
}

/// A missing title: poster, title, `3 episodes`, and its missing tiers.
struct WidgetWantedLine: View {
    let row: WidgetWantedRow
    let poster: Data?
    var posterHeight: CGFloat = WidgetStyle.rowPoster

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(row.itemId, fallback: .wanted)) {
            HStack(spacing: 10) {
                WidgetPoster(data: poster, radius: WidgetStyle.posterRadius)
                    .frame(width: posterHeight * 2 / 3, height: posterHeight)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(WidgetStyle.title).lineLimit(1)
                    Text(row.detail).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                WidgetTierPills(editions: row.tiers.map { (tier: $0, status: EditionStatus.missing) })
            }
        }
    }
}
