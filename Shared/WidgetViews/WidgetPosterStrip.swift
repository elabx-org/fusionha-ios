import SwiftUI
import WidgetKit
import FusionhaKit

/// A row of posters with their edition pills (and titles on the large family).
struct WidgetPosterStrip: View {
    let rows: [RecentImportRow]
    let columns: Int
    let showsTitle: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<columns, id: \.self) { index in
                if index < rows.count {
                    tile(rows[index])
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// The whole tile (poster, title, pills) is one link to the title; the label's
    /// rectangular content shape gives it a tap region (taps never fall through to
    /// the widget's URL). The poster's base stays transparent: an opaque fill
    /// there becomes a solid white block in accented (tinted) rendering. A row
    /// with no item id opens Library, never Activity.
    private func tile(_ row: RecentImportRow) -> some View {
        Link(destination: WidgetLink.item(row.item.itemId, fallback: .library)) {
            VStack(alignment: .leading, spacing: 4) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay(WidgetPoster(data: row.poster, radius: 6))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                if showsTitle {
                    Text(row.item.title)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                }
                WidgetTierPills(editions: row.item.pills)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
