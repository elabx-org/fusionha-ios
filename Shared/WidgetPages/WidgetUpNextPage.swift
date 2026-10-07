import SwiftUI
import WidgetKit
import FusionhaKit

/// Up next. Medium: the next four as posters with their day and chips.
/// Large: the next airings under day headings (`Tonight`, `Thursday`), each
/// with its poster, title, episode, time and chips; as many as fit.
struct WidgetUpNextPage: View {
    let rows: [UpNextRow]
    let large: Bool

    var body: some View {
        if rows.isEmpty {
            WidgetStatusMessage(icon: "calendar", text: "Nothing airing soon",
                                detail: "Next 30 days", tint: Theme.unaired)
        } else if large {
            ViewThatFits(in: .vertical) {
                WidgetUpNextDayList(rows: Array(rows.prefix(4)))
                WidgetUpNextDayList(rows: Array(rows.prefix(3)))
                WidgetUpNextDayList(rows: Array(rows.prefix(2)))
            }
        } else {
            GeometryReader { geo in
                WidgetPosterStrip(tiles: rows.prefix(4).map(\.tile), columns: 4,
                                  maxPosterHeight: max(40, geo.size.height - 41))
            }
        }
    }
}

/// Up next rows under a heading for each new day.
struct WidgetUpNextDayList: View {
    let rows: [UpNextRow]

    var body: some View {
        let days = rows.map { WidgetDay.label($0.item.airDate, hasTime: $0.item.hasTime, long: true) }
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == 0 || days[index] != days[index - 1] {
                    Text(days[index])
                        .font(WidgetStyle.title)
                        .padding(.top, index == 0 ? 0 : 4)
                }
                WidgetUpNextRow(row: row)
            }
        }
    }
}
