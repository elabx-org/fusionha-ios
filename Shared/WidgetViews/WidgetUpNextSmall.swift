import SwiftUI
import WidgetKit
import FusionhaKit

/// Up next, small: the next airing's poster beside its time (big) and day,
/// then its title and episode, with the edition chips.
struct WidgetUpNextSmall: View {
    let row: UpNextRow

    var body: some View {
        let item = row.item
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Up next")
            Spacer(minLength: 6)
            HStack(alignment: .center, spacing: 10) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: 44, height: 66)
                VStack(alignment: .leading, spacing: 2) {
                    WidgetAirClock(item: item, size: 26).widgetAccentable()
                    Text(WidgetDay.label(item.airDate, hasTime: item.hasTime))
                        .font(WidgetStyle.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    WidgetTierPills(editions: item.pills).padding(.top, 2)
                }
            }
            Spacer(minLength: 6)
            Text("\(item.title) · \(item.code)").font(WidgetStyle.title).lineLimit(2)
        }
    }
}
