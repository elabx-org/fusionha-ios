import SwiftUI
import FusionhaKit

/// The Blocklist insight card (web `BlocklistInsight`): the total, the three
/// reason categories and "Retry recoverable".
struct BlocklistInsight: View {
    let total: Int
    let counts: [BlocklistCategory: Int]
    let busy: Bool
    let onRetry: () async -> Void

    var body: some View {
        let recoverable = counts[.recoverable] ?? 0
        VStack(alignment: .leading, spacing: 14) {
            ActFlow(spacing: 22, lineSpacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(total)").font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.txt)
                        .contentTransition(.numericText(value: Double(total)))
                    Text("BLOCKLISTED · NEVER RE-GRABBED").font(.system(size: 11, weight: .semibold)).tracking(0.5).foregroundStyle(Theme.dim)
                }
                ForEach([BlocklistCategory.recoverable, .manual, .permanent], id: \.self) { cat in
                    HStack(spacing: 8) {
                        Image(systemName: cat.icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(cat.color)
                            .frame(width: 24, height: 24).background(cat.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                        Text("\(counts[cat] ?? 0)").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.txt)
                        Text(cat == .recoverable ? "dead NZB" : (cat == .manual ? "manual" : "bad content"))
                            .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Theme.panel2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if recoverable > 0 {
                HStack(spacing: 10) {
                    (Text("\(recoverable) dead-NZB").bold().foregroundColor(Theme.txt)
                     + Text(" may have recovered. Retry to re-check the source"))
                        .font(.system(size: 12.5)).foregroundStyle(Theme.mut)
                    Spacer(minLength: 0)
                    ActAsyncButton(label: "Retry recoverable", kind: .amber, externalWorking: busy) {
                        await onRetry(); return true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line))
    }
}

/// Un-blocklist calls shared by the tab's rows, bulk bar and Retry recoverable.
enum BlocklistOps {
    /// Removes every entry, then fires one search per distinct item/version/episode.
    static func remove(_ client: APIClient, _ entries: [BlocklistEntry], search: Bool) async throws {
        if entries.count == 1 {
            try await client.deleteBlocklistEntry(id: entries[0].id)
        } else {
            try await client.deleteBlocklistEntries(ids: entries.map(\.id))
        }
        guard search else { return }
        var keys = Set<String>()
        for e in entries {
            guard let item = e.mediaItemId else { continue }
            guard keys.insert("\(item)-\(e.editionId ?? -1)-\(e.episodeId ?? -1)").inserted else { continue }
            try? await client.runSearch(itemId: item, editionId: e.editionId, episodeId: e.episodeId)
        }
    }
}
