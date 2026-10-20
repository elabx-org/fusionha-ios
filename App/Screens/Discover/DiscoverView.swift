import SwiftUI
import FusionhaKit

enum DiscoverTab: String, Hashable {
    case browse, requests, issues
}

/// The web's Discover page (`routes/Discover.tsx`, mobile layout): the title
/// and Add in the system bar (D1), the kind control, the search field (or Add sheet button), the "Add as" provider
/// control, Browse · Requests · Issues tabs, then the rails.
/// Requesters reach the same page from "My requests" with the Requests tab on.
struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    @State private var store = DiscoverStore()
    @State private var kind: SearchKind = .movie
    @State private var tab: DiscoverTab
    @State private var query = ""
    @State private var scrollTarget: String?
    /// The bar's title: "Discover", or "My requests" for a requester's tab.
    private let title: String

    init(initialTab: DiscoverTab = .browse, title: String = "Discover") {
        _tab = State(initialValue: initialTab)
        self.title = title
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
                        tabs
                        content
                    }
                    // Plex-app rhythm on phones: 16pt side margins, like Library.
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, Theme.pageBottom)
                }
                .scrollDismissesKeyboard(.interactively)
                // Wide Requests panes scroll on their own: no page scroll around them (D2a).
                .requestsWidePageScroll()
                .onChange(of: scrollTarget) {
                    guard let target = scrollTarget else { return }
                    proxy.scrollTo(target, anchor: .top)
                }
                .onChange(of: store.scrollTo) {
                    guard let target = store.scrollTo else { return }
                    withAnimation(.snappy) { proxy.scrollTo(target, anchor: .top) }
                    store.scrollTo = nil
                }
                .onChange(of: store.scrollReveal) {
                    guard let target = store.scrollReveal else { return }
                    proxy.scrollTo(target)
                    store.scrollReveal = nil
                }
            }
        }
        // Rails, Browse's controls and the filter fields follow the page's own width.
        .publishesPaneSize()
        .shellPage(title)
        .toolbar { AddTitleToolbarItem(model: model) }
        .environment(store)
        .discoverToastOverlay()
        .sheet(item: $store.preview) { route in
            PreviewSheet(route: route, onOpenLibrary: { id in handOff { model.open(id) } })
        }
        .sheet(item: $store.requestPick) { pick in
            NavigationStack { RequestModal(pick: pick) { store.requestsVersion += 1 } }
        }
        .sheet(item: $store.trailer) { trailer in
            TrailerSheet(title: trailer.title, key: trailer.trailerKey)
        }
        .sheet(item: $store.collection) { collection in
            AddCollectionSheet(summary: collection) { store.collectionsVersion += 1 }
        }
        .task(id: "\(me?.id ?? -1)|\(store.requestsVersion)") {
            await store.loadRequests(model.client, approver: canApprove, issues: canManageIssues)
        }
        .task {
            if let settings = try? await model.client?.discoverSettings() {
                DiscoverSession.shared.globalProvider = settings.metadataProvider ?? "tmdb"
                DiscoverSession.shared.animationsEnabled = settings.animationsEnabled ?? true
                // Only an explicit `false` counts as "no key"; a requester can't
                // read settings and learns it from a rail's 409 instead.
                if let configured = settings.tmdbConfigured { store.tmdbMissing = !configured }
            }
        }
        // A decision moves the Requests badge now, not on the next 30 s poll.
        .onChange(of: store.requestsVersion) { Task { await model.refreshShell() } }
        // In-library cards route by the library list (the web's `idByTmdb`).
        .task { if !model.libraryLoaded && !model.requestScoped { await model.loadLibrary() } }
        // Issues lives in the Requests menu now (Proposal 2): the old tab and
        // `?tab=issues` open Requests on Issues.
        .onChange(of: tab, initial: true) { _, now in
            guard now == .issues else { return }
            store.requestsPane = .issues
            tab = .requests
        }
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

    private var tabs: some View {
        // `needs_you` from the shell's 30 s poll: the same figure as the nav badge.
        let badge = model.requestsBadge
        let options: [(DiscoverTab, String, Int?)] = [(.browse, "Browse", nil), (.requests, "Requests", badge)]
        return DiscoverTabs(options: options, selection: $tab)
            .padding(.top, 4)
            .padding(.bottom, 22)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .requests, .issues:
            RequestsPanel(approver: canApprove, issues: canManageIssues)
        case .browse:
            DiscoverBrowseControls(kind: $kind, query: $query, canAdd: canAdd, canRequest: canRequest)
            if store.tmdbMissing {
                MetadataKeyNotice(provider: "tmdb", feature: "Discover")
            } else if requestorSearching {
                RequestorSearchResults(term: query.trimmingCharacters(in: .whitespaces), kind: kind,
                                       canAdd: canAdd, canRequest: canRequest)
            } else {
                rails
            }
        }
    }

    @ViewBuilder
    private var rails: some View {
        LetterboxdRail(canAdd: canAdd, canRequest: canRequest)
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
        DiscoverView(initialTab: .requests, title: "My requests")
    }
}
