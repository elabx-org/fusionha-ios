import Foundation
import FusionhaKit

/// A version-strip tap: which version, and the scroll anchor of its row.
struct VersionReveal: Equatable {
    let editionId: Int
    /// `file-{id}` (its row in the Files tab) or `version-{id}` (its Versions
    /// panel row, for a series version with no files yet).
    let anchor: String
    let id = UUID()
}

extension DetailStore {
    /// The hero's version strip (D4): one chip per tracked version, HD first,
    /// Standard first, from the same numbers as the Versions panel.
    var stripChips: [VersionStripChip] {
        guard let detail else { return [] }
        return detail.versionsSorted.compactMap { edition in
            guard let summary = summary(edition) else { return nil }
            let rows = VersionStrip.liveRows(queue, itemId: itemId, editionId: edition.id)
            return VersionStripChip(editionId: edition.id, tier: edition.tier, edition: edition.versionKey,
                                    qualityCode: summary.qualityCode,
                                    status: summary.status, progress: VersionStrip.progress(rows),
                                    held: VersionStrip.isHeld(rows))
        }
    }

    /// A strip chip's tap: the Files tab (with every version in scope when
    /// this one was scoped out), then the page scrolls to its row.
    func revealVersion(_ editionId: Int) {
        guard let detail else { return }
        if !scopedEditions.contains(where: { $0.id == editionId }) { scope = .all }
        tab = .files
        let anchor = VersionStrip.hasFiles(detail, editionId: editionId) ? "file-\(editionId)" : "version-\(editionId)"
        versionReveal = VersionReveal(editionId: editionId, anchor: anchor)
    }
}
