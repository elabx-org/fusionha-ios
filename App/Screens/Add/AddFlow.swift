import SwiftUI
import FusionhaKit

/// A pick on the Find step: a TMDB-identified title, or a TVDB-only series.
enum AddPick: Hashable {
    case tmdb(MediaSearchResult)
    case tvdb(TvdbSearchResult)

    var title: String {
        switch self {
        case .tmdb(let r): return r.title
        case .tvdb(let r): return r.title
        }
    }

    var year: Int? {
        switch self {
        case .tmdb(let r): return r.year
        case .tvdb(let r): return r.year
        }
    }

    /// A TVDB-only pick is always a series (TVDB search is series-only).
    var kind: MediaKind {
        switch self {
        case .tmdb(let r): return r.kind
        case .tvdb: return .series
        }
    }

    var tmdbAnime: Bool {
        if case .tmdb(let r) = self { return r.isAnime }
        return false
    }

    /// `tmdb:<kind>:<id>` / `tvdb:<id>`: the pick identity.
    var key: String {
        switch self {
        case .tmdb(let r): return "tmdb:\(r.kind.rawValue):\(r.tmdbId)"
        case .tvdb(let r): return "tvdb:\(r.tvdbId)"
        }
    }

    var posterUrl: String? {
        switch self {
        case .tmdb(let r): return r.posterUrl
        case .tvdb(let r): return r.imageUrl
        }
    }

    var backdropUrl: String? {
        if case .tmdb(let r) = self { return r.backdropUrl }
        return nil
    }

    var tmdbResult: MediaSearchResult? {
        if case .tmdb(let r) = self { return r }
        return nil
    }
}

/// One tier's form state before it becomes a `VersionCreate` (`TierState`).
struct AddTierState: Equatable {
    /// On → this version is added and monitored; off → not added at all.
    var on: Bool
    var rootId: Int
    var profileId: Int
    /// This tier's series monitor level; differs from the master only as an override.
    var monitor: String
}

/// A failed add, typed for where it shows: a 409 folder collision on the Folder
/// row, anything else in the footer.
struct AddFlowError: Equatable {
    let folder: Bool
    let message: String
}

/// Every restorable field (the "Use last settings" undo snapshot).
private struct AddSnapshot {
    let versions: [QualityTier: AddTierState]?
    let editions: [QualityTier: String]
    let monitor: String
    let seasonFrom: SeasonFrom
    let seriesType: String
    let provider: String
    let folderName: String
    let minAvail: String
    let minAvailTouched: Bool
    let searchNow: Bool
}

/// The configure step's state for one pick: a port of the web's `useAddFlow`.
/// The Add sheet keeps one alive per pick, so the "View details" round trip
/// (a push inside the sheet) comes back to exactly what was there.
@MainActor
@Observable
final class AddFlow {
    static let tiers: [QualityTier] = [.hd, .uhd]

    let pick: AddPick
    /// Discover's session "Add as" override (`auto` when none).
    let providerOverride: String
    private let client: APIClient?

    // Config the seed reads.
    private(set) var roots: [RootFolder]?
    private(set) var profiles: [QualityProfileSummary]?
    private var addDefaults: [AddDefaultSlot]?
    private(set) var settings: AddSettings?
    private(set) var editionNames: [String] = []

    // The decisions.
    private(set) var versions: [QualityTier: AddTierState]?
    private(set) var editions: [QualityTier: String] = [:]
    private(set) var monitor = "all"
    private(set) var seasonFrom: SeasonFrom = [:]
    var seriesType: String
    var provider: String
    private(set) var folderName: String
    private(set) var minAvail = "announced"
    private var minAvailTouched = false
    var searchNow = true

    // The manual 4K check.
    enum FourKStatus { case idle, checking, done, error }
    private(set) var fourKStatus: FourKStatus = .idle
    private(set) var fourKResult: FourKAvailability?
    /// The last indexer count seen, so a re-check says "Searching 13 indexers…".
    private(set) var fourKLastCount: Int?

    // Preview + last settings.
    private(set) var preview: AddPreview?
    private(set) var previewLoading = true
    private(set) var last: LastAdded?
    private var beforeLast: AddSnapshot?

    private(set) var isAdding = false
    private(set) var error: AddFlowError?

    init(pick: AddPick, client: APIClient?, providerOverride: String?) {
        self.pick = pick
        self.client = client
        self.providerOverride = providerOverride ?? "auto"
        provider = providerOverride ?? "auto"
        seriesType = pick.tmdbAnime ? "anime" : "standard"
        folderName = TitleYear.titleWithYear(pick.title, pick.year)
    }

    // MARK: Derived

    var kind: MediaKind { pick.kind }
    var isSeries: Bool { kind == .series }
    var title: String { pick.title }
    var year: Int? { pick.year }
    var isTvdb: Bool { if case .tvdb = pick { return true } else { return false } }

    /// Anime when TMDB flagged it OR Series type = Anime.
    var effectiveAnime: Bool {
        switch pick {
        case .tmdb(let r): return r.isAnime || (r.kind == .series && seriesType == "anime")
        case .tvdb: return seriesType == "anime"
        }
    }

    /// TMDB itself flags the pick as anime (the "Detected: anime" tag).
    var detectedAnime: Bool { pick.tmdbAnime }

    var ready: Bool { versions != nil }

    /// `profilesForItem`: kindless profiles plus the title's kind (and anime).
    static func profilesFor(_ profiles: [QualityProfileSummary], kind: MediaKind, anime: Bool) -> [QualityProfileSummary] {
        let kinds: Set<String> = anime ? ["anime", kind.rawValue] : [kind.rawValue]
        return profiles.filter { $0.mediaKind == nil || kinds.contains($0.mediaKind ?? "") }
    }

    var profileOptions: [QualityProfileSummary] {
        Self.profilesFor(profiles ?? [], kind: kind, anime: effectiveAnime)
    }

    var onTiers: [QualityTier] { versions.map { v in Self.tiers.filter { v[$0]?.on == true } } ?? [] }

    /// The preview's seasons, in season order (series only).
    var seasons: [SeasonCounts]? {
        guard isSeries, let list = preview?.seasons else { return nil }
        return list.sorted { $0.seasonNumber < $1.seasonNumber }.map {
            SeasonCounts(seasonNumber: $0.seasonNumber, episodeCount: $0.episodeCount,
                         airedCount: $0.airedCount, recentCount: $0.recentCount)
        }
    }

    var hasCustomSeasons: Bool { !seasonFrom.isEmpty }

    var derivedFolder: String { TitleYear.titleWithYear(title, year) }
    private var trimmedFolder: String { folderName.trimmingCharacters(in: .whitespaces) }
    var folderEdited: Bool { !trimmedFolder.isEmpty && trimmedFolder != derivedFolder }
    /// The folder every version lands in (the field, else the default).
    var shownFolder: String { trimmedFolder.isEmpty ? derivedFolder : trimmedFolder }

    /// The global default "Automatic" resolves to (Settings › Metadata).
    var defaultProvider: String { settings?.metadataProvider ?? "tmdb" }
    private var chosenProvider: String { provider != "auto" ? provider : defaultProvider }
    /// A TVDB-only pick can only be built by TVDB or Hybrid.
    var effectiveProvider: String {
        isTvdb ? Self.tvdbPickProvider(chosenProvider) : chosenProvider
    }

    static func tvdbPickProvider(_ choice: String) -> String { choice == "hybrid" ? "hybrid" : "tvdb" }

    /// The provider choice is offered for TMDB-picked series only.
    var showProviderChoice: Bool { !isTvdb && isSeries }

    /// Every id known for the pick ("Identified as"); the preview fills TVDB/IMDb.
    var ids: (tmdb: Int?, tvdb: Int?, imdb: String?) {
        switch pick {
        case .tmdb(let r):
            return (r.tmdbId, preview?.tvdbId, preview?.imdbId)
        case .tvdb(let r):
            return (r.tmdbId ?? preview?.tmdbId, preview?.tvdbId ?? r.tvdbId, preview?.imdbId ?? r.imdbId)
        }
    }

    // MARK: Load + seed

    private var started = false

    /// Loads the config, seeds the versions and fetches the preview, once — in
    /// its own task, so a push over the sheet never cancels it half way.
    func start() {
        guard !started else { return }
        started = true
        Task { await load() }
    }

    private func load() async {
        guard let client else { previewLoading = false; return }
        async let rootsCall = client.rootFolders()
        async let profilesCall = client.qualityProfileSummaries()
        async let defaultsCall = client.addDefaults()
        async let settingsCall = client.addSettings()
        async let editionsCall = client.editionDefinitions()
        async let previewCall = Self.fetchPreview(pick, client)
        settings = try? await settingsCall
        if !minAvailTouched, let configured = settings?.defaultMovieMinimumAvailability, !configured.isEmpty {
            minAvail = configured
        }
        roots = (try? await rootsCall) ?? []
        profiles = (try? await profilesCall) ?? []
        addDefaults = (try? await defaultsCall) ?? []
        editionNames = ((try? await editionsCall) ?? []).filter { $0.enabled != false }.map(\.name)
        seed()
        preview = await previewCall
        previewLoading = false
    }

    private nonisolated static func fetchPreview(_ pick: AddPick, _ client: APIClient) async -> AddPreview? {
        switch pick {
        case .tmdb(let r): return try? await client.addPreview(kind: r.previewKind, tmdbId: r.tmdbId)
        case .tvdb(let r): return try? await client.tvdbPreview(tvdbId: r.tvdbId)
        }
    }

    /// "Use last settings": the latest add of the same kind (anime or not).
    func loadLast() async {
        guard let client else { return }
        last = (try? await client.lastAdded(kind: isSeries ? .series : .movie, anime: effectiveAnime)) ?? nil
    }

    /// `makeDefaults`: HD on, 4K off; each tier prefers the configured default
    /// slot, else the path/name heuristic. Anime draws from the Anime slot.
    private func seed() {
        guard versions == nil, let roots, let profiles else { return }
        let animeHint = isTvdb ? seriesType == "anime" : pick.tmdbAnime
        let resolvedKind = animeHint ? "anime" : kind.rawValue
        let list = Self.profilesFor(profiles, kind: kind, anime: animeHint)
        var out: [QualityTier: AddTierState] = [:]
        for tier in Self.tiers {
            let slot = addDefaults?.first { $0.profileKind == resolvedKind && $0.tier == tier }
            out[tier] = AddTierState(
                on: tier == .hd,
                rootId: slot?.rootFolderId ?? Self.defaultRootId(tier, kind: kind, roots: roots),
                profileId: slot?.qualityProfileId ?? Self.defaultProfileId(tier, resolvedKind: resolvedKind, profiles: list),
                monitor: "all")
        }
        versions = out
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func defaultRootId(_ tier: QualityTier, kind: MediaKind, roots: [RootFolder]) -> Int {
        let wants4k = tier == .uhd
        let kindMatch = { (r: RootFolder) in
            kind == .series ? matches(r.path, "tv|anime|series|show") : matches(r.path, "movie|film")
        }
        let tierMatch = { (r: RootFolder) in matches(r.path, "4k|2160|uhd") == wants4k }
        let chosen = roots.first { kindMatch($0) && tierMatch($0) } ?? roots.first(where: kindMatch)
            ?? roots.first(where: tierMatch) ?? roots.first
        return chosen?.id ?? 0
    }

    static func defaultProfileId(_ tier: QualityTier, resolvedKind: String, profiles: [QualityProfileSummary]) -> Int {
        let wants4k = tier == .uhd
        let is4k = { (p: QualityProfileSummary) in
            matches(p.name, "4k|2160|uhd|ultra") || (p.allowedQualities ?? []).contains { matches($0, "2160|4k|uhd") }
        }
        let anime = resolvedKind == "anime" ? profiles.first { $0.mediaKind == "anime" && is4k($0) == wants4k } : nil
        let chosen = anime ?? profiles.first { is4k($0) == wants4k } ?? profiles.first
        return chosen?.id ?? 0
    }

    // MARK: Edits

    func patchTier(_ tier: QualityTier, rootId: Int? = nil, profileId: Int? = nil) {
        guard var state = versions?[tier] else { return }
        if let rootId { state.rootId = rootId }
        if let profileId { state.profileId = profileId }
        versions?[tier] = state
    }

    /// Turn a version on/off. Fewer than two left on collapses any per-version
    /// override into the master, so what is posted is what is shown.
    func setTierOn(_ tier: QualityTier, _ on: Bool) {
        guard var next = versions else { return }
        next[tier]?.on = on
        let stillOn = Self.tiers.filter { next[$0]?.on == true }
        if stillOn.count < 2 {
            let mode = stillOn.count == 1 ? (next[stillOn[0]]?.monitor ?? monitor) : monitor
            monitor = mode
            for t in Self.tiers { next[t]?.monitor = mode }
        }
        versions = next
    }

    func setEdition(_ tier: QualityTier, _ edition: String?) {
        editions[tier] = AddVocab.isStandardEdition(edition) ? nil : edition
    }

    /// Every version's row follows `mode` (no per-version overrides left).
    private func syncMonitor(_ mode: String) {
        monitor = mode
        guard var next = versions else { return }
        for t in Self.tiers { next[t]?.monitor = mode }
        versions = next
    }

    /// The master monitor (a regular chip): also clears any custom seasons.
    func setMasterMonitor(_ mode: String) {
        seasonFrom = [:]
        syncMonitor(mode)
    }

    func setTierMonitor(_ tier: QualityTier, _ mode: String) {
        versions?[tier]?.monitor = mode
    }

    func clearSeasonFrom() { seasonFrom = [:] }

    /// One season's slider choice. Custom always builds on All.
    func setSeasonStart(_ seasonNumber: Int, _ fromEpisode: Int?) {
        var base = seasonFrom
        if base.isEmpty, let seasons { base = SeasonSlider.materialise(seasons, mode: monitor) }
        base.updateValue(fromEpisode, forKey: seasonNumber)
        seasonFrom = base
        syncMonitor("all")
    }

    /// Tapping a season's name: whole season on, or off when it is fully lit.
    func toggleSeason(_ seasonNumber: Int) {
        guard let seasons, let idx = seasons.firstIndex(where: { $0.seasonNumber == seasonNumber }) else { return }
        let effective = SeasonSlider.apply(seasons, MonitorPreview.compute(seasons, mode: monitor), seasonFrom)
        let lit = idx < effective.perSeason.count ? effective.perSeason[idx].lit.count : 0
        setSeasonStart(seasonNumber, SeasonSlider.toggled(litCount: lit, episodeCount: seasons[idx].episodeCount))
    }

    func setMinAvail(_ value: String) {
        minAvailTouched = true
        minAvail = value
    }

    func setFolderName(_ value: String) {
        folderName = value
        if error?.folder == true { error = nil }
    }

    // MARK: Use last settings

    var lastAvailable: Bool { last != nil && versions != nil }
    var lastApplied: Bool { beforeLast != nil }
    var lastSummary: String { last.map { AddVocab.lastAddedSummary($0, isSeries: isSeries) } ?? "" }

    private func snapshot() -> AddSnapshot {
        AddSnapshot(versions: versions, editions: editions, monitor: monitor, seasonFrom: seasonFrom,
                    seriesType: seriesType, provider: provider, folderName: folderName, minAvail: minAvail,
                    minAvailTouched: minAvailTouched, searchNow: searchNow)
    }

    private func restore(_ s: AddSnapshot) {
        versions = s.versions
        editions = s.editions
        monitor = s.monitor
        seasonFrom = s.seasonFrom
        seriesType = s.seriesType
        provider = s.provider
        folderName = s.folderName
        minAvail = s.minAvail
        minAvailTouched = s.minAvailTouched
        searchNow = s.searchNow
    }

    /// Which tiers are on with their folder + profile (when still offered), the
    /// master monitor (series), minimum availability (movies) and series type.
    /// Never the folder name, editions or season rules.
    func applyLast() {
        guard let last, var next = versions else { return }
        beforeLast = snapshot()
        let mode = isSeries ? (last.monitor ?? monitor) : monitor
        for tier in Self.tiers {
            guard var cur = next[tier] else { continue }
            let src = last.versions.first { $0.tier == tier }
            cur.on = src != nil
            cur.monitor = mode
            if let id = src?.rootFolderId, (roots ?? []).contains(where: { $0.id == id }) { cur.rootId = id }
            if let id = src?.qualityProfileId, (profiles ?? []).contains(where: { $0.id == id }) { cur.profileId = id }
            next[tier] = cur
        }
        versions = next
        if isSeries {
            monitor = mode
            seasonFrom = [:]
            if let type = last.seriesType, !type.isEmpty { seriesType = type }
        } else if let min = last.minimumAvailability, !min.isEmpty {
            setMinAvail(min)
        }
    }

    func undoLast() {
        guard let beforeLast else { return }
        restore(beforeLast)
        self.beforeLast = nil
    }

    // MARK: 4K check (manual)

    func checkFourK() async {
        guard let client else { return }
        let body: AddFourKCheckBody
        switch pick {
        case .tmdb(let r):
            body = AddFourKCheckBody(tmdbId: r.tmdbId, tvdbId: nil, title: r.title, kind: r.kind == .movie ? .movie : .series,
                                     year: r.year, isAnime: effectiveAnime)
        case .tvdb(let r):
            body = AddFourKCheckBody(tmdbId: nil, tvdbId: r.tvdbId, title: r.title, kind: .series, year: r.year,
                                     isAnime: effectiveAnime)
        }
        fourKStatus = .checking
        fourKResult = nil
        do {
            let result = try await client.addCheckFourK(body)
            if result.dispatched == true, let n = result.queriedIndexers { fourKLastCount = n }
            fourKResult = result
            fourKStatus = .done
        } catch {
            fourKStatus = .error
        }
    }

    // MARK: Monitor counts + timeline

    /// The master's (or a mode's) episode count for the sentence; nil without seasons.
    func monitorSummary(_ mode: String, withCustom: Bool) -> AddSentence.Monitor? {
        guard let seasons, !seasons.isEmpty else { return nil }
        let base = MonitorPreview.compute(seasons, mode: mode)
        let p = withCustom ? SeasonSlider.apply(seasons, base, seasonFrom) : base
        return AddSentence.Monitor(mode: mode, count: p.count, exact: p.exact)
    }

    func timeline(today: Date = Date()) -> ReleaseTimelineModel {
        ReleaseTimelineModel.build(preview?.timelineDates ?? TimelineDates(), today: today)
    }

    /// Nothing is out yet, so a 4K miss means "searched on release".
    func notOutYet(_ timeline: ReleaseTimelineModel) -> Bool {
        if isSeries {
            guard let seasons, !seasons.isEmpty else { return false }
            return seasons.allSatisfy { $0.airedCount == 0 }
        }
        return preview?.status != "Released" && !timeline.releasedOut()
    }

    // MARK: Payload + submit

    var chosenVersions: [AddVersionBody] {
        guard let versions else { return [] }
        let folder = folderEdited ? trimmedFolder : nil
        return onTiers.compactMap { tier in
            guard let state = versions[tier] else { return nil }
            let edition = editions[tier]
            return AddVersionBody(tier: tier, edition: AddVocab.isStandardEdition(edition) ? nil : edition,
                                  rootFolderId: state.rootId, qualityProfileId: state.profileId,
                                  monitor: isSeries && state.monitor != monitor ? state.monitor : nil,
                                  folderName: folder)
        }
    }

    var canSubmit: Bool { !chosenVersions.isEmpty && !isAdding }

    /// The `POST /api/v1/library` body, or nil when nothing can be added yet.
    func payload() -> AddTitleBody? {
        let chosen = chosenVersions
        if chosen.isEmpty { return nil }
        // Per-season starts need one shared level, and never ride an anime add.
        let shared = chosen.allSatisfy { $0.monitor == nil }
        let custom = isSeries && shared && !effectiveAnime ? SeasonSlider.payload(seasonFrom) : nil
        switch pick {
        case .tmdb(let r):
            return AddTitleBody(title: r.title, kind: r.kind, year: r.year, tmdbId: r.tmdbId, tvdbId: nil,
                                isAnime: effectiveAnime, versions: chosen, searchNow: searchNow,
                                monitor: isSeries ? monitor : "all", minimumAvailability: isSeries ? nil : minAvail,
                                seriesType: isSeries ? seriesType : nil,
                                metadataProvider: isSeries && provider != "auto" ? provider : nil,
                                seasonMonitorFrom: custom)
        case .tvdb(let r):
            return AddTitleBody(title: r.title, kind: .series, year: r.year, tmdbId: nil, tvdbId: r.tvdbId,
                                isAnime: effectiveAnime, versions: chosen, searchNow: searchNow, monitor: monitor,
                                minimumAvailability: nil, seriesType: seriesType,
                                metadataProvider: Self.tvdbPickProvider(chosenProvider), seasonMonitorFrom: custom)
        }
    }

    /// Fire the add. A failure comes back nil, with `error` set.
    func submit() async -> AddedTitle? {
        guard let body = payload(), !isAdding, let client else { return nil }
        error = nil
        isAdding = true
        defer { isAdding = false }
        do {
            return try await client.addTitle(body)
        } catch {
            let api = error as? APIError
            let message = api?.serverDetail ?? "Could not add title"
            let folder = api?.status == 409 && message.range(of: "folder", options: .caseInsensitive) != nil
            self.error = AddFlowError(folder: folder, message: message)
            return nil
        }
    }

    func clearError() { error = nil }
}
