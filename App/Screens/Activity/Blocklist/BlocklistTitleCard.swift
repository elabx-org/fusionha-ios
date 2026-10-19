import SwiftUI
import FusionhaKit

/// "Group by title" (web `BlocklistTitleCard`): a title header over its
/// dupe-collapsed releases (title + release + reason), open by default.
struct BlocklistTitleCard<Row: View>: View {
    let group: BlocklistGrouping.Title
    @ViewBuilder let row: (BlocklistGrouping.Release) -> Row
    @Environment(AppModel.self) private var model

    var body: some View {
        let lead = group.entries[0]
        let newest = group.entries.compactMap { ActFmt.date($0.createdAt) }.max()
        let releases = group.releases
        ActGroupCard(wash: nil, base: Theme.panel) {
            ActPoster(url: lead.posterUrl, title: lead.itemTitle ?? lead.title, size: .md)
        } title: {
            VStack(alignment: .leading, spacing: 5) {
                Text(lead.itemTitle ?? "Unknown title").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.txt).lineLimit(2)
                    .onTapGesture { if let id = lead.mediaItemId { model.open(id) } }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.danger).frame(width: 6, height: 6)
                    Text("\(group.entries.count) blocked")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.mut)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 8))
            }
        } trailing: {
            Text(newest.map { ActFmt.relative($0) } ?? "").font(.system(size: 11.5, design: .monospaced)).foregroundStyle(Theme.dim)
        } content: {
            VStack(spacing: 0) {
                ForEach(Array(releases.enumerated()), id: \.element.key) { index, release in
                    if index > 0 { Rectangle().fill(Theme.line).frame(height: 1) }
                    row(release)
                }
            }
        }
    }
}
