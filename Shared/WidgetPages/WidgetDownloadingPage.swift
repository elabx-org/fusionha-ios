import SwiftUI
import WidgetKit
import FusionhaKit

/// Downloading, medium and large: each download's poster, title, HD/4K chip
/// and progress bar with time left. Large leads with the top download as a
/// hero (big percentage), then up to four more rows.
struct WidgetDownloadingPage: View {
    let rows: [DownloadsEntry.Row]
    let large: Bool

    var body: some View {
        if rows.isEmpty {
            WidgetStatusMessage(icon: "checkmark.circle.fill", text: "All caught up",
                                detail: "Nothing downloading", tint: Theme.done)
        } else {
            VStack(alignment: .leading, spacing: WidgetStyle.rowGap) {
                if large, let top = rows.first {
                    link(top) { WidgetDownloadHero(row: top) }
                        .padding(.bottom, 4)
                }
                ForEach(Array(listed.enumerated()), id: \.offset) { _, row in
                    link(row) { WidgetDownloadRow(row: row) }
                }
            }
        }
    }

    private var listed: [DownloadsEntry.Row] {
        large ? Array(rows.dropFirst().prefix(4)) : Array(rows.prefix(2))
    }

    private func link<Content: View>(_ row: DownloadsEntry.Row, @ViewBuilder _ content: () -> Content) -> some View {
        WidgetRowLink(url: WidgetLink.item(row.itemId, fallback: .activity)) { content() }
    }
}

/// Poster, title and chip, then the progress bar and time left: two lines.
struct WidgetDownloadRow: View {
    let row: DownloadsEntry.Row

    var body: some View {
        HStack(spacing: 10) {
            WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                .frame(width: WidgetStyle.rowPoster * 2 / 3, height: WidgetStyle.rowPoster)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(row.title).font(WidgetStyle.title).lineLimit(1)
                    Spacer(minLength: 0)
                    WidgetTierPill(tier: row.tier, status: row.status)
                }
                HStack(spacing: 8) {
                    WidgetBar(fraction: row.fraction, tint: row.tint)
                    Text(row.shortCaption)
                        .font(WidgetStyle.caption.monospacedDigit())
                        .foregroundStyle(row.stalled ? Theme.stuck : .secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
    }
}

/// The top download, large: a bigger poster, the title on up to two lines,
/// the chip, and a big percentage over its bar.
struct WidgetDownloadHero: View {
    let row: DownloadsEntry.Row

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                .frame(width: 56, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title).font(WidgetStyle.heroTitle).lineLimit(2)
                WidgetTierPill(tier: row.tier, status: row.status)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(row.percent)%").font(WidgetStyle.numeral(26)).widgetAccentable()
                    Text(row.timeNote ?? "").font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                WidgetBar(fraction: row.fraction, tint: row.tint, height: 6)
            }
        }
        .frame(height: 84)
    }
}

extension DownloadsEntry.Row {
    var percent: Int { Int((fraction * 100).rounded()) }
    var status: EditionStatus { stalled ? .stuck : .downloading }
    var tint: Color { stalled ? Theme.stuck : Theme.grab }
    /// `Stalled`, `12m left`, `Importing`; nil when unknown.
    var timeNote: String? { stalled ? "Stalled" : timeLeft }
    /// The row's one caption: time left when known, else the percentage.
    var shortCaption: String { timeNote ?? "\(percent)%" }
}
