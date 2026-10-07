import SwiftUI
import WidgetKit
import FusionhaKit

/// Recently added, small: the latest import's poster edge to edge (the whole
/// poster on a wash of itself, `WidgetPosterHero`), with its
/// title, chips and `Added 12m ago` on a strip underneath (never on the art).
/// `bleed` needs the widget's content margins off; the paged Downloads widget
/// (margins on) shows the inset version under its header.
struct WidgetRecentSmall: View {
    let row: RecentImportRow
    var bleed = false
    @Environment(\.widgetContentMargins) private var margins

    var body: some View {
        if bleed {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear
                    .overlay(WidgetPosterHero(data: row.poster))
                    .clipped()
                caption.padding(.horizontal, inset).padding(.vertical, 10)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                WidgetTopBar(title: "Recently added")
                Color.clear
                    .overlay(WidgetPoster(data: row.poster, radius: 0))
                    .clipShape(RoundedRectangle(cornerRadius: WidgetStyle.posterRadius, style: .continuous))
                caption
            }
        }
    }

    private var inset: CGFloat { max(margins.leading, 14) }

    private var caption: some View {
        let item = row.item
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.title).font(WidgetStyle.title).lineLimit(1)
                WidgetTierPills(editions: item.pills)
            }
            if let at = item.importedAt {
                Text("Added \(WidgetFeeds.agoLabel(at))")
                    .font(WidgetStyle.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
