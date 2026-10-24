import Foundation

// The bulk decide's sentences (fusionha 0.4.225, the web's `bulk-summary.ts`),
// kept apart from the summary's arithmetic. Same words as the web; the folder
// scan's lines ("has no library match", "nothing imported, your library file
// stays") come from the owner-approved "bar in every scenario" mock.

enum ManualImportBulkCopy {

    static let removeLinked = "Clears it from the queue only; nothing is deleted."
    static let removePlain = "Deletes the downloaded files; checked again just before. The release can be grabbed again later."

    static func verb(_ v: FinishDisposition) -> String {
        switch v {
        case .leave: return "left in the client"
        case .removeBlocklist: return "removed and blocklisted"
        case .remove: return "removed"
        }
    }

    static func reasons(open: [ManualImportRow], skip: [ManualImportRow], cap: (ManualImportRow) -> ManualImportBulk.Caps,
                        codes: ([ManualImportRow]) -> String) -> ManualImportBulkSummary.Reasons {
        let shared = open.filter { cap($0).kind == .shared && !cap($0).imp }
        let better = open.filter { cap($0).imp && !cap($0).bulkImp }
        let unmatched = open.filter { $0.match.itemId == nil }
        let imp = [
            shared.isEmpty ? nil : "\(codes(shared)) \(shared.count == 1 ? "shares" : "share") one file in your library; importing one alone would leave the other without a file.",
            better.isEmpty ? nil : "\(codes(better)) would replace \(better.count == 1 ? "a better copy" : "better copies"): import \(better.count == 1 ? "it" : "them") from the row.",
            unmatched.isEmpty ? nil : "\(codes(unmatched)) \(unmatched.count == 1 ? "has" : "have") no library match: match \(unmatched.count == 1 ? "it" : "them") from the row.",
        ].compactMap { $0 }.joined(separator: " ")
        let nocopy = open.filter { $0.existingFile == nil }
        let withCopy = open.filter { $0.existingFile != nil }
        var skipReason: String?
        if !withCopy.isEmpty, skip.count < open.count {
            let one = withCopy.count == 1
            skipReason = skip.isEmpty
                ? "Only for files with no copy in your library. \(one ? "This one has one" : "These \(withCopy.count) have one"): use Keep current."
                : "\(codes(withCopy)) \(one ? "has" : "have") a copy in your library: use Keep current for \(one ? "it" : "them")."
        }
        return .init(imp: imp.isEmpty ? nil : imp,
                     keep: nocopy.isEmpty ? nil : "\(codes(nocopy)) \(nocopy.count == 1 ? "has" : "have") no copy in your library to keep: use Skip.",
                     skip: skipReason, leave: nil)
    }

    struct Leave { let download: Int; let code: String }

    /// The keep downloads whose leave stands: chosen on a row outside the
    /// selection, or on one already decided.
    static func standingLeaves(_ downloads: [Int], _ ctx: ManualImportBulk.Context,
                               code: (ManualImportRow) -> String) -> [Leave] {
        downloads.compactMap { id in
            guard let lid = ctx.tallies[id]?.leaveRowId else { return nil }
            let row = ctx.rows.first { $0.rowId == lid }
            let stands = !ctx.selected.contains(lid) || row.map { ManualImportBulk.isDecided($0, ctx) } == true
            guard stands else { return nil }
            return Leave(download: id, code: row.map(code) ?? "row \(lid)")
        }
    }

    static func dispositions(linked: Bool, guarded: Bool, canRemove: Bool, proof: String?, preferred: FinishDisposition,
                             leaveRowCode: String?) -> [ManualImportBulkSummary.Disposition] {
        let off = leaveRowCode.map { "\($0) chose leave for this download. Change it on \($0)." }
        var out: [(FinishDisposition, String, String)] = []
        if canRemove {
            out.append((.remove, "Remove the download", linked ? removeLinked : removePlain))
            if !guarded {
                out.append((.removeBlocklist, "Remove and blocklist",
                            proof ?? "Removes the download and blocklists the release so it is not grabbed again."))
            }
        }
        out.append((.leave, "Leave the download", "Only clears the hold. The files and the queue entry are untouched."))
        return out.map { v, label, detail in
            .init(value: v, label: label, detail: detail,
                  recommended: v == preferred && preferred != .remove && (canRemove || leaveRowCode != nil),
                  off: v == .leave ? nil : off)
        }
    }

    /// What Keep current does to the downloads: now, or once their rows are decided.
    static func keepTail(keep: [ManualImportRow], downloads dls: [Int], ctx: ManualImportBulk.Context,
                         leaveRowCode: String?) -> @Sendable (FinishDisposition) -> String? {
        let ids = Set(keep.map(\.rowId))
        let dl = { (r: ManualImportRow) in ManualImportDecide.downloadId(r, ctx.scan) }
        let ready = dls.filter { id in
            ctx.rows.filter { dl($0) == id }.allSatisfy { ManualImportBulk.isDecided($0, ctx) || ids.contains($0.rowId) }
        }
        let still = ctx.rows.filter {
            !ManualImportBulk.isDecided($0, ctx) && !ids.contains($0.rowId) && dl($0).map(dls.contains) == true
        }.count
        let why = leaveRowCode.map { ", as \($0) chose," } ?? ""
        return { v in
            let vb = verb(v)
            if dls.count == 1, ready.count == 1 {
                return "the download is \(vb)\(why.hasSuffix(",") ? String(why.dropLast()) : why) now: nothing else in it to decide"
            }
            if dls.count == 1 { return "the download is \(vb)\(why) once every row is decided · \(still) still to decide" }
            if ready.count == dls.count { return "\(dls.count) downloads are \(vb) now: nothing else in them to decide" }
            return "each download is \(vb) once its own rows are decided"
        }
    }

    /// The breakdown's line: "import · keep current (not an upgrade)".
    static func lineText(_ r: ManualImportRow, _ c: ManualImportBulk.Caps, _ ctx: ManualImportBulk.Context) -> String {
        if c.decided { return "already decided" }
        let can = [c.bulkImp ? "import" : nil, c.keep ? "keep current" : nil, c.skip ? "skip" : nil]
            .compactMap { $0 }.joined(separator: " · ")
        let res = (r.held?.detail ?? ctx.scan?.heldDetail)?.probedResolution
        let note: String
        if r.match.itemId == nil { note = " (no library match)" }
        else if c.kind == .shared { note = " (shared file)" }
        else if ManualImportBatch.confirmEligible(r), r.match.confidence == "medium" { note = " (medium match)" }
        else if c.kind == .new { note = r.target.isSeries ? " (new episode)" : " (new)" }
        else if c.proof, let res, res.w > 0, res.h > 0 { note = " (measures \(res.w)×\(res.h))" }
        else if c.kind == .down { note = " (not an upgrade)" }
        else { note = "" }
        return can + note
    }
}

extension ManualImportBulk {
    /// A row of a joint span: "Shared file with E05" (they import together).
    public static func jointNote(_ r: ManualImportRow, _ ctx: Context) -> String? {
        guard let span = r.jointRows, !span.isEmpty, !r.committed else { return nil }
        let rows = span.compactMap { id in ctx.rows.first { $0.rowId == id } }
        guard !rows.isEmpty else { return nil }
        return "Shared file with \(codes(rows, ctx)) · imports together"
    }
}

extension ManualImportBulkSummary {
    /// Why the rows wait while a decide runs (the web's `APPLYING_TAIL`).
    public static let applyingTail = "Rows lock while this runs; nothing is removed until every row of a download is decided."

    /// The outcome plus the tail, as the bar shows it while the call runs
    /// (a folder scan removes nothing, so it has no tail).
    public static func applyingLine(_ outcome: String?, held: Bool) -> String {
        [outcome, held ? applyingTail : nil].compactMap { $0 }.joined(separator: ". ")
    }
}
