import Foundation
import Observation
import SwiftUI
import FusionhaKit

/// The detail page's tabs (DetailTabs.tsx). `files` is "Editions" on a movie.
enum DetailTab: String, Hashable {
    case seasons, files, history, searches, collection
}

/// What the interactive-search sheet searches.
struct InteractiveTarget: Identifiable {
    let id = UUID()
    /// The editions offered as tabs (one, or every edition for "All editions").
    var editionIds: [Int]
    var episodeId: Int?
    var seasonNumber: Int?
    var subtitle: String
}

/// The AddEditionDialog preset (`{tier, version}`), or none.
struct AddEditionPreset: Identifiable {
    let id = UUID()
    var tier: QualityTier?
    var version: String?
}

struct SeasonRef: Identifiable {
    let number: Int
    var id: Int { number }
}

/// The AutoSearchFlash strip state.
struct SearchFlash: Equatable {
    enum Phase { case searching, done }
    var phase: Phase
    var scope: String
    var grabbed = 0
    var score: Int?
    let id = UUID()
}

/// A running gradual (one-at-a-time) search.
struct GradualJob: Equatable {
    var runId: Int?
    var season: Int?
    var total: Int
    var current: Int = 0
    var label: String
    var stopping = false
}

/// State and actions of one item detail sheet. Every call matches the web app's
/// endpoint, query keys and body.
@MainActor
@Observable
final class DetailStore {
    let itemId: Int
    var client: APIClient?

    private(set) var detail: ItemDetail?
    private(set) var loadError: String?
    private(set) var profiles: [QualityProfile] = []
    private(set) var roots: [RootFolder] = []
    private(set) var enrichment: EnrichmentStatus?
    private(set) var pauses: SearchPauses?
    private(set) var settings: DetailSettings?
    private(set) var runs: [CommandRun] = []
    private(set) var runsTotal = 0
    private(set) var runsLoaded = false
    var queue: [QueueItem] = []

    var scope: DetailScope {
        didSet {
            UserDefaults.standard.set(scope.serialized, forKey: DetailScope.storageKey)
            if scope != oldValue { folded = false }
        }
    }
    var tab: DetailTab = .seasons
    var folded = false
    var oldestFirst: Set<Int> = []
    var toast: DetailToast?
    var flash: SearchFlash?
    var gradual: GradualJob?
    var refreshing = false
    var deleted = false

    /// Optimistic monitor flips while the PATCH is in flight.
    var seasonMonitorOverride: [Int: Bool] = [:]
    var editionMonitorOverride: [Int: Bool] = [:]

    // Sheets
    var interactive: InteractiveTarget?
    var showingEdit = false
    var addPreset: AddEditionPreset?
    var showingDelete = false
    var seasonSheet: SeasonRef?

    init(itemId: Int) {
        self.itemId = itemId
        scope = DetailScope.parse(UserDefaults.standard.string(forKey: DetailScope.storageKey))
    }

    // MARK: Derived

    var effScope: DetailScope { detail?.effectiveScope(scope) ?? scope }
    var scopeEditionId: Int? { detail?.scopeEditionId(scope) }
    var scopedEditions: [DetailEdition] { detail?.scopedEditions(scope) ?? [] }
    var actsOnLabel: String { detail?.scopeLabel(scope, allText: "all editions") ?? "all editions" }
    var showingLabel: String { detail?.scopeLabel(scope, allText: "All editions") ?? "All editions" }

    /// Editions with a live queue row (the web filters `GET /api/v1/queue` to active states).
    var activeQueueEditionIds: Set<Int> {
        Set(queue.filter { $0.mediaItemId == itemId && $0.status.lowercased() != "completed" && $0.status.lowercased() != "failed" }
            .map(\.editionId))
    }

    func dot(_ edition: DetailEdition) -> EditionDot {
        detail?.dot(for: edition, activeQueueEditionIds: activeQueueEditionIds) ?? .miss
    }

    func profile(_ id: Int?) -> QualityProfile? { profiles.first { $0.id == id } }
    func profileName(_ id: Int?) -> String { profile(id)?.name ?? "—" }
    func cutoff(_ id: Int?) -> String? { profile(id)?.cutoff }
    func rootPath(_ edition: DetailEdition) -> String {
        if let root = roots.first(where: { $0.id == edition.rootFolderId }) { return root.path }
        guard let path = edition.fullPath else { return "—" }
        return (path as NSString).deletingLastPathComponent
    }

    func seasonMonitored(_ season: Season) -> Bool {
        seasonMonitorOverride[season.seasonNumber] ?? (season.monitored != false)
    }

    func editionMonitored(_ edition: DetailEdition) -> Bool {
        editionMonitorOverride[edition.id] ?? edition.monitored
    }

    var seasonInterval: Int { settings?.seasonSearchIntervalSeconds ?? 5 }

    // MARK: Loading

    func load() async {
        guard let client else { return }
        await reload()
        async let profiles = try? client.qualityProfiles()
        async let roots = try? client.rootFolders()
        async let settings = try? client.detailSettings()
        async let enrichment = try? client.enrichmentStatus()
        async let pauses = try? client.searchPauses(itemId: itemId)
        let (p, r, s, e, ps) = await (profiles, roots, settings, enrichment, pauses)
        if let p { self.profiles = p }
        if let r { self.roots = r }
        self.settings = s
        self.enrichment = e
        self.pauses = ps
    }

    /// Re-fetches the item (after an action), keeping the page in place.
    func reload() async {
        guard let client else { return }
        do {
            let item = try await client.item(id: itemId)
            detail = item
            loadError = nil
            seasonMonitorOverride = [:]
            editionMonitorOverride = [:]
        } catch {
            if detail == nil { loadError = error.localizedDescription }
        }
    }

    func loadRuns() async {
        guard let client else { return }
        if let page = try? await client.runs(touchedItem: itemId) {
            runs = page.items
            runsTotal = page.total
        }
        runsLoaded = true
    }

    func show(_ message: String, title: String? = nil, variant: DetailToast.Variant = .info,
              actionLabel: String? = nil, action: (() -> Void)? = nil) {
        toast = DetailToast(title: title, message: message, variant: variant, actionLabel: actionLabel, action: action)
    }

    // MARK: Searches

    /// The scoped automatic search. Returns the decisions (nil on failure) and
    /// drives the flash strip and the toast like the web's SearchActionButton.
    @discardableResult
    func search(label: String, editionId: Int? = nil, season: Int? = nil, episodeId: Int? = nil,
                missingOnly: Bool = false) async -> [SearchDecision]? {
        guard let client else { return nil }
        flash = SearchFlash(phase: .searching, scope: label)
        do {
            let decisions = try await client.search(itemId: itemId, editionId: editionId, season: season,
                                                    episodeId: episodeId, missingOnly: missingOnly)
            let grabbed = decisions.filter(\.grabbed)
            flash = SearchFlash(phase: .done, scope: label, grabbed: grabbed.count, score: grabbed.compactMap(\.score).max())
            if grabbed.isEmpty {
                show("Searched \(label) — nothing grabbed", variant: .warning)
            } else {
                let editions = Set(grabbed.compactMap(\.editionId)).count
                let n = max(editions, 1)
                show("Searching \(label) — grabbing \(n) edition\(n == 1 ? "" : "s")", variant: .success,
                     actionLabel: "View trail") { [weak self] in self?.tab = .searches }
            }
            scheduleFlashClear()
            await reload()
            await loadRuns()
            return decisions
        } catch {
            flash = nil
            show("Couldn't search \(label)", variant: .error)
            return nil
        }
    }

    private func scheduleFlashClear() {
        let current = flash?.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            if self?.flash?.id == current { self?.flash = nil }
        }
    }

    /// One-at-a-time search of the whole title (`season == nil`) or one season.
    func gradualSearch(label: String, season: Int? = nil, editionId: Int? = nil, missingOnly: Bool) async {
        guard let client else { return }
        do {
            let start = try await client.gradualSearch(itemId: itemId, season: season, editionId: editionId, missingOnly: missingOnly)
            guard let runId = start.runId, (start.total ?? 0) > 0 else {
                show("Nothing to search in \(label)", variant: .info)
                return
            }
            gradual = GradualJob(runId: runId, season: season, total: start.total ?? 0, label: label)
            await pollGradual(runId: runId)
        } catch {
            show("Couldn't search \(label)", variant: .error)
        }
    }

    private func pollGradual(runId: Int) async {
        guard let client else { return }
        while let job = gradual, job.runId == runId {
            try? await Task.sleep(for: .seconds(1.5))
            guard let run = try? await client.commandRun(id: runId) else { continue }
            gradual?.current = run.progressCurrent ?? gradual?.current ?? 0
            if let total = run.progressTotal { gradual?.total = total }
            if !run.isRunning {
                gradual = nil
                let grabbed = (run.grabbed ?? 0) + (run.upgraded ?? 0)
                show(grabbed > 0 ? "Searched \(job.label) — grabbed \(grabbed)" : "Searched \(job.label) — nothing grabbed",
                     variant: grabbed > 0 ? .success : .warning)
                await reload()
                await loadRuns()
            }
        }
    }

    func stopGradual() async {
        guard let client, let job = gradual else { return }
        gradual?.stopping = true
        try? await client.cancelGradualSearch(itemId: itemId, season: job.season)
    }

    // MARK: Refresh

    func refresh(metadataOnly: Bool) async {
        guard let client, let title = detail?.title else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let dispatch = try await client.refreshItem(id: itemId, metadataOnly: metadataOnly)
            let run = await waitForRun(dispatch.runId)
            await reload()
            if run?.status == "failed" {
                show("Couldn't refresh \(title)", variant: .error)
            } else {
                showRescan(run?.rescanSummary, title: title)
            }
        } catch {
            show("Couldn't refresh \(title)", variant: .error)
        }
    }

    func refreshSeason(_ number: Int) async {
        guard let client else { return }
        let name = number == 0 ? "Specials" : "Season \(number)"
        do {
            let dispatch = try await client.refreshSeason(itemId: itemId, season: number)
            show("Refreshing \(name)…")
            let run = await waitForRun(dispatch.runId)
            await reload()
            showRescan(run?.rescanSummary, title: name)
        } catch {
            show("Couldn't refresh \(name)", variant: .error)
        }
    }

    private func waitForRun(_ id: Int) async -> CommandRun? {
        guard let client else { return nil }
        for _ in 0..<200 {
            try? await Task.sleep(for: .seconds(1.5))
            if let run = try? await client.commandRun(id: id), !run.isRunning { return run }
        }
        return nil
    }

    /// `rescanSummaryToast`.
    private func showRescan(_ summary: RescanSummary?, title: String) {
        let heading = "Refreshed \(title)"
        guard let summary else { show("Metadata updated.", title: heading, variant: .success); return }
        var clauses: [String] = []
        var variant: DetailToast.Variant = .success
        let standdown = summary.standdown ?? []
        if !standdown.isEmpty {
            let labels = standdown.compactMap { id in detail?.editions.first { $0.id == id }?.tier.chipLabel }
            let folder = standdown.count > 1 ? "library folders look" : "library folder looks"
            clauses.append("\(labels.isEmpty ? "A" : labels.joined(separator: ", ")) \(folder) unreachable — skipped, nothing touched.")
            variant = .warning
        }
        let unresolved = (summary.flagged ?? 0) + (summary.dangling ?? 0)
        if unresolved > 0 {
            clauses.append("\(unresolved) \(unresolved == 1 ? "file" : "files") couldn't be resolved on the last scan — none removed yet (confirming over the safety window).")
            variant = .warning
        }
        var changes: [String] = []
        if let n = summary.attached, n > 0 { changes.append("\(n) imported") }
        if let n = summary.healed, n > 0 { changes.append("\(n) recovered") }
        if let n = summary.removed, n > 0 { changes.append("\(n) removed") }
        if let n = summary.probed, n > 0 { changes.append("\(n) re-analysed") }
        if !changes.isEmpty { clauses.append(changes.joined(separator: " · ") + ".") }
        if clauses.isEmpty { show("No changes.", title: heading, variant: .info); return }
        show(clauses.joined(separator: " "), title: heading, variant: variant)
    }

    // MARK: Numbering

    /// `checkOrOpenNumbering`. The review dialog lives in the web app.
    func checkNumbering(openWeb: @escaping () -> Void) async {
        guard let client, let detail else { return }
        if detail.numberingMismatch == true { openWeb(); return }
        do {
            let preview = try await client.numberingPreview(itemId: itemId)
            let label = preview.source == "tvdb" ? "TVDB" : "TVmaze"
            if preview.agrees == false {
                show("Episode numbering differs from \(label) — review it in the web app", variant: .warning,
                     actionLabel: "Review", action: openWeb)
            } else {
                show("Numbering matches \(label) — no change needed")
            }
        } catch {
            show("Couldn't check episode numbering.", variant: .error)
        }
    }

    // MARK: Monitoring

    func setSeasonMonitored(_ number: Int, _ on: Bool) async {
        guard let client else { return }
        let name = number == 0 ? "Specials" : "Season \(number)"
        seasonMonitorOverride[number] = on
        do {
            try await client.setSeasonMonitored(itemId: itemId, season: number, monitored: on)
            show(on ? "Monitoring \(name)" : "Stopped monitoring \(name)", variant: .success)
            await reload()
        } catch {
            seasonMonitorOverride[number] = nil
            show("Couldn't update \(name)", variant: .error)
        }
    }

    func setEditionMonitored(_ edition: DetailEdition, _ on: Bool) async {
        guard let client else { return }
        editionMonitorOverride[edition.id] = on
        do {
            try await client.updateEdition(itemId: itemId, editionId: edition.id, EditionUpdate(monitored: on))
            await reload()
        } catch {
            editionMonitorOverride[edition.id] = nil
            show("Couldn't update \(edition.label)", variant: .error)
        }
    }

    // MARK: Files and history

    func deleteFile(_ fileId: Int, blocklist: Bool) async {
        guard let client else { return }
        do {
            try await client.deleteFile(id: fileId, blocklist: blocklist)
            show(blocklist ? "File deleted and release blocklisted" : "File deleted", variant: .success)
            await reload()
        } catch {
            show("Couldn't delete the file", variant: .error)
        }
    }

    func cleanupLink(_ fileId: Int) async {
        guard let client else { return }
        do {
            try await client.cleanupLink(fileId: fileId)
            show("Dead link cleaned up", variant: .success)
            await reload()
        } catch {
            show("Couldn't clean up the link", variant: .error)
        }
    }

    func regrab(_ entry: HistoryEntry) async {
        guard let client else { return }
        do {
            try await client.regrab(historyId: entry.id)
            show("Re-grabbing \(entry.sourceTitle ?? "release")", variant: .success)
            await reload()
        } catch {
            show("Couldn't re-grab that release", variant: .error)
        }
    }

    func deleteItem(deleteFiles: Bool) async -> Bool {
        guard let client, let title = detail?.title else { return false }
        do {
            try await client.deleteItem(id: itemId, deleteFiles: deleteFiles)
            deleted = true
            return true
        } catch {
            show("Couldn't delete \(title)", variant: .error)
            return false
        }
    }
}
