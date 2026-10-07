import Foundation

/// One button of the detail page's item actions rail (HeroActionRail.tsx).
/// The web's "Park page" (the desktop/mobile-web Park & Resume dock) has no
/// iOS counterpart and is left out.
public enum ItemAction: String, CaseIterable, Sendable {
    case refresh, previewRename, manageEpisodes, manageFiles, reportIssue
    case checkNumbering, editionAliases, edit, delete

    /// The rail's actions in the web's order. `canEdit == false` is the web's
    /// `readOnly`: every write action hides; Report an issue and the numbering
    /// check (a read-only preview) stay.
    public static func rail(isSeries: Bool, canEdit: Bool, hasNonStandardEdition: Bool) -> [ItemAction] {
        var out: [ItemAction] = []
        if canEdit { out += [.refresh, .previewRename, isSeries ? .manageEpisodes : .manageFiles] }
        out.append(.reportIssue)
        if isSeries { out.append(.checkNumbering) }
        if canEdit, hasNonStandardEdition { out.append(.editionAliases) }
        if canEdit { out += [.edit, .delete] }
        return out
    }

    /// The button's tooltip / accessibility label, as on the web.
    public func label(isSeries: Bool, numberingFlagged: Bool = false) -> String {
        switch self {
        case .refresh: return "Refresh metadata"
        case .previewRename: return "Preview rename"
        case .manageEpisodes: return "Manage episodes"
        case .manageFiles: return "Manage files"
        case .reportIssue: return "Report an issue"
        case .checkNumbering: return numberingFlagged ? "Review episode numbering" : "Check episode numbering"
        case .editionAliases: return "Edition aliases"
        case .edit: return "Edit & monitoring"
        case .delete: return isSeries ? "Delete series" : "Delete movie"
        }
    }
}

// MARK: Rename (RenamePanel.tsx)

public enum RenameCopy {
    /// `splitRenamePreview`: a blocked row never counts toward the apply button.
    public static func split(_ rows: [RenamePreviewRow]) -> (movable: [RenamePreviewRow], blocked: [RenamePreviewRow]) {
        (rows.filter { !$0.isBlocked }, rows.filter(\.isBlocked))
    }

    /// What the preview/apply covers, named so the scope is never ambiguous.
    public static func scopeText(versionId: Int?, season: Int?) -> String {
        if let season { return "Season \(season)" }
        return versionId != nil ? "this version" : "the whole title"
    }

    public static func applyLabel(count: Int) -> String {
        count == 0 ? "Rename" : "Rename \(count) \(count == 1 ? "file" : "files")"
    }

    public static func blockedHeading(_ count: Int) -> String {
        count == 1 ? "1 file can't be renamed" : "\(count) files can't be renamed"
    }

    /// `renameBlockCopy`: each refusal reason has its own remedy.
    public static func blockReason(_ row: RenamePreviewRow) -> String {
        switch row.reason {
        case "duplicate_name":
            if let path = row.blockedByPath {
                return "Another file on this title wants the same name (\(path)). Delete or repoint the duplicate."
            }
            return "Another file on this title wants the same name."
        case "destination_held":
            if let path = row.blockedByPath {
                return "That name is currently used by \(path), which can't move out of the way in this scope."
            }
            return "That name is currently used by another file that can't move out of the way."
        case "source_missing":
            return "The file is missing from disk — rescan or replace it first."
        case "destination_exists":
            return "A file fusionha doesn't track is already at that name. Clear it, then rename again."
        default:
            return "fusionha refused this move so it could not overwrite another file."
        }
    }

    /// The apply toast: `n files renamed`, plus the first refusal when any were skipped.
    public static func appliedToast(_ result: RenameApplyResult) -> (message: String, isWarning: Bool) {
        let n = result.applied
        let moved = "\(n) \(n == 1 ? "file" : "files") renamed"
        guard let first = result.skipped?.first, let count = result.skipped?.count else { return (moved, false) }
        return ("\(moved) · \(count) skipped (\(blockReason(first)))", true)
    }
}

// MARK: Episode numbering (NumberingFixDialog.tsx, numbering-summary.ts)

/// One season's notable numbering rows.
public struct NumberingSeasonGroup: Sendable, Hashable, Identifiable {
    public let season: Int
    public let rows: [NumberingDiffRow]
    public var id: Int { season }
}

public enum NumberingCopy {
    /// `NOTABLE_NUMBERING_KINDS`: the rows that propose an actual change.
    public static let notableKinds: Set<String> = ["renumbered", "added", "removed"]

    /// `numberingPreviewHasChanges`.
    public static func hasChanges(_ rows: [NumberingDiffRow]) -> Bool {
        rows.contains { notableKinds.contains($0.kind) }
    }

    /// The notable rows grouped by season, seasons ascending.
    public static func notableBySeason(_ rows: [NumberingDiffRow]) -> [NumberingSeasonGroup] {
        let notable = rows.filter { notableKinds.contains($0.kind) }
        let grouped = Dictionary(grouping: notable, by: { $0.season })
        return grouped.keys.sorted().map { NumberingSeasonGroup(season: $0, rows: grouped[$0] ?? []) }
    }

    public static func kindLabel(_ kind: String) -> String {
        switch kind {
        case "unchanged": return "Unchanged"
        case "renumbered": return "Renumbered"
        case "retitled": return "Retitled"
        case "added": return "New"
        case "removed": return "Removed"
        default: return kind
        }
    }

    /// The compare source's display name (`SOURCE_LABEL`, raw value otherwise).
    public static func sourceLabel(_ source: String) -> String {
        switch source {
        case "tvdb": return "TVDB"
        case "tvmaze": return "TVmaze"
        default: return source
        }
    }

    /// `sourceForProvider`: the label placeholder while the preview loads.
    public static func sourceGuess(provider: String?) -> String {
        provider == "tvdb" || provider == "hybrid" ? "tvdb" : "tvmaze"
    }

    /// The check's "no change needed" toast names TVDB or TVmaze only.
    public static func matchesMessage(source: String?) -> String {
        "Numbering matches \(source == "tvdb" ? "TVDB" : "TVmaze") — no change needed"
    }

    public enum Tone: Sendable { case success, info, warning }

    /// `numberingSummaryToast`.
    public static func summary(_ result: NumberingApplyResult?, itemTitle: String) -> (title: String, message: String, tone: Tone) {
        let title = "Episode numbering fixed — \(itemTitle)"
        guard let result else { return (title, "Numbering pinned to TVmaze.", .success) }
        func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
        var clauses: [String] = []
        let renumbered = result.renumbered?.count ?? 0
        let added = result.added?.count ?? 0
        let relinked = result.relinked?.count ?? 0
        let phantoms = result.removedPhantoms?.count ?? 0
        let unparseable = result.unparseable?.count ?? 0
        if renumbered > 0 { clauses.append(plural(renumbered, "episode", "episodes") + " renumbered") }
        if added > 0 { clauses.append("\(added) new \(added == 1 ? "episode" : "episodes") added") }
        if relinked > 0 { clauses.append(plural(relinked, "file", "files") + " re-linked") }
        if phantoms > 0 { clauses.append("\(phantoms) phantom \(phantoms == 1 ? "episode" : "episodes") removed") }
        var tone = Tone.success
        if unparseable > 0 {
            clauses.append("\(unparseable) \(unparseable == 1 ? "file needs" : "files need") manual assignment")
            tone = .warning
        }
        if clauses.isEmpty { return (title, "No changes.", .info) }
        return (title, clauses.joined(separator: " · ") + ".", tone)
    }
}
