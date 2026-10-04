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
    var requestsVersion = 0

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
                    .padding(.horizontal, 10)
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
            PreviewSheet(route: route,
                         onAdd: { result in handOff { model.addPrefill = result; model.showingAdd = true } },
                         onOpenLibrary: { id in handOff { model.open(id) } })
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
        .onChange(of: canManageIssues) { if tab == .issues && !canManageIssues { tab = .browse } }
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
            Text("Discover")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Theme.txt)
                .padding(.bottom, 10)
            DiscoverSegmented(options: SearchKind.allCases.map { ($0, $0.title) }, selection: $kind, size: .md)
                .padding(.bottom, 14)
            if canAdd {
                Button { model.addPrefill = nil; model.showingAdd = true } label: {
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
                AddAsControl()
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
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.cyan)
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
            Task { try? await Task.sleep(for: .seconds(2)); scrollTarget = raw }
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

// MARK: - "Add as" provider control

private struct AddAsControl: View {
    @State private var session = DiscoverSession.shared

    private func label(_ value: String) -> String {
        switch value {
        case "tvdb": return "TVDB"
        case "hybrid": return "Hybrid"
        default: return "TMDB"
        }
    }

    var body: some View {
        @Bindable var session = session
        HStack(spacing: 6) {
            Text("Add as").foregroundStyle(Theme.dim)
            Menu {
                Picker("Add as", selection: $session.providerOverride) {
                    Text("Default (\(label(session.globalProvider)))").tag("auto")
                    Text("TMDB").tag("tmdb")
                    Text("TVDB").tag("tvdb")
                    Text("Hybrid").tag("hybrid")
                }
            } label: {
                HStack(spacing: 6) {
                    DiscoverProviderMark(provider: session.effectiveProvider)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .padding(.horizontal, 2)
                .frame(minHeight: 30)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Add as \(label(session.effectiveProvider))")
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.mut)
    }
}

// MARK: - Rails

/// Rail chrome: heading, count, own-line toggle, then the state or the track.
struct RailSection<Icon: View, Toggle: View, Track: View>: View {
    let title: String
    let count: String?
    @ViewBuilder var icon: Icon
    @ViewBuilder var toggle: Toggle
    @ViewBuilder var track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    HStack(spacing: 8) {
                        icon
                        Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                    }
                    if let count {
                        Text(count).font(.system(size: 12)).foregroundStyle(Theme.dim)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) { toggle }
                    .scrollClipDisabled()
            }
            .padding(.bottom, 14)
            track
        }
        .padding(.bottom, 34)
    }
}

enum RailLoad<T> {
    case loading, failed, loaded([T])
}

/// A titled horizontal rail of Discover posters.
struct DiscoverRail<Icon: View, Toggle: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    /// Changes when the rail must refetch (kind, window, monetization).
    let key: String
    let trending: Bool
    let canAdd: Bool
    let canRequest: Bool
    @ViewBuilder var icon: Icon
    @ViewBuilder var toggle: Toggle
    let load: (APIClient) async throws -> [MediaSearchResult]
    @State private var state: RailLoad<MediaSearchResult> = .loading

    var body: some View {
        RailSection(title: title, count: count) { icon } toggle: { toggle } track: {
            switch state {
            case .loading: RailStateLine(text: "Loading…")
            case .failed: RailStateLine(text: "Could not load this rail.", error: true)
            case .loaded(let items) where items.isEmpty: RailStateLine(text: "No titles right now.")
            case .loaded(let items):
                RailTrack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        DiscoverCard(result: item, trending: trending, canAdd: canAdd, canRequest: canRequest)
                            .frame(width: 116)
                            .discoverReveal(index: index)
                    }
                }
            }
        }
        .task(id: key) {
            guard let client = model.client else { return }
            if case .loaded = state {} else { state = .loading }
            do {
                state = .loaded(try await load(client))
            } catch is CancellationError {
            } catch {
                state = .failed
            }
        }
    }

    private var count: String? {
        guard case .loaded(let items) = state else { return nil }
        return items.count == 1 ? "1 title" : "\(items.count) titles"
    }
}

extension DiscoverRail where Toggle == EmptyView {
    init(title: String, key: String, trending: Bool, canAdd: Bool, canRequest: Bool,
         @ViewBuilder icon: () -> Icon, load: @escaping (APIClient) async throws -> [MediaSearchResult]) {
        self.init(title: title, key: key, trending: trending, canAdd: canAdd, canRequest: canRequest,
                  icon: icon, toggle: { EmptyView() }, load: load)
    }
}

/// The horizontal track: gap 14, padding 2 2 12, snaps to cards.
struct RailTrack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) { content }
                .scrollTargetLayout()
                .padding(.horizontal, 2)
                .padding(.top, 2)
                .padding(.bottom, 12)
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
        .scrollClipDisabled()
    }
}

extension View {
    /// Cards stagger in (0.026s each), not under Reduce DiscoverMotion.
    func discoverReveal(index: Int, step: Double = 0.026) -> some View {
        modifier(DiscoverRevealIn(delay: Double(min(index, 12)) * step))
    }
}

private struct DiscoverRevealIn: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(DiscoverMotion.reduced(reduceMotion) || shown ? 1 : 0)
            .offset(y: DiscoverMotion.reduced(reduceMotion) || shown ? 0 : 12)
            .onAppear {
                guard !DiscoverMotion.reduced(reduceMotion), !shown else { return }
                withAnimation(DiscoverMotion.reveal().delay(delay)) { shown = true }
            }
    }
}

private struct TrendingRail: View {
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var window = "week"

    var body: some View {
        let kind = self.kind
        let window = self.window
        DiscoverRail(title: "Trending", key: "trending|\(kind.rawValue)|\(window)", trending: true,
                     canAdd: canAdd, canRequest: canRequest) {
            Image(systemName: "flame").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.anime)
        } toggle: {
            DiscoverSegmented(options: [("day", "Today"), ("week", "This Week")], selection: $window)
        } load: { client in
            try await client.discover(kind: kind, list: .trending, window: window, monetization: nil)
        }
    }
}

private struct PopularRail: View {
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var monetization: DiscoverMonetization = .streaming

    var body: some View {
        let kind = self.kind
        let monetization = self.monetization
        DiscoverRail(title: "What's Popular", key: "popular|\(kind.rawValue)|\(monetization.rawValue)", trending: false,
                     canAdd: canAdd, canRequest: canRequest) {
            EmptyView()
        } toggle: {
            DiscoverSegmented(options: DiscoverMonetization.allCases.map { ($0, $0.title) }, selection: $monetization)
        } load: { client in
            try await client.discover(kind: kind, list: .popular, window: nil, monetization: monetization)
        }
    }
}

// MARK: - Discover card

/// `DiscoverCard`: a clean 2:3 poster with a corner status badge, then title
/// and a `year · kind` line with the provider mark and request chip.
struct DiscoverCard: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let result: MediaSearchResult
    var trending = false
    let canAdd: Bool
    let canRequest: Bool
    @State private var checking = false

    private var inLibrary: Bool { result.inLibrary || result.libraryItemId != nil }
    private var requestStatus: String? { store.statusByTmdb[result.tmdbId] }
    private var alreadyRequested: Bool { requestStatus == "pending" || requestStatus == "approved" }

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                poster
                meta
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DiscoverPressStyle())
        .contextMenu { menu } preview: {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w342"))
                .frame(width: 220, height: 330)
        }
    }

    private var poster: some View {
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { DiscoverArt(url: TMDBImage.resized(result.posterUrl, to: "w342")) }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
            .shadow(color: .black.opacity(0.55), radius: 12, y: 12)
            .overlay(alignment: .topLeading) {
                if inLibrary {
                    PosterStatusBadge(kind: .inLibrary).padding(8)
                } else if trending {
                    PosterStatusBadge(kind: .trending).padding(8)
                }
            }
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    if let year = result.displayYear { Text(verbatim: "\(year) · ") }
                    DiscoverKindGlyph(kind: result.kind, isAnime: result.isAnime)
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
                Spacer(minLength: 0)
                providerException
                if !inLibrary, let status = requestStatus, status == "pending" || status == "approved" {
                    let color = status == "pending" ? Theme.miss : Theme.cyan
                    Text(status == "pending" ? "Requested" : "Approved")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.16), in: Capsule())
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var providerException: some View {
        let global = DiscoverSession.shared.globalProvider
        if result.kind == .movie && global != "tmdb" {
            DiscoverProviderMark(provider: "tmdb", height: 9)
        } else if result.kind == .series && global == "tvdb" {
            DiscoverProviderMark(provider: "tvdb", height: 11)
        }
    }

    private func open() {
        if inLibrary {
            if let id = result.libraryItemId, !model.requestScoped { model.open(id) }
        } else if canAdd {
            store.preview = PreviewRoute(result)
        } else if canRequest && !alreadyRequested {
            store.requestPick = result
        }
    }

    @ViewBuilder
    private var menu: some View {
        if inLibrary {
            if let id = result.libraryItemId {
                Button { Task { await checkLibrary(id) } } label: {
                    Label(checking ? "Checking…" : "Check for 4K", systemImage: "4k.tv")
                }
                .disabled(checking)
            }
        } else {
            if canAdd {
                Button { store.preview = PreviewRoute(result) } label: { Label("Add to library", systemImage: "plus") }
            } else if canRequest && !alreadyRequested {
                Button { store.requestPick = result } label: { Label("Request", systemImage: "paperplane") }
            }
            Button { Task { await checkDiscover() } } label: {
                Label(checking ? "Checking…" : "Check for 4K", systemImage: "4k.tv")
            }
            .disabled(checking)
            Button { store.preview = PreviewRoute(result) } label: { Label("View details", systemImage: "eye") }
        }
    }

    private func checkLibrary(_ id: Int) async {
        guard let client = model.client else { return }
        checking = true
        defer { checking = false }
        do {
            let r = try await client.libraryCheckFourK(itemId: id)
            var message = (r.message?.isEmpty == false ? r.message! : "Checked \(result.title) for 4K.")
            if r.foundUhd { message += " See Wanted → 4K Available for details." }
            DiscoverToasts.shared.show(r.foundUhd ? .success : .info, message)
        } catch {
            DiscoverToasts.shared.error("Could not check for 4K", error)
        }
    }

    private func checkDiscover() async {
        guard let client = model.client else { return }
        checking = true
        defer { checking = false }
        do {
            let r = try await client.discoverCheckFourK(DiscoverCheckFourKBody(
                tmdbId: result.tmdbId, title: result.title, kind: result.kind,
                year: result.displayYear, isAnime: result.isAnime))
            if r.foundUhd {
                let n = r.queriedIndexers ?? 0
                DiscoverToasts.shared.show(.success, "\(result.title): genuine 4K available (seen on \(n) indexer\(n == 1 ? "" : "s")). Enable 4K when you add it to grab it.")
            } else {
                DiscoverToasts.shared.show(.info, "\(result.title): no genuine 4K found right now.")
            }
        } catch {
            DiscoverToasts.shared.error("Could not check for 4K", error)
        }
    }
}

// MARK: - Latest Trailers

private struct TrailerRail: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let kind: SearchKind
    let canAdd: Bool
    @State private var list = "popular"
    @State private var state: RailLoad<TrailerResult> = .loading

    var body: some View {
        RailSection(title: "Latest Trailers", count: count) {
            Image(systemName: "play.fill").font(.system(size: 18)).foregroundStyle(Theme.cyan)
        } toggle: {
            DiscoverSegmented(options: [("popular", "Popular"), ("trending", "Trending"), ("top_rated", "Top Rated")],
                              selection: $list)
        } track: {
            switch state {
            case .loading: RailStateLine(text: "Loading trailers…")
            case .failed: RailStateLine(text: "Could not load trailers.", error: true)
            case .loaded(let items) where items.isEmpty: RailStateLine(text: "No trailers right now.")
            case .loaded(let items):
                RailTrack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, trailer in
                        TrailerCard(trailer: trailer, canAdd: canAdd)
                            .frame(width: 300)
                            .discoverReveal(index: index)
                    }
                }
            }
        }
        .task(id: "\(kind.rawValue)|\(list)") {
            guard let client = model.client else { return }
            if case .loaded = state {} else { state = .loading }
            do {
                if kind == .all {
                    async let movies = client.trailers(kind: .movie, list: list)
                    async let series = client.trailers(kind: .series, list: list)
                    let m = try await movies
                    let s = try await series
                    state = .loaded(interleave(m, s))
                } else {
                    state = .loaded(try await client.trailers(kind: kind, list: list))
                }
            } catch is CancellationError {
            } catch {
                state = .failed
            }
        }
    }

    private var count: String? {
        guard case .loaded(let items) = state else { return nil }
        return items.count == 1 ? "1 trailer" : "\(items.count) trailers"
    }
}

private struct TrailerCard: View {
    @Environment(DiscoverStore.self) private var store
    let trailer: TrailerResult
    let canAdd: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { store.trailer = trailer } label: {
                Color.clear
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { DiscoverArt(url: TMDBImage.resized(trailer.backdropUrl ?? trailer.posterUrl, to: "w780")) }
                    .overlay { Color(red: 6 / 255, green: 7 / 255, blue: 10 / 255).opacity(0.28) }
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(Theme.fusion, in: Circle())
                            .shadow(color: Theme.cyan.opacity(0.5), radius: 14, y: 12)
                            .scaleEffect(0.86)
                    }
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
                    .shadow(color: .black.opacity(0.55), radius: 12, y: 12)
            }
            .buttonStyle(DiscoverPressStyle())
            .accessibilityLabel("Play trailer for \(trailer.title)")
            .overlay(alignment: .topLeading) {
                if trailer.inLibrary { PosterStatusBadge(kind: .inLibrary).padding(8) }
            }
            .overlay(alignment: .topTrailing) {
                if !trailer.inLibrary && canAdd {
                    Button { store.preview = PreviewRoute(trailer.asSearchResult) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(red: 6 / 255, green: 7 / 255, blue: 10 / 255).opacity(0.6),
                                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Add \(trailer.title)")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(trailer.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(subline).font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
    }

    private var subline: String {
        let type = trailer.isAnime ? "Anime" : (trailer.kind == .movie ? "Movie" : "Series")
        if let year = trailer.displayYear { return "\(year) · \(type)" }
        return type
    }
}

// MARK: - Complete your collections

private struct CollectionsRail: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    @State private var state: RailLoad<CollectionSummary> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                CollectionsSkeleton()
            case .failed:
                EmptyView()
            case .loaded(let items) where items.isEmpty:
                EmptyView()
            case .loaded(let items):
                RailSection(title: "Complete your collections",
                            count: items.count == 1 ? "1 franchise" : "\(items.count) franchises") {
                    Image(systemName: "square.grid.2x2").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.cyan)
                } toggle: {
                    EmptyView()
                } track: {
                    RailTrack {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, collection in
                            CollectionCard(collection: collection) { ignore(collection) }
                                .frame(width: 116)
                                .discoverReveal(index: index)
                        }
                    }
                }
            }
        }
        .task(id: store.collectionsVersion) {
            guard let client = model.client else { return }
            do {
                state = .loaded(try await client.collections())
            } catch is CancellationError {
            } catch {
                state = .failed
            }
        }
    }

    private func ignore(_ collection: CollectionSummary) {
        Task {
            do {
                try await model.client?.ignoreCollection(DiscoverIgnoreCreate(collectionTmdbId: collection.collectionTmdbId,
                                                                              name: collection.name))
                DiscoverToasts.shared.show(.info, "Ignored \(collection.name)")
                store.collectionsVersion += 1
            } catch {
                DiscoverToasts.shared.show(.error, error.localizedDescription)
            }
        }
    }
}

private struct CollectionCard: View {
    @Environment(DiscoverStore.self) private var store
    let collection: CollectionSummary
    let onIgnore: () -> Void

    private var missing: Int { max(0, collection.totalCount - collection.ownedCount) }

    var body: some View {
        Button { store.collection = collection } label: { content }
            .buttonStyle(DiscoverPressStyle())
            .contextMenu {
                Button { store.collection = collection } label: {
                    Label(missing == 1 ? "Add missing film" : "Add missing films", systemImage: "plus")
                }
                Button(action: onIgnore) { Label("Ignore collection", systemImage: "eye.slash") }
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { DiscoverArt(url: TMDBImage.resized(collection.posterUrl, to: "w342")) }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
                .shadow(color: .black.opacity(0.55), radius: 12, y: 12)
                .overlay(alignment: .topLeading) {
                    CollectionRingBadge(owned: collection.ownedCount, total: collection.totalCount).padding(8)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(collection.totalCount == 1 ? "1 film" : "\(collection.totalCount) films")
                    .font(.system(size: 11)).foregroundStyle(Theme.mut)
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
    }
}

/// `CollectionRingBadge`: a frosted 33pt plate with a completion ring.
struct CollectionRingBadge: View {
    let owned: Int
    let total: Int

    var body: some View {
        let fraction = total > 0 ? Double(owned) / Double(total) : 0
        ZStack {
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.done, style: StrokeStyle(lineWidth: 3.5, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            if owned >= total && total > 0 {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.done)
            } else {
                Text(verbatim: "\(owned)/\(total)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.txt)
            }
        }
        .padding(1.75)
        .frame(width: 33, height: 33)
        .background(Color(red: 14 / 255, green: 16 / 255, blue: 22 / 255).opacity(0.92), in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(0.16)))
        .shadow(color: .black.opacity(0.75), radius: 7, y: 4)
        .accessibilityLabel("\(owned) of \(total) owned")
    }
}

private struct CollectionsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DiscoverShimmer().frame(width: 200, height: 16)
            DiscoverShimmer().frame(width: 70, height: 10)
                .padding(.bottom, 6)
            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        DiscoverShimmer(radius: 13).frame(width: 116, height: 174)
                        DiscoverShimmer(radius: 4).frame(width: 90, height: 10)
                        DiscoverShimmer(radius: 4).frame(width: 50, height: 8)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .padding(.bottom, 34)
        .accessibilityHidden(true)
    }
}

// MARK: - Discover with filters

private struct DiscoverFiltersPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var open = false
    @State private var filter = DiscoverFilter()
    @State private var genres: [DiscoverGenre] = []
    @State private var providers: [WatchProvider] = []
    @State private var state: RailLoad<MediaSearchResult> = .loading

    var body: some View {
        if kind == .all {
            (Text("Pick ") + Text("Movies").foregroundColor(Theme.txt).fontWeight(.semibold)
             + Text(", ") + Text("Series").foregroundColor(Theme.txt).fontWeight(.semibold)
             + Text(", or ") + Text("Anime").foregroundColor(Theme.txt).fontWeight(.semibold)
             + Text(" above to filter by genre, year, rating, or provider."))
                .font(.system(size: 14))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else {
            panel
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.cyan)
                Text("Discover with filters").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer(minLength: 0)
                Button { withAnimation(DiscoverMotion.reduced(reduceMotion) ? nil : DiscoverMotion.reveal(0.3)) { open.toggle() } } label: {
                    Text(open ? "Hide filters" : "Show filters")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(DiscoverPalette.well, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line))
                }
                .buttonStyle(.plain)
            }
            if open {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          alignment: .leading, spacing: 12) {
                    field("Genre", value: genres.first { $0.id == filter.genre }?.name ?? "Any genre") {
                        Button("Any genre") { filter.genre = nil }
                        ForEach(genres) { g in Button(g.name) { filter.genre = g.id } }
                    }
                    field("Year", value: filter.year.map(String.init) ?? "Any year") {
                        Button("Any year") { filter.year = nil }
                        ForEach(years, id: \.self) { y in Button(String(y)) { filter.year = y } }
                    }
                    field("Min rating", value: filter.minRating.map { "\($0)+" } ?? "Any rating") {
                        Button("Any rating") { filter.minRating = nil }
                        ForEach([9, 8, 7, 6, 5, 4], id: \.self) { r in Button("\(r)+") { filter.minRating = r } }
                    }
                    field("Provider", value: providers.first { $0.id == filter.provider }?.name ?? "Any provider") {
                        Button("Any provider") { filter.provider = nil }
                        ForEach(providers) { p in Button(p.name) { filter.provider = p.id } }
                    }
                    field("Sort by", value: filter.sort.title) {
                        ForEach(DiscoverSort.allCases, id: \.self) { s in Button(s.title) { filter.sort = s } }
                    }
                }
                .padding(.top, 16)
                results
                    .padding(.top, 20)
            }
        }
        .padding(14)
        .panel(Theme.panel, radius: 14)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .task(id: open ? kind.rawValue : "closed") {
            guard open, let client = model.client else { return }
            async let g = client.discoverGenres(kind: kind)
            async let p = client.watchProviders(kind: kind)
            genres = (try? await g) ?? []
            providers = (try? await p) ?? []
        }
        .task(id: open ? "\(kind.rawValue)|\(filter.hashValue)" : "closed") {
            guard open, let client = model.client else { return }
            state = .loading
            do {
                state = .loaded(try await client.discoverFilter(kind: kind, filter: filter))
            } catch is CancellationError {
            } catch {
                state = .failed
            }
        }
        .onChange(of: kind) { filter.genre = nil; filter.provider = nil }
    }

    private var years: [Int] {
        let next = Calendar.current.component(.year, from: Date()) + 1
        return Array((next - 45)...next).reversed()
    }

    private func field<Items: View>(_ label: String, value: String, @ViewBuilder items: () -> Items) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Theme.mut)
            Menu { items() } label: {
                HStack(spacing: 6) {
                    Text(value).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.mut)
                }
                .foregroundStyle(Theme.txt)
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line))
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        switch state {
        case .loading: filterState("Loading results…")
        case .failed: filterState("Could not load results.", error: true)
        case .loaded(let items) where items.isEmpty: filterState("No titles match these filters.")
        case .loaded(let items):
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9, alignment: .top), count: 3),
                      alignment: .leading, spacing: 16) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DiscoverCard(result: item, canAdd: canAdd, canRequest: canRequest)
                        .discoverReveal(index: index, step: 0.02)
                }
            }
        }
    }

    private func filterState(_ text: String, error: Bool = false) -> some View {
        Text(text).font(.system(size: 13)).foregroundStyle(error ? Theme.danger : Theme.mut)
            .padding(.vertical, 16).padding(.horizontal, 2)
    }
}

// MARK: - Requester inline search

private struct RequestorSearchResults: View {
    @Environment(AppModel.self) private var model
    let term: String
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var state: RailLoad<MediaSearchResult> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading: line("Searching…")
            case .failed: line("Couldn't search right now — try again.")
            case .loaded(let items) where items.isEmpty: line("No results for “\(term)”.")
            case .loaded(let items):
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16, alignment: .top),
                                    GridItem(.flexible(), spacing: 16, alignment: .top)],
                          alignment: .leading, spacing: 16) {
                    ForEach(items) { DiscoverCard(result: $0, canAdd: canAdd, canRequest: canRequest) }
                }
                .padding(.top, 4)
            }
        }
        .task(id: "\(term)|\(kind.rawValue)") {
            guard let client = model.client else { return }
            state = .loading
            do {
                state = .loaded(try await client.search(term: term, kind: kind))
            } catch is CancellationError {
            } catch {
                state = .failed
            }
        }
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.system(size: 13.5)).foregroundStyle(Theme.mut)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
