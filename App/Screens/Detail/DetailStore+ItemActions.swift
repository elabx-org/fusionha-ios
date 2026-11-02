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
    /// One item action, from the rail or the bar's More menu (folded Duo / phone).
    func perform(_ action: ItemAction) {
        switch action {
        case .refresh: Task { await refresh(metadataOnly: true) }
        case .previewRename: openRename()
        case .manageFiles, .manageEpisodes: manageFiles = ManageFilesTarget(versionIds: detail?.scopeEditionIds(scope))
        case .reportIssue: showingIssue = true
        case .checkNumbering: Task { await checkNumbering() }
        case .editionAliases: showingAliases = true
        case .edit: showingEdit = true
        case .delete: showingDelete = true
        }
    }

    /// "Preview rename": scoped to the page's version, like the web's `openRename(scopedVersionId())`.
    func openRename() {
        renameScope = RenameScope(versionId: scopeEditionId, season: nil)
    }

    /// Interactive search over the page's versions (every version, or the opened one).
    func openInteractiveSearch() {
        let ids = scopedEditions.map(\.id)
        guard !ids.isEmpty else { return }
        interactive = InteractiveTarget(editionIds: ids, subtitle: actsOnLabel)
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
