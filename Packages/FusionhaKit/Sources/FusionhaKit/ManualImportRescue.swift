import Foundation

// The held-download rescue: what the footer's primary does, the reason strip
// above the rows, and the receipts. Ported from the web's
// `routes/manual-import/{finish-plan,held-strip,held-banner,finish-receipt,commit-notices}.ts`.

/// What the rescue's primary button does (`finishPlan`).
public struct ManualImportFinishPlan: Equatable, Sendable {
    public enum Kind: Sendable { case keep, mixed, need, importOnly }
    public let kind: Kind
    /// Rows the commit will import.
    public let imports: Int
    /// Rows set to Current (they stay as they are).
    public let kept: Int
    /// Rows still waiting for a decision.
    public let need: Int
    /// Rows an earlier commit already imported.
    public let done: Int
    public let label: String
    public let disabled: Bool

    /// Whether running it ends the held download(s).
    public var finishes: Bool { kind == .keep || kind == .mixed }

    public init(rows: [ManualImportRow], selected: Set<Int>) {
        let open = rows.filter { !$0.committed }
        let keptRows = open.filter { $0.replaceChoice == "keep_current" }
        let rest = open.filter { $0.replaceChoice != "keep_current" }
        let ready = { (r: ManualImportRow) in selected.contains(r.rowId) && ManualImportRules.isImportable(r) }
        imports = rest.filter(ready).count
        need = rest.filter { !ready($0) }.count
        kept = keptRows.count
        done = rows.count - open.count
        let plan: (Kind, String, Bool)
        if need > 0 && imports > 0 {
            plan = (.importOnly, "Force import \(imports)", false)
        } else if need > 0 {
            plan = (.need, need == 1 ? "1 file needs a decision" : "\(need) files need a decision", true)
        } else if imports == 0 && kept > 0 && done == 0 {
            plan = (.keep, "Keep current · remove download", false)
        } else if kept > 0 || (done > 0 && imports == 0) {
            plan = (.mixed, imports > 0 ? "Import \(imports) · finish download" : "Finish download", false)
        } else {
            plan = (.importOnly, "Force import \(imports)", imports == 0)
        }
        kind = plan.0
        label = plan.1
        disabled = plan.2
    }

    /// The line under the button.
    public var hint: String? {
        switch kind {
        case .need: return "Pick Current or This file on each held row to continue."
        case .keep: return "Nothing is imported. Ends the held download."
        case .mixed where kept > 0: return "\(kept) kept \(kept == 1 ? "file stays" : "files stay") as they are."
        default: return nil
        }
    }
}

/// The reason strip above a rescue's rows.
public struct ManualImportHeldStrip: Equatable, Sendable {
    public let line1: [String]
    public let line2: String?
    /// Held downgrades Keep all current / Import all would answer.
    public let bulkEligible: Int

    /// `decide` is the footer's `need`, so "to decide" and the button always agree (fusionha 0.4.199).
    public init?(scan: ManualImportScan, decide: Int? = nil) {
        guard scan.isRescue || scan.heldReason != nil else { return nil }
        let held = scan.rows.filter { $0.held != nil }
        let single = held.count == 1 ? held.first : (held.isEmpty && scan.rows.count == 1 ? scan.rows.first : nil)
        if let row = single {
            let reason = Self.reasonShort(scan, row)
            let detail = Self.bannerText(scan, row)
            let guardLine = Self.guardLine(scan.heldDetail?.currentGroup ?? row.existingFile?.releaseGroup, tier: row.target.tier,
                                           edition: row.target.edition)
            line1 = [reason] + (guardLine.map { [$0] } ?? [])
            line2 = detail.isEmpty || detail == reason ? nil : detail
            bulkEligible = 0
            return
        }
        guard held.count >= 2 else {
            line1 = [Self.reasonShort(scan, held.first)]
            line2 = nil
            bulkEligible = 0
            return
        }
        let downs = held.filter(Self.isDowngrade)
        let kept = held.filter { $0.replaceChoice == "keep_current" }.count
        let importing = held.filter { $0.replaceChoice == "import" || ($0.replaceChoice == nil && !Self.isDowngrade($0)) }.count
        let ups = held.filter {
            $0.existingFile?.verdict?.upgrade == true && !ManualImportRules.titleBlocked($0) && $0.wouldOrphan == nil
                && ManualImportRules.isImportable($0)
        }.count
        let fresh = held.filter { $0.existingFile == nil }.count
        let open = decide ?? downs.filter { !$0.committed && $0.replaceChoice == nil }.count
        let replaces = downs.count == 1 ? "1 file would replace a better copy" : "\(downs.count) files would replace better copies"
        line1 = [replaces, ups == 1 ? "1 upgrade" : "\(ups) upgrades", "\(fresh) new"]
        if open > 0 {
            line2 = (Self.uniformReason(scan, downs).map { $0 + " " } ?? "") + "\(open) still to decide; open a row to compare."
        } else {
            line2 = "\(importing) will import, \(kept) \(kept == 1 ? "keeps" : "keep") the current file."
        }
        bulkEligible = downs.filter(Self.bulkEligible).count
    }

    /// A held row over a current file that is not an upgrade.
    static func isDowngrade(_ r: ManualImportRow) -> Bool {
        r.held != nil && r.existingFile != nil && !ManualImportRules.titleBlocked(r) && r.existingFile?.verdict?.upgrade != true
    }

    /// The rows Keep all current / Import all act on: undecided-or-not held downgrades with a known file.
    public static func bulkEligible(_ r: ManualImportRow) -> Bool {
        !r.committed && isDowngrade(r) && r.existingFile?.mediaFileId != nil
    }

    static func claimedNumber(_ d: HeldDetail) -> Int? {
        if let c = d.claimedResolution { return c }
        guard let q = d.claimedQuality, let r = q.range(of: #"(\d{3,4})p"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return Int(q[r].dropLast())
    }

    static func reasonShort(_ scan: ManualImportScan, _ row: ManualImportRow?) -> String {
        let d = scan.heldDetail
        if d?.kind == "mislabeled_hdr" { return "not an upgrade" }
        if d?.mislabeled == true { return "smaller than its name says" }
        return scan.heldReason ?? row?.held?.reason ?? "needs a manual import"
    }

    static func bannerText(_ scan: ManualImportScan, _ row: ManualImportRow) -> String {
        guard let d = scan.heldDetail else { return scan.heldReason ?? row.held?.reason ?? "" }
        if d.kind == "mislabeled_hdr" { return HeldCopy.hdrLine(d) }
        if d.mislabeled == true {
            let probed = d.probedQuality ?? "a lower quality"
            guard let claimed = claimedNumber(d) else { return "The file measures as \(probed), below what its name claims." }
            if let res = d.probedResolution, res.w > 0, res.h > 0 {
                return "Name says \(claimed)p, the file measures \(res.w)×\(res.h) (graded \(probed))."
            }
            return "Name says \(claimed)p, the file measures as \(probed)."
        }
        return scan.heldReason ?? row.held?.reason ?? ""
    }

    /// "would replace your 4K FUZEER copy"; nil with no group.
    static func guardLine(_ group: String?, tier: String?, edition: String? = nil) -> String? {
        guard let group, !group.isEmpty else { return nil }
        let short = tier.flatMap(QualityTier.init(rawValue:))?.tierShort
        let slot = short.map { "\($0) \(group)" } ?? group
        // Edition first, like the version label: "Extended · 4K FUZEER".
        return "would replace your \(edition.map { "\($0) · \(slot)" } ?? slot) copy"
    }

    static func uniformReason(_ scan: ManualImportScan, _ downs: [ManualImportRow]) -> String? {
        var keys = Set<String>()
        var line: String?
        for r in downs {
            guard let d = r.held?.detail ?? scan.heldDetail, d.mislabeled == true, let claimed = claimedNumber(d),
                  let res = d.probedResolution, res.w > 0, res.h > 0 else { return nil }
            keys.insert("\(res.w)x\(res.h)@\(claimed)")
            line = "\(res.w)×\(res.h), not the \(claimed)p their names claim."
        }
        guard keys.count == 1, let line else { return nil }
        return "\(downs.count) \(downs.count == 1 ? "file measures" : "files measure") \(line)"
    }
}

public enum ManualImportCopy {
    /// The commit notice: "Imported 3 files in place · 1 still being put in place · 1 failed".
    public static func commitNotice(ok: Int, warned: Int, failed: Int) -> String {
        let inPlace = ok - warned
        return "Imported \(inPlace) file\(inPlace == 1 ? "" : "s") in place"
            + (warned > 0 ? " · \(warned) still being put in place" : "")
            + (failed > 0 ? " · \(failed) failed" : "")
    }

    /// A commit that failed outright, in plain words (never the raw server message).
    public static func commitError(_ error: Error) -> String {
        if let api = error as? APIError {
            if let n = api.invalidRowCount { return "\(n) row\(n == 1 ? "" : "s") can't be imported. Fix or untick \(n == 1 ? "it" : "them")." }
            switch (api.status, api.code) {
            case (503?, _): return "The database is busy. Try again in a moment."
            case (409?, "finish_in_progress"): return "A held download is being finished. Try the import again in a moment."
            case (409?, _): return "These files changed since the scan. Review the rows and try again."
            default: break
            }
        }
        return "Couldn't import. Try again."
    }

    /// A finish that failed, in plain words.
    public static func finishError(_ error: Error) -> String {
        if let api = error as? APIError {
            switch (api.status, api.code) {
            case (409?, "rows_open"): return "Some files still need a choice. Pick Current or This file for each one."
            case (409?, _): return "This download isn't waiting on you any more. Refresh the queue."
            case (503?, _): return "The database is busy. Try again in a moment."
            case (404?, _): return "That download is gone. Refresh the queue."
            default: break
            }
        }
        return "Couldn't finish the download. Try again."
    }

    /// The receipt, worded from the server's answer (removed vs finished).
    public static func finishReceipt(mode: String, imported: Int, kept: Int, group: String?, count: Int) -> String {
        let tail = "\(count > 1 ? "downloads" : "download") \(mode)"
        if imported > 0 { return "Imported \(imported)\(kept > 0 ? " · kept \(kept)" : "") · \(tail)" }
        return "\(group.map { "Kept your \($0) copy" } ?? "Kept your current copy") · \(tail)"
    }
}
