import Foundation

// A decided row's Done receipt and the rescue footer's plan (fusionha 0.4.202,
// the web's `finish-receipt.ts` and `finishPlan`). Nothing can be undone.

extension ManualImportDecide {
    // MARK: Receipts

    public struct Receipt: Equatable, Sendable {
        /// "Kept your FUZEER copy" / "Imported as S06E06".
        public let title: String
        /// "download removed · release blocklisted" / "replaced The.Lover.mkv".
        public let detail: String?
    }

    public static func finishDetail(_ res: FinishRescueResult) -> String {
        switch res.mode {
        case "left": return "download left as it is"
        case "removed": return res.blocklisted == true ? "download removed · release blocklisted" : "download removed"
        // 0.4.233 H3: a blocklist pick still blocklists the release when the data has to stay.
        case _ where res.blocklisted == true:
            return res.libraryLinked == true ? "release blocklisted · download kept because your library still links into it"
                : "release blocklisted · download finished, nothing deleted"
        default: return res.libraryLinked == true ? "download finished · nothing deleted, your library links into it" : "download finished · nothing deleted"
        }
    }

    /// "Which file stays?"'s tail on a kept held row: what really happens to
    /// its download, worded from the effective pick (a standing leave wins).
    /// `finishesNow`: the footer's next step is the finish.
    public static func keepTail(_ pick: FinishDisposition, linked: Bool, finishesNow: Bool) -> String {
        let when = finishesNow ? "when you finish" : "when every row is decided"
        switch pick {
        case .leave: return "the download is left in the client"
        case .remove:
            return linked ? "the download is cleared from the queue \(when); nothing is deleted" : "the download is removed \(when)"
        case .removeBlocklist:
            return linked ? "the release is blocklisted \(when); the download stays while your library links into it"
                : "the download is removed and blocklisted \(when)"
        }
    }

    public static func keptReceipt(group: String?, _ res: FinishRescueResult, skipped: Bool) -> Receipt {
        Receipt(title: skipped ? "Skipped this file" : group.map { "Kept your \($0) copy" } ?? "Kept your copy",
                detail: finishDetail(res))
    }

    private static func place(_ row: ManualImportRow, _ result: ManualImportCommitRow?) -> String {
        if let code = ManualImportRules.episodeCode(row) { return code }
        if row.target.kind == "movie" { return row.match.title ?? "the movie" }
        if let n = result?.episodeIds?.count, n > 0 { return "\(n) episodes" }
        return "this episode"
    }

    public static func importedReceipt(_ row: ManualImportRow, _ result: ManualImportCommitRow? = nil) -> Receipt {
        let said = row.titleCheck?.status == "names_other" ? nil : row.titleCheck?.says
        let name = row.target.isSeries ? said.map { " \($0)" } ?? "" : ""
        return Receipt(title: "Imported as \(place(row, result))\(name)", detail: result?.replacedFile.map { "replaced \($0)" })
    }

    /// A receipt rebuilt from the scan alone (the sheet was reopened after the finish).
    public static func fallbackReceipt(_ row: ManualImportRow) -> Receipt {
        if row.committed { return importedReceipt(row) }
        let title = row.existingFile == nil ? "Skipped this file"
            : row.existingFile?.releaseGroup.map { "Kept your \($0) copy" } ?? "Kept your copy"
        return Receipt(title: title, detail: "download finished")
    }

    /// "Show S01 pack" for the pack progress line.
    public static func packName(_ rows: [ManualImportRow]) -> String {
        let r = rows.first
        let title = r?.match.title ?? r?.parsed.title ?? "Season"
        guard let season = r?.target.season ?? r?.parsed.season else { return "\(title) pack" }
        return "\(title) S\(String(format: "%02d", season)) pack"
    }
}

/// What the rescue's footer primary does (fusionha 0.4.202 `finishPlan`).
public struct ManualImportFinishPlan: Equatable, Sendable {
    /// need: a row has no decision · importing: commit the ticked rows · keep:
    /// every row is decided but a download still waits for its finish · done.
    public enum Kind: Sendable { case need, importing, keep, done }
    public let kind: Kind
    public let imports: Int
    public let kept: Int
    public let need: Int
    public let done: Int
    public let label: String
    /// The narrow wording when `label` doesn't fit beside the other controls
    /// ("3 need a decision"), the web's `shortLabel`. `label` stays the VoiceOver label.
    public let shortLabel: String?
    /// Under the primary's label: a folder scan's "2 need a decision" (the web's batch sub-line).
    public let subline: String?
    public let disabled: Bool
    /// A folder scan: the primary only imports, there is no download to finish.
    public let folder: Bool

    /// A row that still blocks its download's finish (the footer's `need` and the strip's "to decide").
    public static func needsDecision(_ r: ManualImportRow, selected: Set<Int>, finished: (ManualImportRow) -> Bool = { _ in false }) -> Bool {
        !r.committed && !finished(r) && r.replaceChoice != "keep_current"
            && !(selected.contains(r.rowId) && ManualImportRules.isImportable(r))
    }

    public init(rows: [ManualImportRow], selected: Set<Int>,
                finished: (ManualImportRow) -> Bool = { _ in false }, pending: Int = 0) {
        let open = rows.filter { !$0.committed && !finished($0) }
        let rest = open.filter { $0.replaceChoice != "keep_current" }
        imports = rest.filter { selected.contains($0.rowId) && ManualImportRules.isImportable($0) }.count
        need = rest.filter { Self.needsDecision($0, selected: selected, finished: finished) }.count
        kept = open.count - rest.count
        done = rows.filter(\.committed).count
        let plan: (Kind, String, Bool)
        if imports > 0 {
            plan = (.importing, "Force import \(imports)", false)
        } else if need > 0 {
            plan = (.need, need == 1 ? "1 file needs a decision" : "\(need) files need a decision", true)
        } else if pending > 0 {
            plan = (.keep, pending == 1 ? "Finish download" : "Finish \(pending) downloads", false)
        } else {
            plan = (.done, "Done", false)
        }
        kind = plan.0
        label = plan.1
        disabled = plan.2
        shortLabel = plan.0 == .need ? "\(need) need a decision" : nil
        subline = nil
        folder = false
    }

    /// A folder scan (the web's batch `StickyBar`): "Import N" counts the ticked
    /// rows that can import and is off until one can; ticked rows that can't yet
    /// show as "K need a decision" under it. No plan: no Finish, no Done.
    public static func folder(rows: [ManualImportRow], selected: Set<Int>) -> ManualImportFinishPlan {
        let picked = rows.filter { !$0.committed && selected.contains($0.rowId) }
        let imports = picked.filter(ManualImportRules.isImportable).count
        let need = picked.filter { !ManualImportRules.isImportable($0) && $0.replaceChoice != "keep_current" }.count
        return ManualImportFinishPlan(
            kind: .importing, imports: imports,
            kept: rows.filter { !$0.committed && $0.replaceChoice == "keep_current" }.count,
            need: need, done: rows.filter(\.committed).count,
            label: "Import \(imports)", shortLabel: nil,
            subline: need > 0 ? "\(need) need\(need == 1 ? "s" : "") a decision" : nil,
            disabled: imports == 0, folder: true)
    }

    private init(kind: Kind, imports: Int, kept: Int, need: Int, done: Int, label: String,
                 shortLabel: String?, subline: String?, disabled: Bool, folder: Bool) {
        self.kind = kind
        self.imports = imports
        self.kept = kept
        self.need = need
        self.done = done
        self.label = label
        self.shortLabel = shortLabel
        self.subline = subline
        self.disabled = disabled
        self.folder = folder
    }

    public var hint: String? {
        if folder { return nil }
        switch kind {
        // The web's `FooterActions` words.
        case .need: return "Tick files to decide them together · each download finishes once its own rows are decided"
        case .keep: return "Every row is decided · a download still needs its finish"
        case .done: return "Every download is finished"
        case .importing: return nil
        }
    }
}
