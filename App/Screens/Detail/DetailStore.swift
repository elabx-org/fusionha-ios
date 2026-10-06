import Foundation
import Observation
import SwiftUI
import FusionhaKit

/// The detail page's tabs (DetailTabs.tsx). `files` is "Versions" on a movie.
enum DetailTab: String, Hashable {
    case seasons, files, history, searches, collection
}

/// What the interactive-search sheet searches.
struct InteractiveTarget: Identifiable {
    let id = UUID()
    /// The versions offered as tabs (one, or every version for "All versions").
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
    var queue: [QueueItem] = [] {
        didSet {
            // A live queue row flips a version to Downloading / Upgrading.
            let active = activeQueueEditionIds
            if active != lastActiveQueue { lastActiveQueue = active; rebuildSummaries() }
        }
    }
    private var lastActiveQueue: Set<Int> = []

    /// The page scope. Per title: every open starts on all versions (0.4.140
    /// dropped the shared `fusionha:detail-scope` persistence).
    var scope: DetailScope = .all
    var tab: DetailTab = .seasons
    var oldestFirst: Set<Int> = []
    var toast: DetailToast?
    var flash: SearchFlash?
    var gradual: GradualJob?
    var refreshing = false
    var deleted = false

    /// Optimistic monitor flips while the PATCH is in flight.
    var seasonMonitorOverride: [Int: Bool] = [:]
    var editionMonitorOverride: [Int: Bool] = [:]
    var episodeMonitorOverride: [Int: Bool] = [:]
    /// The panel's per-version summaries, rebuilt once per load (never in `body`).
    private(set) var versionSummaries: [Int: VersionSummary] = [:]

    // Sheets
    var interactive: InteractiveTarget?
    var showingEdit = false
    var addPreset: AddEditionPreset?
    var showingDelete = false
    var seasonSheet: SeasonRef?
    /// The item actions rail's dialogs (see DetailStore+ItemActions.swift).
    var renameScope: RenameScope?
    var showingAliases = false
    var showingIssue = false
    var showingNumbering = false
    var checkingNumbering = false

    init(itemId: Int) {
        self.itemId = itemId
    }

    // MARK: Derived

    var effScope: DetailScope { detail?.effectiveScope(scope) ?? scope }
    var scopeEditionId: Int? { detail?.scopeEditionId(scope) }
    var scopedEditions: [DetailEdition] { detail?.scopedEditions(scope) ?? [] }
    /// The rail's `applies to …` hint.
    var actsOnLabel: String { detail?.appliesToLabel(scope) ?? "all versions" }
    /// The tabs' `showing …` echo.
    var showingLabel: String { detail?.showingLabel(scope) ?? "All versions" }
    /// The opened version row (from the RAW scope), nil for all versions.
    var focusedVersion: DetailEdition? { detail?.focusedVersion(scope) }

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

    func episodeMonitored(_ episode: Episode) -> Bool {
        episodeMonitorOverride[episode.id] ?? (episode.monitored != false)
    }

    func summary(_ edition: DetailEdition) -> VersionSummary? { versionSummaries[edition.id] }

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
            episodeMonitorOverride = [:]
            rebuildSummaries()
        } catch {
            if detail == nil { loadError = error.localizedDescription }
        }
    }

    /// Recomputes the per-version coverage once (also when the queue changes,
    /// since a live queue row turns a version's status to Downloading/Upgrading).
    func rebuildSummaries() {
        guard let detail else { versionSummaries = [:]; return }
        let now = Date()
        let active = activeQueueEditionIds
        var out: [Int: VersionSummary] = [:]
        for edition in detail.editions {
            out[edition.id] = VersionSummary(detail: detail, edition: edition, activeQueue: active, now: now)
        }
        versionSummaries = out
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
                let versions = Set(grabbed.compactMap(\.editionId)).count
                let n = max(versions, 1)
                show("Searching \(label) — grabbing \(n) version\(n == 1 ? "" : "s")", variant: .success,
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
                show(missingOnly ? "\(label): no missing episodes — nothing to search"
                                 : "\(label): all episodes meet the cutoff — nothing to upgrade", variant: .warning)
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

    /// Per-episode monitor toggle (`PATCH /api/v1/library/{id}/episodes/{eid}`).
    func setEpisodeMonitored(_ episode: Episode, seasonNumber: Int, _ on: Bool) async {
        guard let client else { return }
        let code = "S\(seasonNumber)·E\(String(format: "%02d", episode.episodeNumber))"
        episodeMonitorOverride[episode.id] = on
        do {
            try await client.setEpisodeMonitored(itemId: itemId, episodeId: episode.id, monitored: on)
            await reload()
        } catch {
            episodeMonitorOverride[episode.id] = nil
            show("Couldn't update \(code)", variant: .error)
        }
    }
}
