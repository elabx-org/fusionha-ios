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

    /// The whole tile (poster, title, pills) is one link to the title. The poster
    /// sits on a solid frame and the label carries a rectangular content shape: a
    /// `Color.clear` base with the poster only in an overlay left the tile without
    /// a tap region, so taps fell through to the widget's URL (Activity on the
    /// Downloads widget). A row with no item id opens Library, never Activity.
    private func tile(_ row: RecentImportRow) -> some View {
        Link(destination: WidgetLink.item(row.item.itemId, fallback: .library)) {
            VStack(alignment: .leading, spacing: 4) {
                Theme.card
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
