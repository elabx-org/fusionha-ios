import SwiftUI
import FusionhaKit

/// The footer's commit and primary (Force import N, Finish, Done) and the
/// closing toast's words.
extension ManualImportSession {
    struct CommitSummary { let ok: Int; let failed: Int; let warned: Int }

    /// Commits only ticked rows the server would accept; each download whose
    /// last open row this decides finishes with its picked disposition.
    @discardableResult
    func commitSelected() async -> CommitSummary? {
        guard let client, let scanId = scan?.scanId else { return nil }
        let ids = rows.filter { selected.contains($0.rowId) && ManualImportRules.isImportable($0) }.map(\.rowId)
        guard !ids.isEmpty else { return nil }
        working = true
        defer { working = false }
        do {
            let mode = importMode
            let finish = finishDispositions(for: ids)
            let result = try await serially { try await client.manualImportCommit(scanId: scanId, rowIds: ids, mode: mode, finish: finish) }
            var ok = 0, warned = 0
            for r in result.results {
                if let error = r.error { rowErrors[r.rowId] = error; continue }
                ok += 1
                rowErrors[r.rowId] = nil
                if let row = rows.first(where: { $0.rowId == r.rowId }) { receipts[r.rowId] = ManualImportDecide.importedReceipt(row, r) }
                if let warning = r.warning { rowWarnings[r.rowId] = warning; warned += 1 } else { rowWarnings[r.rowId] = nil }
            }
            importedCount += ok
            applyFinishes(result)
            let summary = CommitSummary(ok: ok, failed: result.results.count - ok, warned: warned)
            await reload()
            if summary.failed > 0 || summary.warned > 0 {
                notice = (ManualImportCopy.commitNotice(ok: ok, warned: warned, failed: summary.failed), summary.failed > 0)
            }
            return summary
        } catch {
            _ = askReplace(error)  // refused over a copy that is not worse: those rows ask
            notice = (ManualImportCopy.commitError(error), true)
            return CommitSummary(ok: 0, failed: ids.count, warned: 0)
        }
    }

    /// The footer's primary, as the plan names it.
    func runPrimary() async {
        let plan = plan
        guard !working, !plan.disabled else { return }
        switch plan.kind {
        case .need: return
        case .done: closing = (closingText, false)
        case .keep: await finishReady()
        case .importing where plan.folder:
            await commitSelected()
        case .importing:
            // Finish only after a clean commit: a failed or still-being-placed row keeps its download held.
            guard let s = await commitSelected(), s.failed == 0, s.warned == 0 else { return }
            await finishReady()
        }
    }

    /// "Imported 2 · 3 downloads finished" for the closing toast.
    var closingText: String {
        var parts: [String] = []
        if importedCount > 0 { parts.append("Imported \(importedCount)") }
        if finishedCount > 0 { parts.append(finishedCount == 1 ? "1 download finished" : "\(finishedCount) downloads finished") }
        return parts.isEmpty ? "Nothing changed" : parts.joined(separator: " · ")
    }
}
