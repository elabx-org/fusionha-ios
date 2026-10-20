import SwiftUI
import FusionhaKit

/// A file's title: "No match", the episode code and its title(s), or the
/// movie and its edition. Takes the caller's font (the card row's 15 pt, the
/// table's Episode cell, the split's detail head).
struct MIRowTitle: View {
    let row: ManualImportRow
    @Environment(ManualImportSession.self) private var session

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if row.match.itemId == nil {
                Label("No match", systemImage: "xmark.circle").foregroundStyle(Theme.danger)
            } else if row.target.isSeries {
                if let code = ManualImportRules.episodeCode(row) {
                    Text(code).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Theme.i2)
                }
                let titles = episodeTitles
                Text(titles.first ?? row.match.title ?? "—").lineLimit(1)
                if titles.count > 1 { Text("+ \(titles.count - 1) more").foregroundStyle(Theme.mut) }
            } else {
                Text(row.match.title ?? row.parsed.title ?? "—").lineLimit(1)
                if let edition = row.target.edition { Text(edition).foregroundStyle(Theme.edition) }
            }
        }
    }

    private var episodeTitles: [String] {
        guard let item = row.match.itemId, let seasons = session.seasons[item] else { return [] }
        let ids = Set(row.target.coveredEpisodeIds)
        return seasons.flatMap(\.episodes).filter { ids.contains($0.id) }
            .sorted { $0.episodeNumber < $1.episodeNumber }.compactMap(\.title)
    }
}
