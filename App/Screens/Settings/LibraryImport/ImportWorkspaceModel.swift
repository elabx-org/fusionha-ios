import SwiftUI
import FusionhaKit

/// The triage workspace's state (web `ImportWorkspaceModal` + `useDebouncedDecisions`):
/// the polled session, the quality profiles, and the auto-save engine that
/// coalesces per-row edits by `scan_id:folder_key`, applies them at once, and
/// sends them as one PATCH after 400 ms of quiet.
@MainActor
@Observable
final class ImportWorkspaceModel {
    let sessionId: Int
    let client: APIClient?
    private(set) var session: LibraryImportSession?
    private(set) var profiles: [QualityProfile] = []
    var loadError: String?
    var actionError: String?
    private(set) var saving = false
    private(set) var saveFailed = false
    private(set) var working = false
    /// Rows whose profile a bulk apply stamped (cleared by a manual per-row pick).
    private(set) var bulkSetKeys: Set<String> = []
    private var pending: [String: LibraryImportPatch] = [:]
    private var debounce: Task<Void, Never>?

    init(sessionId: Int, client: APIClient?) {
        self.sessionId = sessionId
        self.client = client
    }

    var items: [LibraryImportItem] { session?.items ?? [] }
    var matched: [LibraryImportItem] { items.filter(\.matched) }
    var triage: LibraryImportTriage { LibraryImportRules.partition(items) }
    var isDraft: Bool { session?.isDraft == true }

    func item(_ id: String) -> LibraryImportItem? { items.first { $0.id == id } }

    // MARK: Loading and polling

    /// Loads, then polls every 1.5 s while a scan, the commit or the analysis is live.
    func run() async {
        await load()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let session, LibraryImportRules.needsPolling(session), pending.isEmpty, !saving else { continue }
            await refresh()
        }
    }

    func load() async {
        guard let client else { return }
        if profiles.isEmpty { profiles = (try? await client.qualityProfiles()) ?? [] }
        await refresh()
    }

    func refresh() async {
        guard let client else { return }
        do {
            let fresh = try await client.libraryImportSession(id: sessionId)
            session = LibraryImportRules.applying(Array(pending.values), to: fresh)
            loadError = nil
        } catch {
            if session == nil {
                loadError = ErrorCopy.message(for: error, fallback: "Couldn’t load this import.")
            }
        }
    }

    // MARK: Auto-save

    func queue(_ patch: LibraryImportPatch) {
        pending[patch.key] = pending[patch.key].map { $0.merged(with: patch) } ?? patch
        if let session { self.session = LibraryImportRules.applying([patch], to: session) }
        if patch.qualityProfileId != nil { bulkSetKeys.remove(patch.key) }
        saving = true
        saveFailed = false
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    /// Sends every pending edit now; a commit awaits this so it reads the durable decisions.
    func flush() async {
        debounce?.cancel()
        debounce = nil
        guard let client, !pending.isEmpty else {
            if pending.isEmpty { saving = false }
            return
        }
        let batch = Array(pending.values)
        pending.removeAll()
        do {
            let fresh = try await client.patchLibraryImport(id: sessionId, patches: batch)
            session = LibraryImportRules.applying(Array(pending.values), to: fresh)
            saveFailed = false
        } catch {
            // Nothing persisted: show "Not saved" and fall back to the server's truth.
            saveFailed = true
            await refresh()
        }
        if pending.isEmpty { saving = false }
    }

    // MARK: Row and bulk edits

    func setAccepted(_ item: LibraryImportItem, _ accepted: Bool) {
        queue(LibraryImportRules.acceptPatch(item, accepted: accepted, profiles: profiles))
    }

    func acceptAllReady() {
        let patches = LibraryImportRules.acceptAllPatches(triage.ready, profiles: profiles)
        guard !patches.isEmpty else { return }
        for p in patches { queue(p) }
        Task { await flush() }
    }

    func applyBulkProfile(_ profileId: Int, kind: MediaKind) {
        let targets = LibraryImportRules.bulkTargets(matched, kind: kind, profileId: profileId, profiles: profiles)
        guard !targets.isEmpty else { return }
        for row in targets {
            queue(LibraryImportPatch(scanId: row.scanId, folderKey: row.folderKey, qualityProfileId: profileId))
        }
        bulkSetKeys.formUnion(targets.map(\.id))
        Task { await flush() }
    }

    func applyBulkMonitor(_ value: Bool) {
        guard !matched.isEmpty else { return }
        for row in matched { queue(LibraryImportPatch(scanId: row.scanId, folderKey: row.folderKey, monitored: value)) }
        Task { await flush() }
    }

    // MARK: Session actions

    func rescan(scanId: Int? = nil) async {
        await perform("Couldn’t start the rescan.") { client in
            try await client.rescanLibraryImport(id: self.sessionId, scanId: scanId)
        }
    }

    func discard() async -> Bool {
        await perform("Couldn’t discard this draft.") { client in
            try await client.discardLibraryImport(id: self.sessionId)
        }
    }

    func commit() async {
        await flush()
        await perform("Couldn’t start the import.") { client in
            try await client.commitLibraryImport(id: self.sessionId)
        }
    }

    /// Repoints a row at the picked TMDB title, then accepts it.
    func override(_ itemId: String, tmdbId: Int) async -> Bool {
        guard let client, let row = item(itemId) else { return false }
        actionError = nil
        do {
            try await client.overrideLibraryImportMatch(scanId: row.scanId, groupId: row.groupId, tmdbId: tmdbId)
            setAccepted(row, true)
            await flush()
            if saveFailed { await refresh() }
            return true
        } catch {
            actionError = ErrorCopy.message(for: error, fallback: "Couldn’t change the match.")
            return false
        }
    }

    @discardableResult
    private func perform(_ fallback: String,
                         _ call: (APIClient) async throws -> LibraryImportSession) async -> Bool {
        guard let client else { return false }
        working = true
        defer { working = false }
        do {
            session = try await call(client)
            actionError = nil
            return true
        } catch {
            actionError = ErrorCopy.message(for: error, fallback: fallback)
            return false
        }
    }
}
