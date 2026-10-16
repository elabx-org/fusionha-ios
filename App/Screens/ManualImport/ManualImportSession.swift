import SwiftUI
import FusionhaKit

/// Everything a Manual Import rescue holds and does (the web's
/// `useManualImportSession` + `useRescueDecide`): seeding the scan from held
/// downloads, the ticks (select is not import), per-row overrides, the commit,
/// and filling late probes. Deciding one file at a time and finishing each
/// download is in `ManualImportSession+Decide.swift` (fusionha 0.4.202).
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
    var rowErrors: [Int: String] = [:]
    var rowWarnings: [Int: String] = [:]
    var importMode: ManualImportMode = .auto
    /// A commit or finish in flight.
    var working = false
    /// Rows with an override in flight.
    private(set) var pendingRows: Set<Int> = []
    private(set) var bulkBusy = false
    private(set) var probeStalled = false
    /// A folder scan in flight.
    private(set) var scanning = false
    /// An in-sheet notice (errors, partial results).
    var notice: (text: String, error: Bool)?
    /// Set when the sheet should close; carries the receipt for the app toast.
    var closing: (text: String, warning: Bool)?

    // Decide one file at a time (the extension's state).
    /// Done receipts by row, worded from the server's answers.
    var receipts: [Int: ManualImportDecide.Receipt] = [:]
    /// Rows with a keep or import of their own in flight.
    var busyRows: Set<Int> = []
    /// Downloads this sheet finished.
    var finishedHere: Set<Int> = []
    /// Each download's picked disposition (a row's Keep current choice).
    var dispositions: [Int: FinishDisposition] = [:]
    /// Downloads a commit just tried to finish and could not: the next sweep leaves them.
    var skipOnce: Set<Int> = []
    var inflight: Set<Int> = []
    /// Downloads finished, and rows imported, for the closing toast.
    var finishedCount = 0
    var importedCount = 0
    /// The matched shows' seasons, for the episode picker.
    private(set) var seasons: [Int: [Season]] = [:]
    /// The server's edition names, for a movie row's Edition.
    private(set) var editionNames: [String] = []

    private var serial: Task<Void, Never>?
    let client: APIClient?

    init(rescueIds: [Int], client: APIClient?) {
        self.rescueIds = rescueIds
        self.client = client
    }

    var rows: [ManualImportRow] { scan?.rows ?? [] }
    var tallies: [Int: ManualImportDecide.Tally] { ManualImportDecide.tallies(scan, finishedHere: finishedHere) }
    var plan: ManualImportFinishPlan {
        let scan = scan, tallies = tallies
        return ManualImportFinishPlan(rows: rows, selected: selected,
                                      finished: { ManualImportDecide.rowFinished($0, scan, tallies) },
                                      pending: ManualImportDecide.readyToFinish(tallies).count)
    }

    // MARK: Seeding

    /// No held downloads: the folder scan (`POST /manualimport/scan`).
    var folderMode: Bool { rescueIds.isEmpty }

    func start() async {
        guard scan == nil, !folderMode, let client else { return }
        loadError = nil
        do {
            let fresh = try await client.manualImportRescue(downloadIds: rescueIds)
            scan = fresh
            selected = ManualImportRules.initialSelection(fresh)
        } catch {
            loadError = ErrorCopy.message(for: error, fallback: "Couldn't open these files. Try again.")
        }
    }

    /// Scans a folder; a new folder starts the decisions afresh.
    func scanFolder(_ path: String) async {
        let path = path.trimmingCharacters(in: .whitespaces)
        guard let client, !path.isEmpty, !scanning else { return }
        scanning = true
        defer { scanning = false }
        loadError = nil
        do {
            let fresh = try await client.manualImportScan(path: path)
            receipts = [:]
            rowErrors = [:]
            rowWarnings = [:]
            notice = nil
            scan = fresh
            selected = ManualImportRules.initialSelection(fresh)
        } catch {
            loadError = ErrorCopy.message(for: error, fallback: "Couldn't scan that folder. Check the path and try again.")
        }
    }

    func retryStart() async {
        scan = nil
        await start()
    }

    /// One write at a time, in order.
    func serially<T: Sendable>(_ op: @escaping @MainActor () async throws -> T) async throws -> T {
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
    /// with its own body; the selection follows each row's answer. Keep all
    /// current then finishes what is fully decided, removing only (a bulk
    /// choice never blocklists, and never replaces a row's own pick).
    func bulkHeld(_ choice: String) async {
        let targets = rows.filter { ManualImportHeldStrip.bulkEligible($0) && $0.replaceChoice != choice }
        bulkBusy = true
        defer { bulkBusy = false }
        if choice == "keep_current" {
            for id in Set(targets.compactMap { ManualImportDecide.downloadId($0, scan) }) where dispositions[id] == nil {
                dispositions[id] = .remove
            }
        }
        for row in targets { await patch(row, ["replace_choice": .string(choice)]) }
        if choice == "keep_current" { await finishReady() }
    }

    func adopt(_ fresh: ManualImportScan) {
        scan = fresh
        let open = Set(fresh.rows.filter { !$0.committed }.map(\.rowId))
        selected.formIntersection(open)
    }

    func reload() async {
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

    // MARK: Commit

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
