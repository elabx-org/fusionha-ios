import SwiftUI
import WidgetKit
import FusionhaKit

/// Library, medium and large: movies, series and anime as big numbers in
/// their kind colours, the 4K coverage bar, and the Wanted line (missing ·
/// cutoff unmet). Large adds the Complete / Downloading / Missing / Upcoming tiles.
struct WidgetLibraryPage: View {
    let summary: WidgetLibrarySummary?
    let wanted: WidgetWantedSummary?
    let large: Bool

    var body: some View {
        if let s = summary {
            VStack(alignment: .leading, spacing: large ? 16 : 10) {
                kinds(s)
                WidgetCoverageLine(summary: s)
                if let wanted { WidgetWantedSummaryLine(summary: wanted) }
                if large { statuses(s) }
            }
        } else {
            WidgetStatusMessage(icon: "square.stack", text: "Library unavailable")
        }
    }

    private func kinds(_ s: WidgetLibrarySummary) -> some View {
        HStack(alignment: .top, spacing: 0) {
            WidgetNumber(value: s.movies.formatted(), caption: "Movies", size: 30, tint: Theme.kindMovie)
                .frame(maxWidth: .infinity, alignment: .leading)
            WidgetNumber(value: s.series.formatted(), caption: "Series", size: 30, tint: Theme.kindSeries)
                .frame(maxWidth: .infinity, alignment: .leading)
            WidgetNumber(value: s.anime.formatted(), caption: "Anime", size: 30, tint: Theme.kindAnime)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statuses(_ s: WidgetLibrarySummary) -> some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                WidgetStatTile(value: "\(s.complete)", label: "Complete", color: CardStatus.complete.color)
                WidgetStatTile(value: "\(s.downloading)", label: "Downloading", color: CardStatus.downloading.color)
            }
            GridRow {
                WidgetStatTile(value: "\(s.missing)", label: "Missing", color: CardStatus.missing.color)
                WidgetStatTile(value: "\(s.upcoming)", label: "Upcoming", color: CardStatus.upcoming.color)
            }
        }
    }
}

/// `[4K] ━━━━──────── 312 titles`: titles with a 4K version.
struct WidgetCoverageLine: View {
    let summary: WidgetLibrarySummary

    var body: some View {
        HStack(spacing: 8) {
            WidgetTag(text: "4K", color: QualityTier.uhd.color)
            WidgetBar(fraction: Double(summary.fourKPercent) / 100, tint: QualityTier.uhd.color, height: 6)
            Text("\(summary.fourKTitles.formatted()) titles")
                .font(WidgetStyle.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("4K on \(summary.fourKTitles) titles, \(summary.fourKPercent) percent")
    }
}

/// `[WANTED] 41 missing · 9 cutoff unmet`.
struct WidgetWantedSummaryLine: View {
    let summary: WidgetWantedSummary

    var body: some View {
        HStack(spacing: 8) {
            WidgetTag(text: "Wanted", color: Theme.miss)
            Text(text).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private var text: String {
        var parts = ["\(summary.missing.formatted()) missing"]
        if let cutoff = summary.cutoffUnmet { parts.append("\(cutoff.formatted()) cutoff unmet") }
        return parts.joined(separator: " · ")
    }
}

/// A small filled label (`4K`, `WANTED`).
struct WidgetTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .fixedSize()
            .widgetAccentable()
    }
}
