import SwiftUI
import WidgetKit
import FusionhaKit

/// One v2 Up next row (mock `.wrow`): poster, title over the episode, and on
/// the right the day (when not today), the time and the tickets.
struct V2UpNextRow: View {
    let row: UpNextRow
    var poster = CGSize(width: 28, height: 42)

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(spacing: 11) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: poster.width, height: poster.height)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.system(size: 14.5, weight: .semibold)).lineLimit(1)
                    Text(item.episodeTitle.map { "\(item.code) · \($0)" } ?? item.code)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        let day = WidgetDay.label(item.airDate, hasTime: item.hasTime)
                        if day != "Today" && day != "Tonight" {
                            Text(day).font(.system(size: 10.5, weight: .bold)).foregroundStyle(.secondary)
                        }
                        WidgetAirClock(item: item, size: 13)
                    }
                    WidgetEditionTickets(editions: item.pills)
                }
                .fixedSize()
            }
        }
    }
}

/// Rows split by hairlines, as many as fit.
struct V2UpNextList: View {
    let rows: [UpNextRow]
    var poster = CGSize(width: 28, height: 42)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if i > 0 { WidgetFill(color: .primary.opacity(0.12), accentedOpacity: 0.1).frame(height: 0.5) }
                V2UpNextRow(row: row, poster: poster).padding(.vertical, 5)
            }
        }
    }
}
