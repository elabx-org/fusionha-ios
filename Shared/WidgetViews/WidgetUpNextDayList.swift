import SwiftUI
import WidgetKit
import FusionhaKit

/// Up next rows under day headings (`Today`, `Tomorrow`, `Thu`), times on the rows.
struct WidgetUpNextDayList: View {
    let rows: [UpNextRow]
    var posterHeight: CGFloat = 36

    var body: some View {
        let days = rows.map { WidgetFeeds.whenLabel($0.item.airDate, hasTime: false) }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == 0 || days[index] != days[index - 1] {
                    Text(days[index].uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                        .padding(.top, index == 0 ? 0 : 2)
                }
                WidgetUpNextRow(row: row, posterHeight: posterHeight, timeOnly: true)
            }
        }
    }
}
