import SwiftUI
import WidgetKit
import FusionhaKit

/// Up next, small: when the next item airs (big), its poster, title, and
/// code with the edition pills. One item, shown well.
struct WidgetUpNextSmall: View {
    let row: UpNextRow

    var body: some View {
        let item = row.item
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Up next")
            Spacer(minLength: 6)
            HStack(alignment: .top, spacing: 8) {
                WidgetAirTime(item: item, size: 24)
                Spacer(minLength: 0)
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: 34, height: 51)
            }
            Spacer(minLength: 4)
            Text(item.title).font(WidgetStyle.title).lineLimit(2)
            HStack(spacing: 4) {
                Text(item.code).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 2)
                WidgetTierPills(editions: item.pills)
            }
            .padding(.top, 3)
        }
    }
}
