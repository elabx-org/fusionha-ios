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
        default: return res.libraryLinked == true ? "download finished · nothing deleted, your library links into it" : "download finished · nothing deleted"
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
    public let disabled: Bool

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
    }

    public var hint: String? {
        switch kind {
        case .need: return "Each download finishes as soon as its own rows are decided."
        case .keep: return "Every row is decided · a download still needs its finish."
        case .done: return "Every download is finished."
        case .importing: return nil
        }
    }
}
