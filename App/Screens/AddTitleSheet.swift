import SwiftUI
import FusionhaKit

enum MetadataSource: Hashable {
    case tmdb, tvdb
}

/// What the Add sheet pushes: the "View details" preview of a title (zooming
/// out of `zoomId`), from the configure step's hero or a Find tile's eye.
private struct AddDetailsRoute: Hashable {
    let route: PreviewRoute
    let zoomId: String
}

/// The web's Add dialog (AddItemModal.tsx) as a bottom sheet. Find searches
/// TMDB (or TVDB for series) with the trending grid while the field is empty;
/// the configure step (Add title v2, `AddConfigView`) sets up each version and
/// `POST /api/v1/library`. "View details" pushes the title's preview inside
/// the sheet with a zoom from the hero, and "Continue adding" zooms back to
/// the same configure state. Requester accounts get a Request flow instead.
struct AddTitleSheet: View {
    /// Open straight on this title's configure step (Discover, a preview page).
    var initialPick: AddPick?
    /// From a details page: no "View details" link back to it.
    var hideViewDetails = false
    /// Discover's session "Add as" provider.
    var providerOverride: String?
    /// After a successful add, with the new item's id.
    var onAdded: ((Int) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motionEnabled) private var motion
    @Namespace private var zoomSpace
    @State private var path = NavigationPath()
    @State private var flow: AddFlow?
    @State private var requestPick: MediaSearchResult?
    @State private var sessionProvider = "auto"
    @State private var settings: AddSettings?
    @State private var detent: PresentationDetent = .fraction(0.88)
    @State private var kind: SearchKind = .all
    @State private var source: MetadataSource = .tmdb
    @State private var query = ""
    @State private var gridView = true
    @State private var results: [MediaSearchResult] = []
    @State private var tvdbResults: [TvdbSearchResult] = []
    @State private var trending: [MediaSearchResult] = []
    @State private var trendingState: LoadState = .loading
    @State private var searchState: LoadState = .idle
    @State private var searchMissingKey = false
    @State private var trendingMissingKey = false

    enum LoadState { case idle, loading, loaded, failed }

    private var term: String { query.trimmingCharacters(in: .whitespaces) }
    private var configuring: Bool { flow != nil || requestPick != nil }
    /// Optimistic while settings load: only an explicit `false` gates.
    private var tmdbConfigured: Bool { settings?.tmdbConfigured != false }
    private var tvdbConfigured: Bool { settings?.tvdbConfigured != false }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AddDetailsRoute.self) { details in
                    previewPage(details.route)
                        .modifier(ZoomTransition(id: details.zoomId, namespace: zoomSpace))
                }
                .navigationDestination(for: PreviewRoute.self) { route in
                    previewPage(route)
                }
        }
        .presentationDetents([.fraction(0.88), .large], selection: $detent)
        .onAppear(perform: start)
        .onChange(of: kind) { if kind == .movie { source = .tmdb } }
        .onChange(of: tvdbConfigured) { if !tvdbConfigured { source = .tmdb } }
        .task(id: kind) { await loadTrending() }
        .task(id: "\(term)|\(kind.rawValue)|\(source == .tvdb)") { await search() }
        .task { settings = try? await model.client?.addSettings() }
    }

    @ViewBuilder
    private var root: some View {
        if let flow {
            AddConfigView(flow: flow, onSearchAgain: backToSearch, onViewDetails: viewDetailsAction(flow),
                          onClose: { dismiss() }, onAdded: { added($0, flow: flow) },
                          zoom: flow.pick.tmdbResult == nil ? nil : (id: heroZoomId(flow), namespace: zoomSpace))
                .id(flow.pick.key)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let requestPick {
                        header(title: "Request title", sub: "Pick the quality to request")
                        RequestConfigurator(result: requestPick) { dismiss() }
                    } else {
                        searchStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.9))
                .accessibilityLabel("Close")
                .padding(.top, 8)
                .padding(.trailing, 6)
            }
            .background(Theme.panel)
        }
    }

    // MARK: Picks

    private func start() {
        if let initialPick {
            sessionProvider = providerOverride ?? "auto"
            startFlow(initialPick)
        } else {
            sessionProvider = model.addProviderOverride ?? "auto"
            let prefill = model.addPrefill
            model.addPrefill = nil
            model.addProviderOverride = nil
            if let prefill { pick(prefill) }
        }
        #if DEBUG
        screenshotHooks()
        #endif
    }

    private func startFlow(_ pick: AddPick) {
        withAnimation(motion ? .snappy(duration: 0.3) : nil) {
            flow = AddFlow(pick: pick, client: model.client,
                           providerOverride: sessionProvider == "auto" ? nil : sessionProvider)
            detent = .large
        }
    }

    private func heroZoomId(_ flow: AddFlow) -> String { "hero-\(flow.pick.key)" }

    /// "View details": a TMDB pick's preview, pushed with a zoom from the hero.
    /// Not for a TVDB-only pick (no TMDB id), nor from a details page.
    private func viewDetailsAction(_ flow: AddFlow) -> (() -> Void)? {
        guard !hideViewDetails, let result = flow.pick.tmdbResult else { return nil }
        return { path.append(AddDetailsRoute(route: PreviewRoute(result), zoomId: heroZoomId(flow))) }
    }

    /// The configure step's back: to Find, the box seeded with the title when
    /// the pick never came from it.
    private func backToSearch() {
        let seed = flow?.title ?? requestPick?.title ?? ""
        if term.isEmpty && !seed.isEmpty { query = TitleYear.display(seed, nil).title }
        withAnimation(motion ? .snappy(duration: 0.3) : nil) {
            flow = nil
            requestPick = nil
        }
    }

    private func pick(_ result: MediaSearchResult) {
        if result.inLibrary, let id = result.libraryItemId, !model.requestScoped {
            dismiss()
            model.open(id)
        } else if model.requestScoped {
            withAnimation(motion ? .snappy(duration: 0.3) : nil) { requestPick = result }
        } else {
            startFlow(.tmdb(result))
        }
    }

    private func pickTvdb(_ result: TvdbSearchResult) {
        if result.inLibrary == true, let id = result.libraryItemId {
            dismiss()
            model.open(id)
        } else {
            startFlow(.tvdb(result))
        }
    }

    /// A Find tile's eye: the title's preview, zooming out of the tile.
    private func preview(_ result: MediaSearchResult) {
        path.append(AddDetailsRoute(route: PreviewRoute(result), zoomId: "tile-\(result.id)"))
    }

    private func isCurrent(_ route: PreviewRoute) -> Bool {
        guard let result = flow?.pick.tmdbResult else { return false }
        return PreviewRoute(result) == route
    }

    private func previewPage(_ route: PreviewRoute) -> some View {
        PreviewPage(route: route, onAdd: { result in
            // "Continue adding" goes back to the same configure state; another
            // title starts its own.
            if !isCurrent(PreviewRoute(result)) { startFlow(.tmdb(result)) }
            path = NavigationPath()
        }, onOpenLibrary: { id in
            dismiss()
            model.open(id)
        }, continueAdding: isCurrent(route), onClose: { dismiss() }, onBack: {
            if !path.isEmpty { path.removeLast() }
        })
    }

    private func added(_ item: AddedTitle, flow: AddFlow) {
        model.toast("\(flow.title) added")
        dismiss()
        Task { await model.loadLibrary() }
        onAdded?(item.id)
    }

    // MARK: Find

    @ViewBuilder
    private var searchStep: some View {
        header(title: model.requestScoped ? "Request title" : "Add title",
               sub: "Search TMDB or TVDB, then configure each version")
        SegmentedPills(options: SearchKind.allCases.map { ($0, $0.title) }, selection: $kind, style: .plain, fill: true)
        if !model.requestScoped { sourceSegment }
        searchField
        if !model.requestScoped { providerNote }
        sectionRow
        resultsBody
    }

    /// Which provider a fresh pick is added with: the session override when
    /// set, else the global default.
    private var providerNote: some View {
        let global = settings?.metadataProvider ?? model.settings?.metadataProvider ?? "tmdb"
        let effective = sessionProvider == "auto" ? global : sessionProvider
        return HStack(spacing: 5) {
            Text("Added as")
            ProviderMark(provider: effective, size: 12)
                .foregroundStyle(Theme.txt)
            Text(sessionProvider == "auto" ? "· your default" : "· overridden for this session")
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.dim)
        .padding(.leading, 3)
    }

    private func header(title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
            Text(sub).font(.system(size: 13)).foregroundStyle(Theme.mut)
        }
        .padding(.trailing, 30)
        .padding(.bottom, 4)
    }

    private var sourceSegment: some View {
        HStack(spacing: 0) {
            sourceButton(.tmdb)
            if kind != .movie { sourceButton(.tvdb) }
        }
        .padding(3)
        .panel(Theme.panel2, radius: 11)
        .sensoryFeedback(.selection, trigger: source)
    }

    private func sourceButton(_ value: MetadataSource) -> some View {
        let active = source == value
        // Shown but unreachable without a TVDB key, so people learn it exists.
        let locked = value == .tvdb && !tvdbConfigured
        let ring = value == .tmdb ? Theme.indigo.opacity(0.5) : Color(hex: 0x4FB862).opacity(0.55)
        return Button {
            withAnimation(motion ? Motion.indicator : nil) { source = value }
        } label: {
            ProviderMark(provider: value == .tmdb ? "tmdb" : "tvdb", size: 12)
                .opacity(locked ? 0.4 : 1)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.card)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(ring, lineWidth: 1.5))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(value == .tmdb ? "Search TMDB" : "Search TVDB")
        .accessibilityHint(locked ? "Needs a TVDB key → Settings" : "")
    }

    private var placeholder: String {
        if source == .tvdb { return "Search series on TheTVDB" }
        switch kind {
        case .all: return "Search movies, series & anime"
        case .movie: return "Search for a movie"
        case .series: return "Search for a series"
        case .anime: return "Search for anime"
        }
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.mut)
            TextField("", text: $query, prompt: Text(placeholder).foregroundStyle(Theme.dim))
                .font(.system(size: 16))
                .foregroundStyle(Theme.txt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.mut)
                        .frame(width: 24, height: 24)
                        .background(Theme.txt.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .panel(Theme.panel2, radius: 11)
    }

    private var sectionLabel: String {
        if term.isEmpty { return "Trending this week" }
        return source == .tvdb ? "TVDB results for “\(term)”" : "Results for “\(term)”"
    }

    private var sectionCount: Int? {
        if term.isEmpty { return nil }
        guard searchState == .loaded else { return nil }
        return source == .tvdb ? tvdbResults.count : results.count
    }

    private var sectionRow: some View {
        HStack(spacing: 8) {
            Text(sectionLabel.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
            if let count = sectionCount {
                Text("\(count)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 6)
            if source == .tmdb {
                HStack(spacing: 0) {
                    viewButton(grid: true)
                    viewButton(grid: false)
                }
                .padding(2)
                .panel(Theme.panel2, radius: 8)
            }
            HStack(spacing: 5) {
                Text("VIA").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                ProviderMark(provider: source == .tvdb ? "tvdb" : "tmdb", size: 10)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .overlay(Capsule().strokeBorder(Theme.line))
        }
        .padding(.top, 4)
    }

    private func viewButton(grid: Bool) -> some View {
        Button {
            withAnimation(motion ? Motion.indicator : nil) { gridView = grid }
        } label: {
            Image(systemName: grid ? "square.grid.2x2" : "list.bullet")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(gridView == grid ? Theme.txt : Theme.mut)
                .frame(width: 26, height: 22)
                .background(gridView == grid ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(grid ? "Grid view" : "List view")
    }

    @ViewBuilder
    private var resultsBody: some View {
        if term.isEmpty {
            if !tmdbConfigured || trendingMissingKey {
                MetadataKeyNotice(provider: "tmdb", feature: "Trending")
            } else {
                switch trendingState {
                case .loading, .idle: note("Loading trending titles…")
                case .failed: note("Could not load trending titles right now.")
                case .loaded:
                    if trending.isEmpty { note("Nothing trending right now — search above.") } else { tmdbList(trending) }
                }
            }
        } else if source == .tvdb {
            if !tvdbConfigured || searchMissingKey {
                MetadataKeyNotice(provider: "tvdb", feature: "TVDB search")
            } else {
                switch searchState {
                case .loading, .idle: note("Searching TVDB…")
                case .failed, .loaded:
                    if tvdbResults.isEmpty {
                        note("No TVDB matches for “\(term)”.")
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(tvdbResults) { result in TvdbRow(result: result) { pickTvdb(result) } }
                        }
                    }
                }
            }
        } else if !tmdbConfigured || searchMissingKey {
            MetadataKeyNotice(provider: "tmdb", feature: "TMDB search")
        } else {
            switch searchState {
            case .loading, .idle: note("Searching…")
            case .failed, .loaded:
                if results.isEmpty { note("No matches for “\(term)”.") } else { tmdbList(results) }
            }
        }
    }

    @ViewBuilder
    private func tmdbList(_ list: [MediaSearchResult]) -> some View {
        if gridView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3), spacing: 14) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, result in
                    AddTile(result: result, pick: { pick(result) }, preview: { preview(result) }, zoom: zoomSpace)
                        .reveal(index, y: 10, duration: 0.4)
                }
            }
        } else {
            LazyVStack(spacing: 8) {
                ForEach(list) { result in
                    AddListRow(result: result) { pick(result) }
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    // MARK: Loading

    private static func missingKey(_ error: Error, _ code: String) -> Bool {
        guard case .http(_, let body) = error as? APIError else { return false }
        return body.contains(code)
    }

    private func loadTrending() async {
        guard let client = model.client else { return }
        trendingState = .loading
        do {
            trending = try await client.discover(kind: kind, list: .trending)
            trendingMissingKey = false
            trendingState = .loaded
        } catch {
            if Task.isCancelled { return }
            trendingMissingKey = Self.missingKey(error, "tmdb_not_configured")
            trendingState = .failed
        }
    }

    private func search() async {
        guard !term.isEmpty else { searchState = .idle; return }
        searchState = .loading
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled, let client = model.client else { return }
        do {
            if source == .tvdb {
                tvdbResults = try await client.searchTVDB(term: term)
            } else {
                results = try await client.search(term: term, kind: kind)
            }
            searchMissingKey = false
            searchState = .loaded
        } catch {
            if Task.isCancelled { return }
            results = []
            tvdbResults = []
            searchMissingKey = Self.missingKey(error, source == .tvdb ? "tvdb_not_configured" : "tmdb_not_configured")
            searchState = .failed
        }
    }

    // MARK: Screenshots

    #if DEBUG
    /// CI screenshots: open on a trending pick (`…_ADD_PICK=<tmdb id>`, with
    /// `…_ADD_KIND` for one off the list) or a
    /// TVDB-only one (`…_ADD_TVDB=<tvdb id>`); `…_ADD_DETAILS` then pushes
    /// its "View details".
    private func screenshotHooks() {
        let env = ProcessInfo.processInfo.environment
        guard flow == nil, let client = model.client else { return }
        if let id = env["FUSIONHA_SCREENSHOT_ADD_PICK"].flatMap(Int.init) {
            Task {
                let list = (try? await client.discover(kind: .all, list: .trending)) ?? []
                var hit = list.first { $0.tmdbId == id }
                if hit == nil, let kind = env["FUSIONHA_SCREENSHOT_ADD_KIND"] {
                    // A title off the trending list (the upcoming movie).
                    hit = try? await client.discoverPreview(kind: kind == "movie" ? .movie : .series, tmdbId: id).asSearchResult
                }
                if let hit = hit ?? list.first {
                    startFlow(.tmdb(MediaSearchResult(copying: hit, inLibrary: false)))
                    if env["FUSIONHA_SCREENSHOT_ADD_DETAILS"] != nil, let flow {
                        try? await Task.sleep(for: .milliseconds(1200))
                        viewDetailsAction(flow)?()
                    }
                }
            }
        } else if let id = env["FUSIONHA_SCREENSHOT_ADD_TVDB"].flatMap(Int.init) {
            Task {
                let list = (try? await client.searchTVDB(term: "monster")) ?? []
                if let hit = list.first(where: { $0.tvdbId == id }) ?? list.first { startFlow(.tvdb(hit)) }
            }
        }
    }
    #endif
}

/// The shared "a key is missing" notice (web `KeyMissingNotice`): an amber
/// wash in place of a feature that needs a TMDB or TVDB key.
struct MetadataKeyNotice: View {
    let provider: String
    let feature: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "key")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.miss)
            (Text("\(feature) needs a \(provider == "tvdb" ? "TVDB" : "TMDB") key (free) — ")
             + Text("add one in Settings › Metadata").fontWeight(.semibold).foregroundColor(Theme.txt)
             + Text("."))
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.miss.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Step 1 pieces

private func kindName(_ result: MediaSearchResult) -> String {
    result.isAnime ? "Anime" : (result.kind == .movie ? "Movie" : "Series")
}

/// A grid tile: 2:3 art, glass kind chip, "In library" badge or the + / eye
/// buttons, then title and "YYYY · Kind".
private struct AddTile: View {
    let result: MediaSearchResult
    let pick: () -> Void
    let preview: () -> Void
    /// The poster is the zoom source for the eye's preview push.
    var zoom: Namespace.ID?

    private var subline: String {
        var parts: [String] = []
        if let year = result.year { parts.append(String(year)) }
        parts.append(kindName(result))
        if result.inLibrary { parts.append("In library") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            poster
                .overlay(alignment: .topLeading) {
                    Image(systemName: result.kind == .movie && !result.isAnime ? "film" : "tv")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(result.isAnime ? Theme.anime : .white)
                        .frame(width: 27, height: 27)
                        .glassEffect(.regular, in: Circle())
                        .padding(6)
                }
                .overlay(alignment: .topTrailing) {
                    if result.inLibrary {
                        Text("In library")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(Theme.done)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6), in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.done.opacity(0.45)))
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if !result.inLibrary {
                        HStack(spacing: 5) {
                            Button(action: preview) {
                                Image(systemName: "eye")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .glassEffect(.regular.interactive(), in: Circle())
                            }
                            .accessibilityLabel("Preview")
                            Button(action: pick) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Theme.fusion, in: Circle())
                            }
                            .accessibilityLabel("Add \(result.title)")
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.9))
                        .padding(6)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(TitleYear.display(result.title, nil).title)
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(subline)
                    .font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
    }

    @ViewBuilder
    private var poster: some View {
        let art = PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w500"))
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
        if let zoom {
            art.matchedTransitionSource(id: "tile-\(result.id)", in: zoom)
        } else {
            art
        }
    }
}

/// A list row: 38×52 thumb, title + year, "Kind · via TMDB", Add / Open ↗.
private struct AddListRow: View {
    let result: MediaSearchResult
    let pick: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w154"))
                .frame(width: 38, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                let shown = TitleYear.display(result.title, result.year)
                (Text(shown.title).foregroundStyle(Theme.txt)
                    + Text(shown.year.map { "  " + String($0) } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("\(kindName(result)) · via TMDB").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 6)
            Button(action: pick) {
                if result.inLibrary {
                    Text("Open ↗").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
                } else {
                    Text("Add")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Theme.fusion, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(8)
        .panel(Theme.card, radius: 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
    }
}

/// A TVDB row: thumb, title + year, a two-line overview, "Add via TVDB".
private struct TvdbRow: View {
    let result: TvdbSearchResult
    let pick: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            PosterImage(url: result.imageUrl.flatMap(URL.init(string:)))
                .frame(width: 38, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                let shown = TitleYear.display(result.title, result.year)
                (Text(shown.title).foregroundStyle(Theme.txt)
                    + Text(shown.year.map { "  " + String($0) } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("Series · via TVDB").font(.system(size: 12)).foregroundStyle(Theme.mut)
                if let overview = result.overview, !overview.isEmpty {
                    Text(overview).font(.system(size: 12)).foregroundStyle(Theme.dim).lineLimit(2)
                }
            }
            Spacer(minLength: 6)
            Button(action: pick) {
                if result.inLibrary == true {
                    Text("Open ↗").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
                } else {
                    Text("Add via TVDB")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color(hex: 0x4FB862), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(8)
        .panel(Theme.card, radius: 12)
    }
}

// MARK: - Requesters

private struct RequestConfigurator: View {
    @Environment(AppModel.self) private var model
    let result: MediaSearchResult
    let done: () -> Void
    @State private var tier: QualityTier = .hd
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w342"))
                    .frame(width: 72, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
                    if let overview = result.overview {
                        Text(overview).font(.system(size: 13)).foregroundStyle(Theme.mut).lineLimit(4)
                    }
                }
            }
            SegmentedPills(options: [(QualityTier.hd, "HD·1080p"), (.uhd, "UHD·4K")], selection: $tier, fill: true)
            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.danger)
            }
            Button {
                Task {
                    sending = true
                    do {
                        try await model.client?.request(MediaRequestCreate(tmdbId: result.tmdbId, kind: result.kind, tier: tier))
                        model.toast("Requested \(result.title)")
                        done()
                    } catch {
                        self.error = "Couldn't send the request. \(error.localizedDescription)"
                    }
                    sending = false
                }
            } label: {
                Text(sending ? "Requesting…" : "Request")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Theme.fusion, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(sending)
        }
    }
}
