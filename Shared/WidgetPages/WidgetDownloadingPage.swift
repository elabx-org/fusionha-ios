import SwiftUI
import WidgetKit
import FusionhaKit

/// Downloading, medium and large. Medium: the top download as a hero (big
/// poster, title and chip, bar, `72% · 6m left · 41.2 GB`) and a `+2 more`
/// line. Large: up to four rows, each poster, title and chip, bar and
/// `72% · 6m left`; a stalled row turns amber.
struct WidgetDownloadingPage: View {
    let rows: [DownloadsEntry.Row]
    let total: Int
    let large: Bool

    var body: some View {
        if let top = rows.first {
            if large {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(rows.prefix(4).enumerated()), id: \.offset) { _, row in
                        link(row) { WidgetDownloadRow(row: row) }
                    }
                }
            } else {
                WidgetDownloadHero(row: top, more: total - 1, next: rows.dropFirst().first)
            }
        } else {
            WidgetStatusMessage(icon: "checkmark.circle.fill", text: "All caught up",
                                detail: "Nothing downloading", tint: Theme.done)
        }
    }

    private func link<Content: View>(_ row: DownloadsEntry.Row, @ViewBuilder _ content: () -> Content) -> some View {
        WidgetRowLink(url: WidgetLink.item(row.itemId, fallback: .activity)) { content() }
    }
}

/// A large-widget row: poster, title and chip, the bar, and its caption.
struct WidgetDownloadRow: View {
    let row: DownloadsEntry.Row

    var body: some View {
        HStack(spacing: 12) {
            WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                .frame(width: 40, height: 60)
            VStack(alignment: .leading, spacing: 7) {
                WidgetTitleChip(title: row.title, tier: row.tier, status: row.status)
                WidgetBar(fraction: row.stalled ? 1 : row.fraction, tint: row.tint)
                Text(row.stalled ? "Stalled · tap to open Activity" : row.caption(withSize: false))
                    .font(WidgetStyle.caption.monospacedDigit())
                    .foregroundStyle(row.stalled ? Theme.stuck : .secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// The medium hero: the top download big (poster and text open it), then
/// `+2 more · Severance S02E04` (opens the next one).
struct WidgetDownloadHero: View {
    let row: DownloadsEntry.Row
    let more: Int
    let next: DownloadsEntry.Row?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            WidgetRowLink(url: url(row)) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: 66, height: 99)
            }
            VStack(alignment: .leading, spacing: 8) {
                WidgetRowLink(url: url(row)) {
                    VStack(alignment: .leading, spacing: 8) {
                        WidgetTitleChip(title: row.title, tier: row.tier, status: row.status, font: WidgetStyle.heroTitle)
                        WidgetBar(fraction: row.fraction, tint: row.tint, height: 6)
                        Text(row.caption(withSize: true))
                            .font(WidgetStyle.caption.monospacedDigit())
                            .foregroundStyle(row.stalled ? Theme.stuck : .secondary)
                            .lineLimit(1)
                    }
                }
                if more > 0 {
                    WidgetRowLink(url: next.map(url) ?? WidgetLink.activity) { moreLine }
                }
            }
        }
    }

    private func url(_ row: DownloadsEntry.Row) -> URL {
        WidgetLink.item(row.itemId, fallback: .activity)
    }

    private var moreLine: some View {
        HStack(spacing: 5) {
            Text("+\(more) more" + (next.map { " · \($0.title)" } ?? ""))
                .font(WidgetStyle.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let next { WidgetTierPill(tier: next.tier, status: next.status) }
        }
    }
}

/// A title with its tier chip right after it (one line).
struct WidgetTitleChip: View {
    let title: String
    let tier: QualityTier
    var status: EditionStatus?
    var font: Font = WidgetStyle.rowTitle

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(font).lineLimit(1)
            WidgetTierPill(tier: tier, status: status).fixedSize()
        }
    }
}

extension DownloadsEntry.Row {
    var percent: Int { Int((fraction * 100).rounded()) }
    var status: EditionStatus { stalled ? .stuck : .downloading }
    var tint: Color { stalled ? Theme.stuck : Theme.grab }
    /// `Stalled`, `12m left`, `Importing`; nil when unknown.
    var timeNote: String? { stalled ? "Stalled" : timeLeft }

    /// `72% · 6m left · 41.2 GB` (size only when asked and known).
    func caption(withSize: Bool) -> String {
        var parts = ["\(percent)%"]
        if let note = timeNote { parts.append(note) }
        if withSize, size > 0 { parts.append(WidgetDownloadStats.sizeLabel(size)) }
        return parts.joined(separator: " · ")
    }
}
