import Foundation

// The toast when Manual Import closes itself: it was opened for one held
// download and that download just finished (owner-approved item 5). It names
// the title and what happened, e.g. "Interstellar · kept your FraMeSToR copy ·
// download removed" or "The Office S06 · imported 2 · kept 3".

extension ManualImportDecide {
    /// "Interstellar", "The Office S06", or "The Office" when the rows span seasons.
    public static func downloadName(_ rows: [ManualImportRow]) -> String? {
        guard let first = rows.first, let title = first.match.title ?? first.parsed.title else { return nil }
        guard first.target.isSeries else { return title }
        let seasons = Set(rows.compactMap { $0.target.season ?? $0.parsed.season })
        guard seasons.count == 1, let season = seasons.first else { return title }
        return "\(title) S\(String(format: "%02d", season))"
    }

    /// One finished download's closing line. One file reads as its receipt
    /// ("kept your FraMeSToR copy · download removed"); a pack as counts
    /// ("imported 2 · kept 3 · skipped 1"). `currentGroup` is the held
    /// detail's group, for a kept row whose copy names none.
    public static func closingLine(_ rows: [ManualImportRow], finish: FinishRescueResult?,
                                   currentGroup: String? = nil) -> String {
        var parts: [String] = []
        if let name = downloadName(rows) { parts.append(name) }
        if rows.count == 1, let row = rows.first {
            parts.append(lowerFirst(singleOutcome(row, currentGroup: currentGroup)))
            if let finish { parts.append(finishDetail(finish)) }
        } else {
            let imported = rows.filter(\.committed).count
            let skipped = rows.filter { !$0.committed && $0.existingFile == nil }.count
            let kept = rows.count - imported - skipped
            if imported > 0 { parts.append("imported \(imported)") }
            if kept > 0 { parts.append("kept \(kept)") }
            if skipped > 0 { parts.append("skipped \(skipped)") }
            if imported + kept + skipped == 0, let finish { parts.append(finishDetail(finish)) }
        }
        return parts.isEmpty ? "Download finished" : parts.joined(separator: " · ")
    }

    private static func singleOutcome(_ row: ManualImportRow, currentGroup: String?) -> String {
        if row.committed { return row.target.kind == "movie" ? "imported" : importedReceipt(row).title }
        if row.existingFile == nil { return "Skipped this file" }
        return (row.existingFile?.releaseGroup ?? currentGroup).map { "Kept your \($0) copy" } ?? "Kept your copy"
    }

    private static func lowerFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.lowercased() + s.dropFirst()
    }
}
