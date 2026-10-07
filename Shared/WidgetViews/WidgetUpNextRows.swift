import SwiftUI
import WidgetKit
import FusionhaKit

/// A large Up next row: poster, title, `S02E05 · Trojan's Horse`, and on the
/// right the air time over the edition chips.
struct WidgetUpNextRow: View {
    let row: UpNextRow

    var body: some View {
        let item = row.item
        WidgetRowLink(url: WidgetLink.item(item.itemId)) {
            HStack(spacing: 12) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: 36, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(WidgetStyle.rowTitle).lineLimit(1)
                    Text(item.episodeTitle.map { "\(item.code) · \($0)" } ?? item.code)
                        .font(WidgetStyle.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    WidgetAirClock(item: item, size: 15)
                    WidgetTierPills(editions: item.pills)
                }
            }
        }
    }
}
