import SwiftUI
import WidgetKit
import FusionhaKit

/// Recently added, small: the latest import's poster, title, when, and pills.
struct WidgetRecentSmall: View {
    let row: RecentImportRow

    var body: some View {
        let item = row.item
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBar(title: "Recently added")
            Spacer(minLength: 8)
            HStack(alignment: .bottom, spacing: 10) {
                WidgetPoster(data: row.poster, radius: WidgetStyle.posterRadius)
                    .frame(width: 58, height: 87)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(WidgetStyle.title).lineLimit(3)
                    if let at = item.importedAt {
                        Text(WidgetFeeds.agoLabel(at)).font(WidgetStyle.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    WidgetTierPills(editions: item.pills)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
