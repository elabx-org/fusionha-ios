import SwiftUI
import FusionhaKit

/// The idle page's readiness tiles (mock `tiles`): the range's grabs and
/// imports, the indexers and the disk, two by two, each a small W1 module.
struct V2IdleTiles: View {
    let summary: IdleSummary?
    let week: Bool
    @Environment(\.pagePalette) private var page

    private struct Tile: Identifiable {
        let icon: String
        let caption: String
        let value: String
        let detail: String
        var good = false
        var id: String { caption }
    }

    private var tiles: [Tile] {
        guard let s = summary else {
            return ["Today", "Indexers", "Disk"].map { Tile(icon: "ellipsis", caption: $0, value: "–", detail: "Loading…") }
        }
        let range = week ? s.history.week : s.history.today
        var out = [
            Tile(icon: week ? "calendar" : "arrow.down", caption: week ? "7 days" : "Today",
                 value: "\(range.grabbed) · \(range.imported)",
                 detail: "grabbed · imported · \(range.failed) failed"),
            Tile(icon: "checkmark.circle", caption: "Indexers", value: "\(s.indexers.healthy) of \(s.indexers.total)",
                 detail: s.indexers.backoff > 0 ? "\(s.indexers.backoff) backing off" : "healthy, none backing off",
                 good: s.indexers.backoff == 0 && s.indexers.healthy == s.indexers.total),
        ]
        if let disk = s.disk {
            out.append(Tile(icon: "folder", caption: "Disk", value: ActFmt.bytes(Double(disk.freeBytes)),
                            detail: "free of \(ActFmt.bytes(Double(disk.totalBytes))) · \(disk.roots) roots"))
        }
        out.append(Tile(icon: "tray.and.arrow.down", caption: "Clients", value: "\(s.clients.enabled) of \(s.clients.total)",
                        detail: s.clients.enabled == 0 ? "none ready" : "ready"))
        return out
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(tiles) { tile in
                VStack(alignment: .leading, spacing: 0) {
                    Label(tile.caption, systemImage: tile.icon)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(tile.good ? Theme.doneText : (page?.inkMuted ?? Theme.mut))
                    Text(tile.value)
                        .font(.system(size: 24, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 6)
                    Text(tile.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(page?.inkMuted ?? Theme.mut)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background { ModuleSurface(radius: 18) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
