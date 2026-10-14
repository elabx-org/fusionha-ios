import SwiftUI
import FusionhaKit

/// Everything a Manual Import rescue holds and does (the web's
/// `useManualImportSession` + `useFinishRescue`): seeding the scan from held
/// downloads, the ticks (select is not import), per-row overrides, the commit,
/// finishing the download(s), and filling late probes.
///
/// Every write to one scan read-modify-writes its rows server-side, so writes
/// run one at a time (`serial`), as the web's `enqueueScanWrite` does.
@MainActor
@Observable
final class ManualImportSession {
    let rescueIds: [Int]
    private(set) var scan: ManualImportScan?
    private(set) var loadError: String?
    var selected: Set<Int> = []
    private(set) var rowErrors: [Int: String] = [:]
    private(set) var rowWarnings: [Int: String] = [:]
    var importMode: ManualImportMode = .auto
    var blocklist = true
    /// A commit or finish in flight.
    private(set) var working = false
    /// Rows with an override in flight.
    private(set) var pendingRows: Set<Int> = []
    private(set) var bulkBusy = false
    private(set) var probeStalled = false
    /// An in-sheet notice (errors, partial results).
    var notice: (text: String, error: Bool)?
    /// Set when the sheet should close; carries the receipt for the app toast.
    private(set) var closing: (text: String, warning: Bool)?
    /// The matched shows' seasons, for the episode picker.
    private(set) var seasons: [Int: [Season]] = [:]
    /// The server's edition names, for a movie row's Edition.
    private(set) var editionNames: [String] = []

    private var finished: [Int: String] = [:]
    private var serial: Task<Void, Never>?
    private let client: APIClient?

    init(rescueIds: [Int], client: APIClient?) {
        self.rescueIds = rescueIds
        self.client = client
    }

    var rows: [ManualImportRow] { scan?.rows ?? [] }
    var plan: ManualImportFinishPlan { ManualImportFinishPlan(rows: rows, selected: selected) }
    var guarded: Bool { scan?.heldDetail?.releaseBlocklisted == true }
    var showBlocklist: Bool { plan.kind == .keep && !guarded }

    // MARK: Seeding

    func start() async {
        guard scan == nil, let client else { return }
        loadError = nil
        do {
            let fresh = try await client.manualImportRescue(downloadIds: rescueIds)
            scan = fresh
            selected = ManualImportRules.initialSelection(fresh)
        } catch {
            loadError = ErrorCopy.message(for: error, fallback: "Couldn't open these files. Try again.")
        }
    }

    func retryStart() async {
        scan = nil
        await start()
    }

    /// One write at a time, in order.
    private func serially<T: Sendable>(_ op: @escaping @MainActor () async throws -> T) async throws -> T {
        let previous = serial
        let task = Task { @MainActor () async throws -> T in
            await previous?.value
            return try await op()
        }
        serial = Task { _ = try? await task.value }
        return try await task.value
    }

    // MARK: Ticks

    func toggle(_ row: ManualImportRow) {
        guard !row.committed else { return }
        if selected.contains(row.rowId) { selected.remove(row.rowId) } else { selected.insert(row.rowId) }
    }

    // MARK: Overrides

    /// One row's override. Import anyway is always bound to the file on screen
    /// (the server refuses it when the slot holds another file by now). Keep
    /// current unticks the row; an accepted Import anyway ticks it.
    func patch(_ row: ManualImportRow, _ fields: [String: SettingsJSON]) async {
        guard let client, let scanId = scan?.scanId else { return }
        var body = fields
        let importing = fields["replace_choice"] == SettingsJSON.string("import")
        if importing, let current = row.existingFile {
            guard let id = current.mediaFileId else {
                rowErrors[row.rowId] = "The current file changed. Review it again."
                return
            }
            body["replace_against_media_file_id"] = .int(id)
        }
        if fields["replace_choice"] == SettingsJSON.string("keep_current") { selected.remove(row.rowId) }
        let payload = body
        pendingRows.insert(row.rowId)
        defer { pendingRows.remove(row.rowId) }
        do {
            let fresh = try await serially { try await client.manualImportOverride(scanId: scanId, rowId: row.rowId, payload) }
            adopt(fresh)
            rowErrors[row.rowId] = nil
            if importing { selected.insert(row.rowId) }
        } catch {
            if importing { await reload() }
            rowErrors[row.rowId] = ErrorCopy.message(for: error, fallback: "Couldn't change this file. Try again.")
        }
    }

    /// Keep all current / Import all: one override per held downgrade, each
    /// with its own body; the selection follows each row's answer.
    func bulkHeld(_ choice: String) async {
        let targets = rows.filter { ManualImportHeldStrip.bulkEligible($0) && $0.replaceChoice != choice }
        bulkBusy = true
        defer { bulkBusy = false }
        for row in targets { await patch(row, ["replace_choice": .string(choice)]) }
    }

    private func adopt(_ fresh: ManualImportScan) {
        scan = fresh
        let open = Set(fresh.rows.filter { !$0.committed }.map(\.rowId))
        selected.formIntersection(open)
    }

    private func reload() async {
        guard let client, let id = scan?.scanId, let fresh = try? await client.manualImportScan(id: id) else { return }
        adopt(fresh)
    }

    // MARK: Episodes

    func loadSeasons(itemId: Int) async {
        guard seasons[itemId] == nil, let client, let item = try? await client.item(id: itemId) else { return }
        seasons[itemId] = item.seasons ?? []
    }

    func loadEditions() async {
        guard editionNames.isEmpty, let client, let defs = try? await client.editionDefinitions() else { return }
        editionNames = defs.filter { $0.enabled != false }.map(\.name)
    }

    // MARK: Probes

    /// Fills late probes while any are pending: backs off 2, 4, 8, then 15 s
    /// without progress, pauses during a commit, and stalls after two minutes
    /// with no progress (`retryProbes` starts again).
    func pollProbes() async {
        guard let client, let scanId = scan?.scanId else { return }
        var noProgress = 0
        var since: Date?
        probeStalled = false
        while (scan?.probePending ?? 0) > 0, !Task.isCancelled {
            let delay = noProgress == 0 ? 0.5 : min(2 * pow(2, Double(noProgress - 1)), 15)
            try? await Task.sleep(for: .seconds(delay))
            if working { continue }
            let before = scan?.probePending ?? 0
            guard let fresh = try? await serially({ try await client.manualImportProbe(scanId: scanId) }) else {
                noProgress += 1
                continue
            }
            adopt(fresh)
            if (fresh.probePending ?? 0) < before {
                noProgress = 0
                since = nil
            } else {
                noProgress += 1
                since = since ?? .now
                if let since, Date.now.timeIntervalSince(since) >= 120 { probeStalled = true; return }
            }
        }
    }

    func retryProbes() { probeStalled = false }

    // MARK: Commit and finish

    struct CommitSummary { let ok: Int; let failed: Int; let warned: Int }

    /// Commits only ticked rows the server would accept.
    @discardableResult
    func commitSelected(finishing: Bool = false) async -> CommitSummary? {
        guard let client, let scanId = scan?.scanId else { return nil }
        let ids = rows.filter { selected.contains($0.rowId) && ManualImportRules.isImportable($0) }.map(\.rowId)
        guard !ids.isEmpty else { return nil }
        working = true
        defer { working = false }
        do {
            let mode = importMode
            let result = try await serially { try await client.manualImportCommit(scanId: scanId, rowIds: ids, mode: mode) }
            var ok = 0, warned = 0
            for r in result.results {
                if let error = r.error { rowErrors[r.rowId] = error; continue }
                ok += 1
                rowErrors[r.rowId] = nil
                if let warning = r.warning { rowWarnings[r.rowId] = warning; warned += 1 } else { rowWarnings[r.rowId] = nil }
            }
            let summary = CommitSummary(ok: ok, failed: result.results.count - ok, warned: warned)
            await reload()
            if !finishing || summary.failed > 0 || summary.warned > 0 {
                let text = ManualImportCopy.commitNotice(ok: ok, warned: warned, failed: summary.failed)
                if !finishing, summary.failed == 0, summary.warned == 0, rows.allSatisfy(\.committed) {
                    closing = (text, false)
                } else {
                    notice = (text, summary.failed > 0)
                }
            }
            return summary
        } catch {
            notice = (ManualImportCopy.commitError(error), true)
            return CommitSummary(ok: 0, failed: ids.count, warned: 0)
        }
    }

    /// The footer's primary, as the plan names it.
    func runPrimary() async {
        let plan = plan
        guard !working, !plan.disabled else { return }
        switch plan.kind {
        case .importOnly: await commitSelected()
        case .need: return
        case .keep: await finish(imported: 0, plan: plan)
        case .mixed:
            guard plan.imports > 0 else { return await finish(imported: plan.done, plan: plan) }
            // Finish only after a clean commit: a failed or still-being-placed row keeps the download open.
            guard let s = await commitSelected(finishing: true), s.failed == 0, s.warned == 0 else { return }
            await finish(imported: s.ok, plan: plan)
        }
    }

    /// Ends every held download of the rescue in turn; ones already ended are skipped.
    private func finish(imported: Int, plan: ManualImportFinishPlan) async {
        guard let client else { return }
        let blocklisting = showBlocklist && blocklist
        let group = scan?.heldDetail?.currentGroup
            ?? rows.first { $0.replaceChoice == "keep_current" }?.existingFile?.releaseGroup
        working = true
        defer { working = false }
        for id in rescueIds where finished[id] == nil {
            do {
                finished[id] = try await client.finishRescue(downloadId: id, blocklist: blocklisting).mode
            } catch {
                let lead = rescueIds.count > 1 ? "Finished \(finished.count) of \(rescueIds.count) downloads. " : ""
                let head = imported > 0 ? "Imported \(imported) · " : ""
                notice = (head + lead + ManualImportCopy.finishError(error), true)
                return
            }
        }
        let mode = finished.values.contains("finished") ? "finished" : "removed"
        closing = (ManualImportCopy.finishReceipt(mode: mode, imported: imported, kept: plan.kept,
                                                  group: group, count: rescueIds.count), false)
    }
}
