import SwiftUI
import FusionhaKit

/// The grouped Manual Import's choices before they are applied (v2 S9): the
/// draft (`MIDraft`), the held download's disposition, the open card and the
/// Files view's filter. The footer applies everything at once: the overrides
/// a choice needs first, then ONE all-or-nothing decide through v1's
/// `ManualImportSession` (its serial writes, finishes and receipts).
@MainActor
@Observable
final class V2MIDraftStore {
    enum Segment: String, CaseIterable, Identifiable {
        case groups = "Groups", files = "Files"
        var id: String { rawValue }
    }

    /// The chips over the list: every file, or the files doing one thing.
    enum Filter: Hashable {
        case all, imports, keeps, skips
    }

    var draft = MIDraft()
    /// The pick for the downloads of kept files; nil follows the pre-pick.
    var disposition: FinishDisposition?
    var segment: Segment = .groups
    var filter: Filter = .all
    /// The card shown beside the list on the open Duo, or pushed on the phone.
    var focus: MIProblem?
    /// The file shown beside the list on the open Duo.
    var fileFocus: Int?
    /// The list's scroll, so a fold's new host opens where the last one was.
    @ObservationIgnored var listY: CGFloat = 0
    /// Applying the draft.
    private(set) var applying = false

    // MARK: Reading

    func groups(_ s: ManualImportSession) -> [MIGroup] { MIProblemGrouping.groups(s.rows) }

    func group(_ p: MIProblem, _ s: ManualImportSession) -> MIGroup? { groups(s).first { $0.problem == p } }

    func choice(_ r: ManualImportRow, _ s: ManualImportSession) -> MIChoice? { draft.choice(r, rows: s.rows) }

    func counts(_ s: ManualImportSession) -> MIDraft.Counts { draft.counts(s.rows) }

    func plan(_ s: ManualImportSession) -> MICommitPlan { MICommitPlan(draft: draft, rows: s.rows) }

    /// Something was chosen on this page and not applied yet.
    var dirty: Bool { draft != MIDraft() }

    func shows(_ r: ManualImportRow, _ s: ManualImportSession) -> Bool {
        switch filter {
        case .all: return true
        case .imports: return choice(r, s)?.imports == true
        case .keeps: return choice(r, s) == .keep
        case .skips: return choice(r, s) == .skip
        }
    }

    /// The kept files' Keep current choices (v1's bulk summary over them):
    /// the dispositions offered, the pre-pick, and the request's per-download picks.
    func keepSummary(_ s: ManualImportSession) -> ManualImportBulkSummary? {
        let kept = Set(plan(s).kept)
        guard !kept.isEmpty else { return nil }
        let ctx = ManualImportBulk.Context(rows: s.rows, selected: kept, scan: s.scan, tallies: s.tallies)
        let summary = ManualImportBulkSummary(ctx, canRemove: s.canRemove)
        return summary.dispositions.isEmpty ? nil : summary
    }

    func effectiveDisposition(_ summary: ManualImportBulkSummary) -> FinishDisposition {
        guard let disposition, summary.dispositions.contains(where: { $0.value == disposition && $0.off == nil }) else {
            return summary.preferred
        }
        return disposition
    }

    /// Files whose import replaces a copy that is as good or better, or longer: the footer asks first.
    func replacements(_ s: ManualImportSession) -> [ManualImportRow] {
        let ids = Set(plan(s).replaces)
        return s.rows.filter { ids.contains($0.rowId) }
    }

    // MARK: Ticked files (the Files view)

    /// The ticked files' choices staged at once, never over a better copy
    /// (the bulk rule: "Import 1 of 4").
    func stage(_ action: ManualImportDecideAction, _ s: ManualImportSession) {
        let summary = s.bulk
        let targets: [ManualImportRow]
        let choice: MIChoice
        switch action {
        case .importFile: targets = summary.imp; choice = .importFile
        case .keepCurrent: targets = summary.keep; choice = .keep
        case .skip: targets = summary.skip; choice = .skip
        }
        for r in targets { draft.setFile(r, MIProblemGrouping.fit(choice, r, rows: s.rows) ?? choice, rows: s.rows) }
        s.selected.subtract(targets.map(\.rowId))
    }

    /// Fusionha's pick for the ticked files that have one.
    func usePicks(_ s: ManualImportSession) {
        let ticked = s.rows.filter { s.selected.contains($0.rowId) }
        draft.usePicks(ticked, rows: s.rows)
        s.selected.subtract(ticked.filter { MIProblemGrouping.pick($0, rows: s.rows) != nil }.map(\.rowId))
    }

    func tickedPicks(_ s: ManualImportSession) -> Int {
        s.rows.filter { s.selected.contains($0.rowId) && MIProblemGrouping.pick($0, rows: s.rows) != nil }.count
    }

    // MARK: Applying

    /// The overrides one at a time, then one decide. The decide's rows and
    /// picks are fixed before the overrides (an override can move a file to
    /// another group); an override that fails stops before the decide.
    func apply(_ s: ManualImportSession) async {
        guard !applying, !s.working, s.applying == nil, let client = s.client, let scanId = s.scan?.scanId else { return }
        let plan = plan(s)
        guard !plan.isEmpty else { return }
        let picks = keepSummary(s).flatMap { $0.request(.keepCurrent, pick: effectiveDisposition($0), mode: s.importMode)?.dispositions } ?? [:]
        let request = plan.request(dispositions: picks, mode: s.importMode)
        applying = true
        s.working = true
        defer {
            applying = false
            s.working = false
        }
        s.notice = nil
        for p in plan.patches {
            guard let row = s.rows.first(where: { $0.rowId == p.rowId }) else { continue }
            await s.patch(row, p.fields)
            if let error = s.rowErrors[p.rowId] {
                s.notice = (error, true)
                return
            }
        }
        guard let request else {
            draft = MIDraft()
            return
        }
        do {
            let res = try await s.serially { try await client.manualImportDecide(scanId: scanId, request) }
            s.adopt(res.scan)
            s.applyFinishes(res.asCommit)
            s.markFinished((res.downloads ?? []).filter { $0.finished == true }.map(\.id))
            let failed = (res.results ?? []).filter { $0.error != nil && $0.error != "already committed" }
            s.importedCount += (res.results ?? []).count - failed.count
            for r in failed { s.rowErrors[r.rowId] = r.error }
            if !failed.isEmpty {
                s.notice = (ManualImportCopy.commitNotice(ok: 0, warned: 0, failed: failed.count), true)
            }
            // An accepted Import anyway ticks its row (v1's `patch`): nothing stays ticked here.
            s.selected = []
            draft = MIDraft()
        } catch {
            if await s.adoptStandingLeave(error) { return }
            _ = s.askReplace(error)
            s.notice = (ManualImportCopy.decideError(error), true)
        }
    }
}
