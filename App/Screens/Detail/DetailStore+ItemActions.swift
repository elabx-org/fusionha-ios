import Foundation
import FusionhaKit

/// What the rename sheet previews and applies (RenamePanel's `versionId` / `season`).
struct RenameScope: Identifiable {
    let id = UUID()
    var versionId: Int?
    var season: Int?
}

// The item actions rail's entry points (ItemDetail.tsx's rail handlers).
extension DetailStore {
    /// "Preview rename": scoped to the page's version, like the web's `openRename(scopedVersionId())`.
    func openRename() {
        renameScope = RenameScope(versionId: scopeEditionId, season: nil)
    }

    /// `checkOrOpenNumbering`: a flagged series opens the review sheet straight
    /// away; otherwise preview once, then open the sheet when the diff proposes
    /// a change, or toast "no change needed".
    func checkNumbering() async {
        guard let client, let detail else { return }
        if detail.numberingMismatch == true { showingNumbering = true; return }
        checkingNumbering = true
        defer { checkingNumbering = false }
        do {
            let preview = try await client.numberingPreview(itemId: itemId)
            if NumberingCopy.hasChanges(preview.rows ?? []) {
                showingNumbering = true
            } else {
                show(NumberingCopy.matchesMessage(source: preview.source))
            }
        } catch {
            show("Couldn't check episode numbering.", variant: .error)
        }
    }

    /// Season number → episode count, for the Report an issue pickers.
    var issueSeasons: [Int: Int]? {
        guard let seasons = detail?.seasons, !seasons.isEmpty else { return nil }
        return Dictionary(seasons.map { ($0.seasonNumber, $0.episodes.count) }, uniquingKeysWith: { a, _ in a })
    }
}
