import SwiftUI
import WidgetKit
import FusionhaKit

/// v2 "Needs you" (mock Browse › Widgets): small is the count with the first
/// two holds in words; medium puts the count beside up to three rows (poster,
/// title, the hold in words). Nothing waiting: a calm "Nothing needs you".
struct NeedsYouWidgetView: View {
    let entry: NeedsYouEntry
    let family: WidgetFamily

    static let symbol = "pause.circle.fill"

    var body: some View {
        if !entry.signedIn {
            WidgetSignInPrompt(report: "")
        } else if entry.failed {
            WidgetSmallFailure(title: "Needs you")
        } else if entry.needCount == 0 {
            VStack(alignment: .leading, spacing: 0) {
                WidgetCountHeader(symbol: Self.symbol, title: "Needs you", tint: .secondary)
                WidgetStatusMessage(icon: "checkmark.circle", text: "Nothing needs you",
                                    detail: entry.movingCount > 0 ? "\(entry.movingCount) downloading" : nil)
            }
        } else if family == .systemSmall {
            WidgetCountFace(symbol: Self.symbol, title: "Needs you", count: entry.needCount,
                            detail: WidgetNeedsYou.Summary.joined(entry.rows.map(\.line), withDetail: false),
                            tint: Theme.stuck)
        } else {
            medium
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            WidgetCountFace(symbol: Self.symbol, title: "Needs you", count: entry.needCount,
                            detail: entry.movingCount > 0 ? "+\(entry.movingCount) downloading" : "Review in Activity",
                            tint: Theme.stuck)
                .frame(width: 104)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.rows.prefix(3), id: \.line.downloadId) { NeedsYouRow(row: $0) }
                if entry.needCount > 3 {
                    Text("and \(entry.needCount - 3) more").font(WidgetStyle.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// One hold: poster, title, the reason in the held orange.
private struct NeedsYouRow: View {
    let row: NeedsYouEntry.Row

    var body: some View {
        WidgetRowLink(url: WidgetLink.item(row.line.mediaItemId)) {
            HStack(spacing: 9) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: 24, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(row.line.title).font(WidgetStyle.title).lineLimit(1)
                        EditionBadge(tier: row.line.tier, state: .held)
                            .badgeInk(.page)
                            .widgetAccentable()
                            .fixedSize()
                    }
                    Text(row.line.detail)
                        .font(WidgetStyle.caption)
                        .foregroundStyle(Theme.stuck)
                        .lineLimit(1)
                }
            }
        }
    }
}
