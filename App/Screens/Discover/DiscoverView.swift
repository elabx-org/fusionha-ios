import SwiftUI
import FusionhaKit

enum DiscoverTab: String, Hashable {
    case browse, requests, issues
}

/// A title the Preview page shows (`/preview/{kind}/{tmdbId}`).
struct PreviewRoute: Identifiable, Hashable {
    let kind: PreviewKind
    let tmdbId: Int
    var id: String { "\(kind.rawValue)-\(tmdbId)" }

    init(kind: PreviewKind, tmdbId: Int) {
        self.kind = kind
        self.tmdbId = tmdbId
    }

    init(_ result: MediaSearchResult) {
        self.init(kind: result.previewKind, tmdbId: result.tmdbId)
    }
}

/// The Discover "Add as" provider override. Session memory only, like the web.
@MainActor
@Observable
final class DiscoverSession {
    static let shared = DiscoverSession()
    /// `auto` (the Settings default), `tmdb`, `tvdb` or `hybrid`.
    var providerOverride = "auto"
    /// `GET /api/v1/settings` → `metadata_provider`.
    var globalProvider = "tmdb"
    /// `GET /api/v1/settings` → `animations_enabled` (the web's app-wide motion switch).
    var animationsEnabled = true

    var effectiveProvider: String { providerOverride == "auto" ? globalProvider : providerOverride }
}

/// Shared state for one Discover page: request statuses for the card chips,
/// the pending badge and the sheets the cards open.
@MainActor
@Observable
final class DiscoverStore {
    var requests: [MediaRequest] = []
    var requestsLoaded = false
    var requestsFailed = false
    var pendingCount = 0
    var preview: PreviewRoute?
    var requestPick: MediaSearchResult?
    var trailer: TrailerResult?
    var collection: CollectionSummary?
    /// Bumped to refetch the collections rail after an ignore/add.
    var collectionsVersion = 0
    /// Bumped to refetch request lists after a decision.
    var requestsVersion = 0 {
        didSet { demand.reset() }
    }
    /// Per-title demand for a requester's cards (Me too, Watch).
    let demand = DiscoverDemand()

    /// The highest-priority request status per TMDB id (pending > approved > …).
    var statusByTmdb: [Int: String] {
        var map: [Int: String] = [:]
        for request in requests {
            if let current = map[request.tmdbId],
               MediaRequest.priority(current) >= MediaRequest.priority(request.status) { continue }
            map[request.tmdbId] = request.status
        }
        return map
    }

    func loadRequests(_ client: APIClient?, approver: Bool) async {
        guard let client else { return }
        do {
            requests = try await client.requests(status: nil)
            requestsFailed = false
        } catch {
            requestsFailed = true
        }
        requestsLoaded = true
        if approver {
            pendingCount = (try? await client.requests(status: "pending").count) ?? requests.filter { $0.status == "pending" }.count
        } else {
            pendingCount = 0
        }
    }
}

/// The web's Discover page (`routes/Discover.tsx`, mobile layout): title, kind
/// control, the search field (or Add sheet button), the "Add as" provider
/// control, Browse · Requests · Issues tabs, then the rails.
/// Requesters reach the same page from "My requests" with the Requests tab on.
struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @State private var store = DiscoverStore()
    @State private var kind: SearchKind = .movie
    @State private var tab: DiscoverTab
    @State private var query = ""
    @State private var scrollTarget: String?

    init(initialTab: DiscoverTab = .browse) {
        _tab = State(initialValue: initialTab)
    }

    private var me: Me? { model.me }
    private var canAdd: Bool { me.map { $0.hasCapability("add") } ?? !model.requestScoped }
    private var canRequest: Bool { me?.hasCapability("request") ?? false }
    private var canApprove: Bool { me?.hasPermission("requests.approve") ?? false }
    private var canManageIssues: Bool { me?.hasPermission("issues.manage") ?? false }
    private var requestorSearching: Bool {
        !canAdd && canRequest && !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        @Bindable var store = store
        Screen(showsAdd: true) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        header
                        tabs
                        content
                    }
                    // Plex-app rhythm on phones: 16pt side margins, like Library.
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 90)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: scrollTarget) {
                    guard let target = scrollTarget else { return }
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .environment(store)
        .discoverToastOverlay()
        .sheet(item: $store.preview) { route in
            PreviewSheet(route: route, onOpenLibrary: { id in handOff { model.open(id) } })
        }
        .sheet(item: $store.requestPick) { pick in
            RequestModal(pick: pick) { store.requestsVersion += 1 }
        }
        .sheet(item: $store.trailer) { trailer in
            TrailerSheet(title: trailer.title, key: trailer.trailerKey)
        }
        .sheet(item: $store.collection) { collection in
            AddCollectionSheet(summary: collection) { store.collectionsVersion += 1 }
        }
        .task(id: "\(me?.id ?? -1)|\(store.requestsVersion)") {
            await store.loadRequests(model.client, approver: canApprove)
        }
        .task {
            if let settings = try? await model.client?.discoverSettings() {
                DiscoverSession.shared.globalProvider = settings.metadataProvider ?? "tmdb"
                DiscoverSession.shared.animationsEnabled = settings.animationsEnabled ?? true
            }
        }
        // In-library cards route by the library list (the web's `idByTmdb`).
        .task { if !model.libraryLoaded && !model.requestScoped { await model.loadLibrary() } }
        .onChange(of: canManageIssues) { if tab == .issues && !canManageIssues { tab = .browse } }
        .onChange(of: model.pendingDiscoverTab, initial: true) {
            // `fusionha://discover/requests` from the widget.
            guard let pending = model.pendingDiscoverTab else { return }
            tab = pending
            model.pendingDiscoverTab = nil
        }
        #if DEBUG
        .onAppear(perform: applyScreenshotHooks)
        .onChange(of: model.me?.id) { applyScreenshotHooks() }
        #endif
    }

    /// Closes the Preview sheet, then opens something on the app shell.
    private func handOff(_ action: @escaping @MainActor () -> Void) {
        store.preview = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            action()
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShellTitleRow("Discover")
                .padding(.bottom, 14)
            DiscoverSegmented(options: SearchKind.allCases.map { ($0, $0.title) }, selection: $kind, size: .md)
                .padding(.bottom, 14)
            if canAdd {
                Button { model.openAdd(nil, providerOverride: DiscoverSession.shared.providerOverride) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold))
                        Text("Search TMDB to add movies, series & anime…")
                            .font(.system(size: 14.5))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Theme.mut)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: 560, minHeight: 44, alignment: .leading)
                    .background(DiscoverPalette.well, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search TMDB to add movies, series and anime")
                DiscoverAddAsControl()
                    .padding(.top, 8)
            } else if canRequest {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.mut)
                    TextField("", text: $query, prompt: Text("Search movies & shows to request…").foregroundStyle(Theme.mut))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.txt)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.mut)
                                .frame(width: 24, height: 24)
                                .background(Theme.txt.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear")
                    }
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: 560, minHeight: 44)
                .background(DiscoverPalette.well, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.line))
            }
        }
        .padding(.bottom, 22)
    }

    private var tabs: some View {
        var options: [(DiscoverTab, String, Int?)] = [(.browse, "Browse", nil),
                                                      (.requests, "Requests", canApprove ? store.pendingCount : nil)]
        if canManageIssues { options.append((.issues, "Issues", nil)) }
        return DiscoverTabs(options: options, selection: $tab)
            .padding(.top, 4)
            .padding(.bottom, 22)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .requests:
            RequestsPanel(approver: canApprove)
        case .issues:
            IssuesPanel()
        case .browse:
            if requestorSearching {
                RequestorSearchResults(term: query.trimmingCharacters(in: .whitespaces), kind: kind,
                                       canAdd: canAdd, canRequest: canRequest)
            } else {
                rails
            }
        }
    }

    @ViewBuilder
    private var rails: some View {
        TrendingRail(kind: kind, canAdd: canAdd, canRequest: canRequest)
        TrailerRail(kind: kind, canAdd: canAdd)
            .id("trailers")
        PopularRail(kind: kind, canAdd: canAdd, canRequest: canRequest)
        upcomingRail
            .id("upcoming")
        DiscoverRail(title: "Top Rated", key: "top_rated|\(kind.rawValue)", trending: false,
                     canAdd: canAdd, canRequest: canRequest) {
            Image(systemName: "star").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.miss)
        } load: { client in
            try await client.discover(kind: kind, list: .topRated, window: nil, monetization: nil)
        }
        CollectionsRail()
            .id("collections")
        DiscoverFiltersPanel(kind: kind, canAdd: canAdd, canRequest: canRequest)
            .id("filters")
    }

    private var upcomingRail: some View {
        let railKind = kind
        let title: String
        let icon: String
        switch railKind {
        case .movie: title = "Upcoming"; icon = "calendar"
        case .series, .anime: title = "On The Air"; icon = "tv"
        case .all: title = "Upcoming & On The Air"; icon = "calendar"
        }
        return DiscoverRail(title: title, key: "upcoming|\(railKind.rawValue)", trending: false,
                            canAdd: canAdd, canRequest: canRequest) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.i2)
        } load: { client in
            switch railKind {
            case .movie:
                return try await client.discover(kind: .movie, list: .upcoming, window: nil, monetization: nil)
            case .series, .anime:
                return try await client.discover(kind: railKind, list: .onTheAir, window: nil, monetization: nil)
            case .all:
                async let movies = client.discover(kind: .movie, list: .upcoming, window: nil, monetization: nil)
                async let series = client.discover(kind: .series, list: .onTheAir, window: nil, monetization: nil)
                let m = try await movies
                let s = try await series
                return interleave(m, s)
            }
        }
    }

    #if DEBUG
    /// CI screenshots: open a tab, a preview or the request modal at launch.
    private func applyScreenshotHooks() {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["FUSIONHA_SCREENSHOT_REQUESTOR_TAB"], model.requestScoped {
            if raw == "you" { model.tab = .you } else if raw == "requests" { model.tab = .requests }
        }
        guard model.tab == .discover else { return }
        if let raw = env["FUSIONHA_SCREENSHOT_DISCOVER_TAB"], let value = DiscoverTab(rawValue: raw) { tab = value }
        if let raw = env["FUSIONHA_SCREENSHOT_DISCOVER_KIND"], let value = SearchKind(rawValue: raw) { kind = value }
        if let raw = env["FUSIONHA_SCREENSHOT_DISCOVER_SCROLL"] {
            Task {
                try? await Task.sleep(for: .seconds(2))
                scrollTarget = raw
                // Lazy rails above the target change height as they load; aim again.
                try? await Task.sleep(for: .seconds(2))
                scrollTarget = nil
                try? await Task.sleep(for: .milliseconds(100))
                scrollTarget = raw
            }
        }
        if store.preview == nil, let raw = env["FUSIONHA_SCREENSHOT_PREVIEW"] {
            let parts = raw.split(separator: "/")
            if parts.count == 2, let kind = PreviewKind(rawValue: String(parts[0])), let id = Int(parts[1]) {
                store.preview = PreviewRoute(kind: kind, tmdbId: id)
            }
        }
        if store.requestPick == nil, let raw = env["FUSIONHA_SCREENSHOT_REQUEST"] {
            let parts = raw.split(separator: "/")
            if parts.count == 3, let id = Int(parts[1]) {
                store.requestPick = MediaSearchResult.make(
                    tmdbId: id, title: String(parts[2]).replacingOccurrences(of: "_", with: " "), year: nil,
                    kind: parts[0] == "movie" ? .movie : .series, isAnime: false, overview: nil, inLibrary: false,
                    libraryItemId: nil, posterUrl: nil, backdropUrl: nil, date: nil, voteAverage: nil)
            }
        }
    }
    #endif
}

/// Round-robin two lists (the web's `kind=all` merge).
func interleave<T>(_ a: [T], _ b: [T]) -> [T] {
    var out: [T] = []
    out.reserveCapacity(a.count + b.count)
    for i in 0..<max(a.count, b.count) {
        if i < a.count { out.append(a[i]) }
        if i < b.count { out.append(b[i]) }
    }
    return out
}

/// Requester "My requests" tab: the Discover page with the Requests tab on.
struct RequestsView: View {
    var body: some View {
        DiscoverView(initialTab: .requests)
    }
}
