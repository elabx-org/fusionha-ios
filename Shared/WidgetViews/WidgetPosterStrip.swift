import SwiftUI
import WidgetKit
import FusionhaKit

/// One poster tile: the art, an optional caption (title or day) and the
/// edition chips underneath. Never text on the art.
struct WidgetPosterTileItem {
    let poster: Data?
    let url: URL
    var caption: String?
    let pills: [(tier: QualityTier, status: EditionStatus?)]
}

extension RecentImportRow {
    func tile(caption: Bool) -> WidgetPosterTileItem {
        WidgetPosterTileItem(poster: poster, url: WidgetLink.item(item.itemId, fallback: .library),
                             caption: caption ? item.title : nil, pills: item.pills)
    }
}

extension UpNextRow {
    /// Captioned with its day (`Tonight`, `Thu`).
    var tile: WidgetPosterTileItem {
        WidgetPosterTileItem(poster: poster, url: WidgetLink.item(item.itemId, fallback: .calendar),
                             caption: WidgetDay.label(item.airDate, hasTime: item.hasTime), pills: item.pills)
    }
}

/// A row of poster tiles in equal columns; empty columns stay blank.
struct WidgetPosterStrip: View {
    let tiles: [WidgetPosterTileItem]
    let columns: Int
    /// Caps the poster height so the row fits the space it is given.
    var maxPosterHeight: CGFloat?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<columns, id: \.self) { index in
                if index < tiles.count {
                    tile(tiles[index])
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// The whole tile is one link (a rectangular content shape, so taps never
    /// fall through to the widget's URL). The poster's base stays transparent:
    /// an opaque fill there becomes a solid white block in tinted rendering.
    private func tile(_ item: WidgetPosterTileItem) -> some View {
        Link(destination: item.url) {
            VStack(alignment: .leading, spacing: 5) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .frame(maxHeight: maxPosterHeight)
                    .overlay(WidgetPoster(data: item.poster, radius: WidgetStyle.posterRadius))
                    .clipShape(RoundedRectangle(cornerRadius: WidgetStyle.posterRadius, style: .continuous))
                if let caption = item.caption {
                    Text(caption).font(WidgetStyle.caption.weight(.semibold)).lineLimit(1)
                }
                WidgetTierPills(editions: item.pills)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
