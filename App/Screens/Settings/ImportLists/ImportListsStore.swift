import SwiftUI
import FusionhaKit

/// Settings › Media Management › Import lists (web `ImportListsPanel` and its
/// hooks, fusionha 0.4.237): the lists, exclusions and the folder / profile
/// choices the form offers. Every write re-reads what it touched.
@MainActor
@Observable
final class ImportListsStore {
    var lists: [ImportList] = []
    var loaded = false
    var failed = false
    var exclusions: [ImportListExclusion]?
    var exclusionsFailed = false
    var rootFolders: [RootFolder] = []
    var profiles: [QualityProfile] = []
    /// List ids with a Sync now or a switch in flight.
    var busy: Set<Int> = []

    func load(_ client: APIClient?) async {
        guard let client else { return }
        do {
            lists = try await client.importLists()
            failed = false
        } catch {
            if !loaded { failed = true }
        }
        loaded = true
    }

    /// The form's pickers (once).
    func loadChoices(_ client: APIClient?) async {
        guard let client, rootFolders.isEmpty || profiles.isEmpty else { return }
        rootFolders = (try? await client.rootFolders()) ?? []
        profiles = (try? await client.qualityProfiles()) ?? []
    }

    func list(_ id: Int?) -> ImportList? { lists.first { $0.id == id } }

    /// While a Sync now waits for the job, re-read every few seconds (web `syncPollMs`).
    var waitingOnSync: Bool { lists.contains { $0.syncRequestedAt != nil } }

    // MARK: Row actions

    func setEnabled(_ list: ImportList, _ on: Bool, _ model: AppModel) async {
        await run(list.id, model, failure: ImportListCopy.saveFailed) {
            _ = try await $0.updateImportList(list.id, .object(["enabled": .bool(on)]))
        }
    }

    func sync(_ list: ImportList, _ model: AppModel) async {
        guard let client = model.client, !busy.contains(list.id) else { return }
        busy.insert(list.id)
        defer { busy.remove(list.id) }
        do {
            try await client.syncImportList(list.id)
            model.toast(ImportListCopy.checking(list.name))
        } catch {
            var limited = false
            if case .http(429, _)? = error as? APIError { limited = true }
            model.toast(limited ? ImportListCopy.syncLimited : ImportListCopy.syncFailed, variant: .error)
        }
        await load(client)
    }

    func delete(_ list: ImportList, _ model: AppModel) async {
        await run(list.id, model, failure: ImportListCopy.deleteFailed) { try await $0.deleteImportList(list.id) }
    }

    private func run(_ id: Int, _ model: AppModel, failure: String, _ call: (APIClient) async throws -> Void) async {
        guard let client = model.client else { return }
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            try await call(client)
        } catch {
            model.toast(failure, variant: .error)
        }
        await load(client)
    }

    // MARK: Exclusions

    func loadExclusions(_ client: APIClient?) async {
        guard let client else { return }
        do {
            exclusions = try await client.importListExclusions()
            exclusionsFailed = false
        } catch {
            if exclusions == nil { exclusionsFailed = true }
        }
    }

    func removeExclusion(_ e: ImportListExclusion, _ model: AppModel) async {
        guard let client = model.client else { return }
        do {
            try await client.removeImportListExclusion(e.id)
            exclusions?.removeAll { $0.id == e.id }
        } catch {
            model.toast("Couldn’t remove it. Try again.", variant: .error)
        }
    }

    /// Exclude a picked TMDB title on every list (`listId` nil) or one.
    func exclude(_ pick: MediaSearchResult, listId: Int?, _ model: AppModel) async -> Bool {
        guard let client = model.client else { return false }
        do {
            _ = try await client.addImportListExclusion(tmdbId: pick.tmdbId, kind: pick.kind, title: pick.title,
                                                        year: pick.year, listId: listId)
            model.toast("\(ImportListCopy.titleWithYear(pick.title, pick.year)) is excluded")
            await loadExclusions(client)
            return true
        } catch {
            model.toast(ImportListCopy.serverMessage(error), variant: .error)
            return false
        }
    }
}
