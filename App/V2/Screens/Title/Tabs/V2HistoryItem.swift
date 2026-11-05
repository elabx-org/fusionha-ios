import Foundation
import FusionhaKit

/// One History row: the event, its version, its time, and (for an import)
/// the file it replaced, folded in from that file's DELETED event (mock
/// browse-title.js `mergeReplaced`).
struct V2HistoryItem: Identifiable {
    let entry: HistoryEntry
    let edition: DetailEdition?
    let date: Date?
    var replaced: String?
    var id: Int { entry.id }

    /// "16:20".
    var time: String {
        date.map { $0.formatted(.dateTime.hour().minute()) } ?? ""
    }

    /// The release's own chips after quality and score: group, then source.
    static func releaseChips(_ entry: HistoryEntry) -> [String] {
        let chips = entry.chips ?? []
        var out: [String] = []
        for kind in ["group", "source"] {
            if let chip = chips.first(where: { $0.kind == kind }), !chip.label.isEmpty, !out.contains(chip.label) {
                out.append(chip.label)
            }
        }
        if out.isEmpty, let indexer = entry.indexer, !indexer.isEmpty { out.append(indexer) }
        return out
    }

    /// Newest first. A DELETED event within ten minutes before an import of
    /// the same version (and episode) is the file that import replaced.
    static func build(_ entries: [HistoryEntry], detail: ItemDetail) -> [V2HistoryItem] {
        let showsVersion = !detail.editions.isEmpty
        var out: [V2HistoryItem] = []
        for entry in entries {
            let date = DetailText.instant(entry.createdAt)
            if entry.eventType == "DELETED", let date,
               let i = out.lastIndex(where: { replaces($0, deleted: entry, at: date) }) {
                out[i].replaced = replacedText(entry)
                continue
            }
            let edition = showsVersion ? detail.editions.first(where: { $0.id == entry.editionId }) : nil
            out.append(V2HistoryItem(entry: entry, edition: edition, date: date))
        }
        return out
    }

    private static func replaces(_ item: V2HistoryItem, deleted: HistoryEntry, at date: Date) -> Bool {
        guard item.entry.eventType == "IMPORTED", item.replaced == nil,
              item.entry.editionId == deleted.editionId, item.entry.episodeId == deleted.episodeId,
              let imported = item.date else { return false }
        let gap = imported.timeIntervalSince(date)
        return gap >= 0 && gap <= 600
    }

    private static func replacedText(_ entry: HistoryEntry) -> String {
        var parts: [String] = []
        if let quality = entry.quality { parts.append(DetailText.quality(quality)) }
        if let score = entry.cfScore { parts.append(V2HistoryEvent.score(score)) }
        if parts.isEmpty, let title = entry.sourceTitle { parts.append(title) }
        return parts.isEmpty ? "the previous file" : parts.joined(separator: " · ")
    }

    /// The rows under their day headers, in order.
    static func days(_ items: [V2HistoryItem]) -> [(day: String, items: [V2HistoryItem])] {
        var out: [(day: String, items: [V2HistoryItem])] = []
        for item in items {
            let key = item.date.map { V2HistoryEvent.day($0) } ?? "Earlier"
            if out.last?.day == key { out[out.count - 1].items.append(item) } else { out.append((key, [item])) }
        }
        return out
    }
}
