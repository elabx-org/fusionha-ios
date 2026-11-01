import Foundation

// The held-download rescue's copy: notices, refusals and receipts. Ported from
// the web's `routes/manual-import/{finish-receipt,commit-notices}.ts`; the reason
// strip is `ManualImportHeldStrip.swift`.

public enum ManualImportCopy {
    /// A leave chosen on another file of the download stands (409 `leave_stands`).
    public static let leaveStands = "A leave was chosen for this download on another file; change it there."
    /// A remove without `system.admin` (403 `forbidden`).
    public static let removeForbidden = "Removing a download needs the system.admin permission; pick leave."

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
            case (403?, _): return removeForbidden
            case (409?, "leave_stands"): return api.leaveStands?.detail ?? leaveStands
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
            case (409?, "leave_stands"): return api.leaveStands?.detail ?? leaveStands
            case (403?, _): return removeForbidden
            case (409?, _): return "This download isn't waiting on you any more. Refresh the queue."
            case (503?, _): return "The database is busy. Try again in a moment."
            case (404?, _): return "That download is gone. Refresh the queue."
            default: break
            }
        }
        return "Couldn't finish the download. Try again."
    }

    /// A refused bulk decide (nothing was applied), in plain words.
    public static func decideError(_ error: Error) -> String {
        if let api = error as? APIError {
            if let first = api.invalidRowReasons.first { return first }
            switch (api.status, api.code) {
            case (404?, _): return "This scan is gone. Close Manual import and open it again."
            case (403?, _): return removeForbidden
            case (409?, "leave_stands"): return api.leaveStands?.detail ?? leaveStands
            case (409?, "finish_in_progress"): return "A held download is being finished. Try again in a moment."
            case (422?, "unknown_download"), (422?, "disposition_needs_keep"):
                return "That choice no longer fits these files. Review the rows and try again."
            case (503?, _): return "The database is busy. Try again in a moment."
            default: break
            }
        }
        return "Couldn't apply that. Try again."
    }

    /// A refused row override's coded answer in plain words; nil keeps the server's message.
    public static func overrideError(_ error: Error) -> String? {
        guard let api = error as? APIError else { return nil }
        switch (api.status, api.code) {
        case (403?, _): return removeForbidden
        case (409?, "leave_stands"): return api.leaveStands?.detail ?? leaveStands
        case (409?, "finish_in_progress"): return "This download is being finished. Try again in a moment."
        case (422?, "disposition_not_held"): return "This file isn't part of a held download, so there is no download to finish."
        case (422?, "disposition_needs_keep"): return "Pick Keep current for this file first."
        case (422?, "keep_current_empty_slot"):
            return "There is no current file to keep here. Re-match the episode or dismiss the check."
        default: return nil
        }
    }

    /// The receipt, worded from the server's answer (removed vs finished).
    public static func finishReceipt(mode: String, imported: Int, kept: Int, group: String?, count: Int) -> String {
        let tail = "\(count > 1 ? "downloads" : "download") \(mode)"
        if imported > 0 { return "Imported \(imported)\(kept > 0 ? " · kept \(kept)" : "") · \(tail)" }
        return "\(group.map { "Kept your \($0) copy" } ?? "Kept your current copy") · \(tail)"
    }
}
