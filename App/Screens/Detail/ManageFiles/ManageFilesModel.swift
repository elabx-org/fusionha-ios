import Foundation
import FusionhaKit

/// State and actions of Manage files / Manage episodes (web
/// `ManageExistingFilesDialog` + `use-replace-action`): the scoped file list,
/// the selection, and Replace / Clean up / Delete / Move / Re-scan with the
/// server's stand-down answers read as notes, not failures.
@MainActor
@Observable
final class ManageFilesModel {
    let detail: ItemDetail
    let scopeVersionIds: Set<Int>?
    let season: Int?
    var client: APIClient?

    private(set) var items: [ManagedFileItem] = []
    private(set) var loaded = false
    private(set) var loadFailed = false
    var selected: Set<Int> = []
    private(set) var busy = false
    private(set) var deleting: Int?
    private(set) var rescanning = false
    var note: Note?
    /// Set after anything that changed files, so the detail page reloads on close.
    private(set) var changed = false

    struct Note: Equatable {
        let text: String
        let failed: Bool
        let id = UUID()
    }

    init(detail: ItemDetail, scopeVersionIds: Set<Int>?, season: Int?) {
        self.detail = detail
        self.scopeVersionIds = scopeVersionIds
        self.season = season
    }

    var isSeries: Bool { detail.kind == .series }
    var selectedItems: [ManagedFileItem] { items.filter { selected.contains($0.id) } }
    var allSelected: Bool { !items.isEmpty && selected.count == items.count }
    /// Move to version needs a movie with a sibling to move onto.
    var canMove: Bool { !isSeries && detail.editions.count > 1 }

    var subtitle: String {
        let part: String
        if let season { part = season == 0 ? "Specials" : "Season \(season)" } else { part = isSeries ? "All seasons" : "" }
        let scope = scopeVersionIds == nil ? "All versions"
            : detail.editions.filter { scopeVersionIds?.contains($0.id) == true }.map(versionName).joined(separator: " + ")
        return [detail.title, part, scope].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func versionName(_ e: DetailEdition) -> String {
        let multi = Set(detail.editions.map { $0.movieEdition ?? "" }).count > 1
        return VersionLabel.text(tier: e.tier, edition: e.movieEdition, multipleEditions: multi) ?? e.tier.chipLabel
    }

    func toggle(_ id: Int) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    func toggleAll() { selected = allSelected ? [] : Set(items.map(\.id)) }

    // MARK: Load

    func load() async {
        guard let client else { return }
        do {
            let rows = try await client.managedFiles(itemId: detail.id)
            items = ManagedFileRules.items(rows, detail: detail, scopeVersionIds: scopeVersionIds, season: season)
            selected.formIntersection(Set(items.map(\.id)))
            loadFailed = false
        } catch {
            loadFailed = true
        }
        loaded = true
    }

    // MARK: Edit

    /// Applies one partial edit to `fileIds`; returns false (with a note) on failure.
    func edit(_ fileIds: [Int], _ fields: [String: SettingsJSON]) async -> Bool {
        guard let client, !fields.isEmpty else { return true }
        do {
            _ = try await client.bulkEditFiles(itemId: detail.id, fileIds: fileIds, fields)
            changed = true
            await load()
            return true
        } catch {
            note = Note(text: ErrorCopy.message(for: error, fallback: "Couldn’t save the change. Try again."), failed: true)
            return false
        }
    }

    // MARK: Replace / Clean up

    /// Monitored rows re-grab (absent records through remove-and-regrab,
    /// unreadable ones forced), unmonitored rows only clean up.
    func replace(_ targets: [ManagedFileItem]) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        var replaced = 0, stood = 0, failed = 0
        let monitored = targets.filter(\.monitored)
        for t in targets where !t.monitored { await cleanup(t, client: client, count: &replaced, stood: &stood, failed: &failed) }
        for t in monitored where t.absent {
            do { try await client.removeAndRegrab(fileId: t.id); replaced += 1 } catch { tally(error, standDown: 422, &stood, &failed) }
        }
        let forced = monitored.filter { !$0.absent && $0.unreadable }.map(\.id)
        let dangling = monitored.filter { !$0.absent && !$0.unreadable }.map(\.id)
        for (ids, force) in [(dangling, false), (forced, true)] where !ids.isEmpty {
            do {
                if ids.count == 1 { try await client.replaceFile(fileId: ids[0], force: force) }
                else { try await client.bulkReplaceFiles(fileIds: ids, force: force) }
                replaced += ids.count
            } catch { tally(error, standDown: 409, &stood, &failed) }
        }
        await finish(replaced > 0 ? "Replaced. Searching for \(replaced == 1 ? "a new copy" : "new copies")." : nil,
               stood: stood > 0 ? "Mount not ready or the link recovered, so nothing was deleted." : nil, failed: failed,
               failedText: "Couldn’t replace \(failed == 1 ? "the file" : "\(failed) files"). Try again.")
    }

    func cleanup(_ targets: [ManagedFileItem]) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        var done = 0, stood = 0, failed = 0
        for t in targets { await cleanup(t, client: client, count: &done, stood: &stood, failed: &failed) }
        await finish(done > 0 ? "Dead link cleared. The version can re-grab." : nil,
               stood: stood > 0 ? "The link recovered, so there was nothing to clean up." : nil, failed: failed,
               failedText: "Couldn’t clean up the dead link. Try again.")
    }

    private func cleanup(_ t: ManagedFileItem, client: APIClient, count: inout Int, stood: inout Int, failed: inout Int) async {
        do { try await client.cleanupLink(fileId: t.id); count += 1 } catch { tally(error, standDown: 422, &stood, &failed) }
    }

    private func tally(_ error: Error, standDown status: Int, _ stood: inout Int, _ failed: inout Int) {
        if case APIError.http(status, _) = error { stood += 1 } else { failed += 1 }
    }

    private func finish(_ ok: String?, stood: String?, failed: Int, failedText: String) async {
        selected = []
        if failed > 0 {
            note = Note(text: failedText, failed: true)
        } else {
            let text = [ok, stood].compactMap { $0 }.joined(separator: " ")
            if !text.isEmpty { note = Note(text: text, failed: false) }
        }
        changed = true
        await load()
    }

    // MARK: Delete

    /// One file keeps the single-file path (blocklist opt-in, replacement
    /// search); several go through the bulk delete run.
    func delete(_ targets: [ManagedFileItem], blocklist: Bool = false) async {
        guard let client, !targets.isEmpty else { return }
        if targets.count == 1, let one = targets.first {
            do {
                try await client.deleteFile(id: one.id, blocklist: blocklist, search: true)
                note = Note(text: blocklist ? "File deleted and its release blocklisted." : "File deleted.", failed: false)
            } catch {
                note = Note(text: "Couldn’t remove the file. Try again.", failed: true)
            }
            selected.remove(one.id)
            changed = true
            await load()
            return
        }
        deleting = targets.count
        defer { deleting = nil }
        do {
            let start = try await client.bulkDeleteFiles(itemId: detail.id, fileIds: targets.map(\.id))
            if let runId = start.runId {
                var state = try await client.run(id: runId)
                while state.isRunning {
                    try await Task.sleep(for: .seconds(1))
                    state = try await client.run(id: runId)
                }
                note = state.failed ? Note(text: "The delete didn’t finish. Try again.", failed: true)
                    : Note(text: "Deleted \(start.total) files.", failed: false)
            }
        } catch {
            note = Note(text: "The delete didn’t finish. Try again.", failed: true)
        }
        selected = []
        changed = true
        await load()
    }

    // MARK: Move and re-scan

    func move(_ item: ManagedFileItem, to version: DetailEdition) async {
        guard let client else { return }
        busy = true
        defer { busy = false }
        do {
            try await client.repointFile(itemId: detail.id, fileId: item.id, versionId: version.id)
            note = Note(text: "File moved to \(versionName(version)).", failed: false)
            changed = true
            await load()
        } catch APIError.http(409, _) {
            note = Note(text: "That version already has a file.", failed: true)
        } catch {
            note = Note(text: "Couldn’t move the file. Try again.", failed: true)
        }
    }

    /// Refresh & scan files, then re-read the list once the run settles.
    func rescan() async {
        guard let client, !rescanning else { return }
        rescanning = true
        defer { rescanning = false }
        do {
            let dispatch = try await client.refreshItem(id: detail.id, metadataOnly: false)
            var state = try await client.run(id: dispatch.runId)
            while state.isRunning {
                try await Task.sleep(for: .seconds(1.5))
                state = try await client.run(id: dispatch.runId)
            }
            changed = true
            await load()
        } catch {
            note = Note(text: "Couldn’t re-scan the files. Try again.", failed: true)
        }
    }
}
