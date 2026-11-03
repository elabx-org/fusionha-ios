import SwiftUI
import FusionhaKit

/// Decide one file at a time (fusionha 0.4.202, the web's `useRescueDecide`):
/// Import this file / Assign / Re-match commit just that row; Keep current
/// records the choice and, once every row of that download is decided,
/// finishes THAT download with the picked disposition. Each decided row then
/// reads as a Done receipt worded from the server's answer. No Undo.
extension ManualImportSession {

    /// The decide state of one held row, or nil outside a rescue.
    func tally(for row: ManualImportRow) -> ManualImportDecide.Tally? {
        ManualImportDecide.downloadId(row, scan).flatMap { tallies[$0] }
    }

    func isFinished(_ row: ManualImportRow) -> Bool { tally(for: row)?.finished == true }

    /// Decided, or its download is finished, so the verdict counts agree with the held strip.
    func isDone(_ row: ManualImportRow) -> Bool { ManualImportDecide.isDecided(row) || isFinished(row) }

    /// The verdict strip's filter shows this row.
    func shows(_ row: ManualImportRow) -> Bool { filter.matches(row, isDone: isDone) }

    /// The row's receipt: exact from the server's answer, else rebuilt once its download finished.
    func receipt(for row: ManualImportRow) -> ManualImportDecide.Receipt? {
        if let stored = receipts[row.rowId] { return stored }
        return isFinished(row) && ManualImportDecide.isDecided(row) ? ManualImportDecide.fallbackReceipt(row) : nil
    }

    func keepChoice(for row: ManualImportRow) -> ManualImportDecide.KeepChoice {
        let saved = ManualImportDecide.downloadId(row, scan).flatMap(savedDisposition)
        return ManualImportDecide.keepChoice(row, scan, linked: tally(for: row)?.linked == true, saved: saved)
    }

    /// This sheet's pick for the download, else the one saved on the server
    /// (0.4.225). The finish still sends it explicitly.
    func savedDisposition(_ downloadId: Int) -> FinishDisposition? {
        dispositions[downloadId] ?? tallies[downloadId]?.disposition
    }

    /// What really happens to a held row's download when it is kept: a leave
    /// that stands wins, else the pick, else the default (never "removed" by guess).
    func keepTail(for row: ManualImportRow) -> String? {
        guard let id = ManualImportDecide.downloadId(row, scan), let t = tallies[id], !t.finished else { return nil }
        let mine = rows.filter { ManualImportDecide.downloadId($0, scan) == id }
        let pick: FinishDisposition = t.leaveRowId != nil ? .leave
            : savedDisposition(id) ?? ManualImportDecide.defaultDisposition(mine, scan)
        return ManualImportDecide.keepTail(pick, linked: t.linked, finishesNow: plan.kind == .keep)
    }

    // MARK: Row actions

    /// Keep current (or Skip this file) with a disposition; finishes the download once all its rows are decided.
    func keepRow(_ row: ManualImportRow, _ disposition: FinishDisposition) async {
        guard !busyRows.contains(row.rowId) else { return }
        confirming[row.rowId] = nil
        busyRows.insert(row.rowId)
        defer { busyRows.remove(row.rowId) }
        if let id = ManualImportDecide.downloadId(row, scan) { dispositions[id] = disposition }
        if row.replaceChoice != "keep_current" {
            await patch(row, ["replace_choice": .string("keep_current")])
            guard rowErrors[row.rowId] == nil else { return }
        }
        selected.remove(row.rowId)
        await finishReady()
    }

    /// The row's own action: its override first (episodes, a re-match, a title
    /// dismissal), then a commit of just this row. Re-match only re-targets
    /// (0.4.233 B1). An import over a copy that is not worse asks first
    /// ("Replace your copy?"); `confirmed` is the Replace, sent as Import anyway
    /// bound to the copy the row showed.
    func importRow(_ row: ManualImportRow, _ action: ManualImportDecide.RowAction, confirmed: Bool = false) async {
        guard !busyRows.contains(row.rowId), let client, let scanId = scan?.scanId else { return }
        if let ask = action.confirm, !confirmed {
            confirming[row.rowId] = ask
            return
        }
        confirming[row.rowId] = nil
        busyRows.insert(row.rowId)
        defer { busyRows.remove(row.rowId) }
        var current = row
        if let before = action.before {
            await patch(row, before)
            guard rowErrors[row.rowId] == nil else { return }
            current = rows.first { $0.rowId == row.rowId } ?? row
        }
        if !action.commits {
            notice = (ManualImportDecide.rematchedNotice(current), false)
            return
        }
        if action.before != nil, !confirmed, let ask = ManualImportDecide.replaceConfirm(current) {
            confirming[row.rowId] = ask  // the new episodes hold a copy that is not worse: ask first
            return
        }
        // Bound to the copy the confirm showed; a slot holding another file by now is refused.
        if confirmed, current.existingFile != nil, current.replaceChoice != "import" {
            await patch(row.existingFile != nil ? row : current, ["replace_choice": .string("import")])
            guard rowErrors[row.rowId] == nil else { return }
        }
        do {
            let mode = importMode
            let finish = finishDispositions(for: [row.rowId])
            let res = try await serially {
                try await client.manualImportCommit(scanId: scanId, rowIds: [row.rowId], mode: mode, finish: finish)
            }
            applyFinishes(res)
            guard let result = res.results.first(where: { $0.rowId == row.rowId }), result.error == nil else {
                rowErrors[row.rowId] = res.results.first { $0.rowId == row.rowId }?.error ?? "Couldn't import this file."
                return
            }
            rowErrors[row.rowId] = nil
            rowWarnings[row.rowId] = result.warning
            importedCount += 1
            selected.remove(row.rowId)
            markFinished((res.downloads ?? []).filter { $0.finished == true }.map(\.id))
            await reload()
            let after = rows.first { $0.rowId == row.rowId } ?? row
            receipts[row.rowId] = ManualImportDecide.importedReceipt(after, result)
            // A row still being put in place keeps its download held: never finish over it.
            if result.warning == nil { await finishReady(skip: Set((res.finishes ?? []).map(\.downloadId))) }
        } catch {
            if askReplace(error) { return }
            rowErrors[row.rowId] = ManualImportCopy.commitError(error)
        }
    }

    /// Replace on a row's "Replace your copy?": Import this file, confirmed.
    func replaceRow(_ row: ManualImportRow) async {
        guard let action = ManualImportDecide.importAction(row) ?? ManualImportDecide.rowAction(row) else { return }
        await importRow(row, action, confirmed: true)
    }

    /// A refusal that only needs "Replace your copy?" (422 `invalid_rows` on a
    /// replace verdict) puts the ask on each refused row; true when it did.
    func askReplace(_ error: Error) -> Bool {
        guard let api = error as? APIError else { return false }
        let refused = api.replaceRefusals
        guard !refused.isEmpty else { return false }
        for r in refused {
            let row = rows.first { $0.rowId == r.rowId }
            confirming[r.rowId] = row.flatMap(ManualImportDecide.replaceConfirm) ?? r.reason
            rowErrors[r.rowId] = nil
        }
        return refused.count == api.invalidRowCount
    }

    /// A 409 `leave_stands`: the stored leave wins, so drop this sheet's pick
    /// for that download and reload so the rows show it. True when it was one.
    func adoptStandingLeave(_ error: Error) async -> Bool {
        guard let stands = (error as? APIError)?.leaveStands else { return false }
        if let id = stands.downloadId { dispositions[id] = nil } else { dispositions.removeAll() }
        notice = (stands.detail, true)
        await reload()
        return true
    }

    // MARK: Finishing

    /// The downloads a commit of these rows may finish, with their pending dispositions.
    func finishDispositions(for rowIds: [Int]) -> [Int: FinishDisposition] {
        guard let scan else { return [:] }
        let ids = Set(scan.rows.filter { rowIds.contains($0.rowId) }.compactMap { ManualImportDecide.downloadId($0, scan) })
        var out: [Int: FinishDisposition] = [:]
        for id in ids {
            let mine = scan.rows.filter { ManualImportDecide.downloadId($0, scan) == id }
            guard mine.contains(where: { !$0.committed && $0.replaceChoice == "keep_current" }) else { continue }
            out[id] = savedDisposition(id) ?? ManualImportDecide.defaultDisposition(mine, scan)
        }
        return out
    }

    /// A commit's finishes: receipts, or the plain error (that download is left for the footer's retry).
    func applyFinishes(_ res: ManualImportCommitResult) {
        for f in res.finishes ?? [] {
            if let result = f.result, f.error == nil {
                recordFinish(f.downloadId, result)
            } else {
                if f.error == "leave_stands" { dispositions[f.downloadId] = nil }  // the stored leave wins
                skipOnce.insert(f.downloadId)
                notice = (ManualImportDecide.finishCodeMessage(f.error), true)
            }
        }
    }

    /// Finish every download whose rows are all decided (its own disposition, else the default).
    func finishReady(skip: Set<Int> = []) async {
        let tried = skip.union(skipOnce)
        skipOnce.removeAll()
        guard let scan else { return }
        for t in ManualImportDecide.readyToFinish(tallies) where !tried.contains(t.id) {
            let mine = scan.rows.filter { ManualImportDecide.downloadId($0, scan) == t.id }
            await finishOne(t.id, savedDisposition(t.id) ?? ManualImportDecide.defaultDisposition(mine, scan))
        }
    }

    private func finishOne(_ id: Int, _ disposition: FinishDisposition) async {
        guard let client, !inflight.contains(id) else { return }
        inflight.insert(id)
        working = true
        defer {
            inflight.remove(id)
            working = !inflight.isEmpty
        }
        do {
            let res = try await client.finishRescue(downloadId: id, disposition: disposition)
            recordFinish(id, res)
            await reload()
        } catch {
            if await adoptStandingLeave(error) { return }
            notice = (ManualImportCopy.finishError(error), true)
        }
    }

    /// The kept rows of a finished download get their receipts; it leaves every count.
    private func recordFinish(_ id: Int, _ res: FinishRescueResult) {
        finishResults[id] = res
        let mine = rows.filter { ManualImportDecide.downloadId($0, scan) == id }
        let group = mine.first { $0.replaceChoice == "keep_current" }?.existingFile?.releaseGroup ?? scan?.heldDetail?.currentGroup
        for r in mine where receipts[r.rowId] == nil {
            receipts[r.rowId] = r.committed ? ManualImportDecide.importedReceipt(r)
                : ManualImportDecide.keptReceipt(group: group, res, skipped: r.existingFile == nil)
        }
        markFinished([id])
    }

    func markFinished(_ ids: [Int]) {
        let fresh = Set(ids).subtracting(finishedHere)
        finishedCount += fresh.count
        finishedHere.formUnion(fresh)
    }
}
