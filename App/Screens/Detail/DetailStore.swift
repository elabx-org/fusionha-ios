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

    // Sheets. They live here, not on the view, so a fold / unfold that moves
    // the title between the sheet and the column re-presents them
    // (`DetailChildSheets`). Opening one afresh clears its draft.
    var interactive: InteractiveTarget? { didSet { opened("search", oldValue?.id, interactive?.id) } }
    var showingEdit = false { didSet { opened("edit", oldValue, showingEdit) } }
    var addPreset: AddEditionPreset? { didSet { opened("add", oldValue?.id, addPreset?.id) } }
    var showingDelete = false { didSet { opened("delete", oldValue, showingDelete) } }
    var seasonSheet: SeasonRef?
    /// The episode sheet (EpisodeDetailDialog): Details / History / Search.
    var episodeSheet: EpisodeSheetTarget? { didSet { opened("episode", oldValue?.id, episodeSheet?.id) } }
    /// The item actions rail's dialogs (see DetailStore+ItemActions.swift).
    var renameScope: RenameScope? { didSet { opened("rename", oldValue?.id, renameScope?.id) } }
    var showingAliases = false { didSet { opened("aliases", oldValue, showingAliases) } }
    var showingIssue = false { didSet { opened("issue", oldValue, showingIssue) } }
    var showingNumbering = false {
        didSet {
            opened("numbering", oldValue, showingNumbering)
            if !showingNumbering { numberingSource = nil }
        }
    }
    /// The compare source the numbering sheet previews (an Edit pin), nil = the default.
    var numberingSource: String?
    /// The reviewed metadata-source switch, to this provider.
    var switchTarget: MetadataSwitchTarget? { didSet { opened("switch", oldValue?.id, switchTarget?.id) } }
    /// Manage files / Manage episodes, on the page scope or one version.
    var manageFiles: ManageFilesTarget? { didSet { opened("manage", oldValue?.id, manageFiles?.id) } }
    var checkingNumbering = false
    /// The movie's collection (`GET /api/v1/collections/{id}`), for the rail and the tab.
    var collection: CollectionDetail?
    var collectionFailed = false
    /// The Add-collection sheet, preselected to these films.
    var collectionAdd: CollectionAddTarget? { didSet { opened("collection", oldValue?.id, collectionAdd?.id) } }
    /// Who asked for this title (`GET /api/v1/requests/item/{id}`): the hero pill and the strip.
    var requestRows: [ItemRequestRow] = []
    /// Bumped by the hero's "Requested by" pill: the page scrolls to the strip.
    var revealRequests = 0

    /// What the child sheets had typed when their host went away (`retainsDraft`).
    @ObservationIgnored var drafts = DraftBag()
    /// The page's scroll offset, restored by the next host.
    @ObservationIgnored var scrollY: CGFloat = 0
    /// Whether a host has shown this store yet: a later host is a fold / unfold.
    @ObservationIgnored var hosted = false

    init(itemId: Int) {
        self.itemId = itemId
    }

    private func opened<ID: Equatable>(_ sheet: String, _ old: ID?, _ new: ID?) {
        if DraftBag.isFreshOpen(from: old, to: new) { drafts.clear(sheet: sheet) }
    }

    private func opened(_ sheet: String, _ old: Bool, _ new: Bool) {
        if new && !old { drafts.clear(sheet: sheet) }
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
        await loadCollection()
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
}
