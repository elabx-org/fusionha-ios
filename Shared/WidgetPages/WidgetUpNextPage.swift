import SwiftUI
import WidgetKit
import FusionhaKit

/// Up next, medium and large: the next airing as a hero (poster, big air
/// time, title, pills); medium adds the one after it as a single line, large
/// lists up to four more under `LATER`.
struct WidgetUpNextPage: View {
    let rows: [UpNextRow]
    let large: Bool

    var body: some View {
        if let next = rows.first {
            VStack(alignment: .leading, spacing: WidgetStyle.rowGap) {
                WidgetUpNextHero(row: next, posterHeight: large ? 96 : 78)
                if large {
                    later
                } else if rows.count > 1 {
                    WidgetUpNextLine(row: rows[1])
                }
            }
        } else {
            WidgetStatusMessage(icon: "calendar", text: "Nothing airing soon",
                                detail: "Next 30 days", tint: Theme.unaired)
        }
    }

    @ViewBuilder
    private var later: some View {
        let more = Array(rows.dropFirst().prefix(4))
        if !more.isEmpty {
            WidgetSectionLabel("Later").padding(.top, 4)
            ForEach(Array(more.enumerated()), id: \.offset) { _, row in
                WidgetUpNextRow(row: row)
            }
        }
    }
}

/// One compact line under the medium hero: title, when, pills.
struct WidgetUpNextLine: View {
    let row: UpNextRow

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(spacing: 6) {
                Text(item.title).font(WidgetStyle.title).lineLimit(1).layoutPriority(1)
                Text(WidgetFeeds.whenLabel(item.airDate, hasTime: item.hasTime))
                    .font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 4)
                WidgetTierPills(editions: item.pills)
            }
        }
    }
}
