import SwiftUI
import FusionhaKit

/// Decide the ticked rows together (fusionha 0.4.225, the web's
/// `useBulkDecide`): Import N, Keep current (with the held download's
/// disposition) and Skip are each ONE atomic `POST /scan/{id}/decide`. The
/// server validates everything first and applies nothing on a refusal, then
/// finishes every download it fully decided; its answer carries the scan.
extension ManualImportSession {

    /// The bulk bar replaces the selection sheet here (held downloads, unless
    /// `ManualImportFeatures.barEverywhere`).
    var barShows: Bool { ManualImportFeatures.bulkBar(scan) }

    /// What the selection can take, and the words for it.
    var bulk: ManualImportBulkSummary {
        ManualImportBulkSummary(bulkContext, canRemove: canRemove)
    }

    var bulkContext: ManualImportBulk.Context {
        .init(rows: rows, selected: selected, scan: scan, tallies: tallies)
    }

    /// Ticked rows that are not imported (the bar shows while any are).
    var tickedCount: Int { rows.filter { !$0.committed && selected.contains($0.rowId) }.count }

    var undecidedCount: Int { ManualImportBulk.undecided(bulkContext).count }

    /// Select all undecided (⌘A): exactly the rows that still need a decision.
    func selectAllUndecided() {
        selected = Set(ManualImportBulk.undecided(bulkContext).filter { !$0.committed }.map(\.rowId))
    }

    /// One decide call for the selection; `pick` is Keep current's disposition.
    func decide(_ action: ManualImportDecideAction, pick: FinishDisposition? = nil) async {
        let summary = bulk
        guard applying == nil, !working, let client, let scanId = scan?.scanId,
              let request = summary.request(action, pick: pick ?? summary.preferred, mode: importMode) else { return }
        let ids = request.rows.map(\.rowId)
        guard ids.allSatisfy({ !busyRows.contains($0) }) else { return }
        applying = Applying(action: action, count: ids.count, outcome: outcome(action, summary, pick))
        busyRows.formUnion(ids)
        defer {
            busyRows.subtract(ids)
            applying = nil
        }
        notice = nil
        do {
            let res = try await serially { try await client.manualImportDecide(scanId: scanId, request) }
            adopt(res.scan)
            applyFinishes(res.asCommit)
            markFinished((res.downloads ?? []).filter { $0.finished == true }.map(\.id))
            settle(res, ids: ids, action: action)
        } catch {
            notice = (ManualImportCopy.decideError(error), true)
        }
    }

    private func outcome(_ action: ManualImportDecideAction, _ s: ManualImportBulkSummary, _ pick: FinishDisposition?) -> String? {
        switch action {
        case .importFile: return s.impOutcome
        case .keepCurrent: return s.keepOutcome(pick ?? s.preferred)
        case .skip: return s.skipOutcome
        }
    }

    /// Receipts and row errors from the answer; decided rows leave the selection.
    private func settle(_ res: ManualImportDecideResult, ids: [Int], action: ManualImportDecideAction) {
        let results = res.results ?? []
        let failed = Dictionary(results.compactMap { r in
            r.error.flatMap { $0 == "already committed" ? nil : (r.rowId, $0) }
        }, uniquingKeysWith: { a, _ in a })
        var ok = 0, warned = 0
        for r in results where failed[r.rowId] == nil {
            ok += 1
            if let row = rows.first(where: { $0.rowId == r.rowId }) { receipts[r.rowId] = ManualImportDecide.importedReceipt(row, r) }
            rowWarnings[r.rowId] = r.warning
            if r.warning != nil { warned += 1 }
        }
        for id in ids { rowErrors[id] = failed[id] }
        selected.subtract(ids.filter { failed[$0] == nil })
        guard action == .importFile else { return }
        importedCount += ok
        if !failed.isEmpty || warned > 0 {
            notice = (ManualImportCopy.commitNotice(ok: ok, warned: warned, failed: failed.count), !failed.isEmpty)
        }
    }

    /// Medium matches among the ticked rows (Confirm N medium matches).
    var tickedToConfirm: [ManualImportRow] {
        rows.filter { selected.contains($0.rowId) && ManualImportBatch.confirmEligible($0) }
    }
}

extension ManualImportSession {
    /// A decide call in flight: the bar's indeterminate state.
    struct Applying: Equatable {
        let action: ManualImportDecideAction
        let count: Int
        /// What the call does, worded as the outcome line.
        let outcome: String?

        var label: String {
            switch action {
            case .importFile: return "Importing \(count)…"
            case .keepCurrent: return "Keeping current for \(count)…"
            case .skip: return "Skipping \(count)…"
            }
        }
    }
}
