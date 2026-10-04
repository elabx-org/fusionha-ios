import SwiftUI
import FusionhaKit

enum MetadataSource: Hashable {
    case tmdb, tvdb
}

/// The web's Add dialog (AddItemModal.tsx) as a bottom sheet. Step 1 searches
/// TMDB (or TVDB for series) with the trending grid while the field is empty;
/// step 2 configures each quality edition and the title's options, then
/// `POST /api/v1/library`. Requester accounts get a Request flow instead.
struct AddTitleSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.motionEnabled) private var motion
    @State private var kind: SearchKind = .all
    @State private var source: MetadataSource = .tmdb
    @State private var query = ""
    @State private var gridView = true
    @State private var results: [MediaSearchResult] = []
    @State private var tvdbResults: [TvdbSearchResult] = []
    @State private var trending: [MediaSearchResult] = []
    @State private var trendingState: LoadState = .loading
    @State private var searchState: LoadState = .idle
    @State private var picked: MediaSearchResult?
    @State private var tvdbPicked: TvdbSearchResult?

    enum LoadState { case idle, loading, loaded, failed }

    private var term: String { query.trimmingCharacters(in: .whitespaces) }
    private var configuring: Bool { picked != nil || tvdbPicked != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let picked {
                    if model.requestScoped {
                        header(title: "Request title", sub: "Pick the quality to request")
                        RequestConfigurator(result: picked) { dismiss() }
                    } else {
                        EditionConfigurator(pick: .tmdb(picked), back: back, added: added)
                    }
                } else if let tvdbPicked {
                    EditionConfigurator(pick: .tvdb(tvdbPicked), back: back, added: added)
                } else {
                    searchStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 30)
            .animation(motion ? .snappy(duration: 0.3) : nil, value: configuring)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.panel)
        .presentationDetents([.fraction(0.88), .large])
        .onAppear {
            picked = model.addPrefill
            model.addPrefill = nil
            #if DEBUG
            if picked == nil, let id = ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_ADD_PICK"].flatMap(Int.init) {
                Task {
                    let list = (try? await model.client?.discover(kind: .all, list: .trending)) ?? []
                    if let hit = list.first(where: { $0.tmdbId == id }) ?? list.first {
                        picked = MediaSearchResult(copying: hit, inLibrary: false)
                    }
                }
            }
            #endif
        }
        .onChange(of: kind) { if kind == .movie { source = .tmdb } }
        .task(id: kind) { await loadTrending() }
        .task(id: "\(term)|\(kind.rawValue)|\(source == .tvdb)") { await search() }
    }

    private func back() {
        withAnimation(motion ? .snappy : nil) {
            picked = nil
            tvdbPicked = nil
        }
    }

    private func added(_ id: Int, _ title: String) {
        model.toast("\(title) added")
        dismiss()
        Task {
            await model.loadLibrary()
            model.open(id)
        }
    }

    // MARK: Step 1

    @ViewBuilder
    private var searchStep: some View {
        header(title: model.requestScoped ? "Request title" : "Add title",
               sub: "Search TMDB or TVDB, then configure each edition")
        SegmentedPills(options: SearchKind.allCases.map { ($0, $0.title) }, selection: $kind, style: .plain, fill: true)
        if !model.requestScoped { sourceSegment }
        searchField
        if !model.requestScoped {
            HStack(spacing: 5) {
                Text("Added as")
                ProviderLogo(provider: model.settings?.metadataProvider ?? "tmdb", compact: true)
                Text("· your default")
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.dim)
            .padding(.leading, 3)
        }
        sectionRow
        resultsBody
    }

    private func header(title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
            Text(sub).font(.system(size: 13)).foregroundStyle(Theme.mut)
        }
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
        let ring = value == .tmdb ? Theme.indigo.opacity(0.5) : Color(hex: 0x4FB862).opacity(0.55)
        return Button {
            withAnimation(motion ? Motion.indicator : nil) { source = value }
        } label: {
            ProviderLogo(provider: value == .tmdb ? "tmdb" : "tvdb")
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
        .accessibilityLabel(value == .tmdb ? "Search TMDB" : "Search TVDB")
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
        if term.isEmpty { return trendingState == .loaded ? trending.count : nil }
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
            if let count = sectionCount, count > 0 {
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
                ProviderLogo(provider: source == .tvdb ? "tvdb" : "tmdb", compact: true)
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
            switch trendingState {
            case .loading, .idle: note("Loading trending titles…")
            case .failed: note("Could not load trending titles right now.")
            case .loaded:
                if trending.isEmpty { note("Nothing trending right now — search above.") } else { tmdbList(trending) }
            }
        } else if source == .tvdb {
            switch searchState {
            case .loading, .idle: note("Searching TVDB…")
            case .failed, .loaded:
                if tvdbResults.isEmpty {
                    note("No TVDB matches for “\(term)”. TVDB search needs an API key in Settings → Metadata.")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(tvdbResults) { result in TvdbRow(result: result) { pickTvdb(result) } }
                    }
                }
            }
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
                    AddTile(result: result, pick: { pick(result) }, preview: { preview(result) })
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

    private func pick(_ result: MediaSearchResult) {
        if result.inLibrary, let id = result.libraryItemId, !model.requestScoped {
            dismiss()
            model.open(id)
        } else {
            withAnimation(motion ? .snappy : nil) { picked = result }
        }
    }

    private func pickTvdb(_ result: TvdbSearchResult) {
        if result.inLibrary == true, let id = result.libraryItemId {
            dismiss()
            model.open(id)
        } else {
            withAnimation(motion ? .snappy : nil) { tvdbPicked = result }
        }
    }

    private func preview(_ result: MediaSearchResult) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            model.openPreview(result)
        }
    }

    // MARK: Loading

    private func loadTrending() async {
        guard let client = model.client else { return }
        trendingState = .loading
        do {
            trending = try await client.discover(kind: kind, list: .trending)
            trendingState = .loaded
        } catch {
            if !Task.isCancelled { trendingState = .failed }
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
            searchState = .loaded
        } catch {
            if Task.isCancelled { return }
            results = []
            tvdbResults = []
            searchState = .failed
        }
    }
}

// MARK: - Step 1 pieces

/// The TMDB / TVDB marks, drawn (no bundled artwork).
struct ProviderLogo: View {
    let provider: String
    var compact = false

    var body: some View {
        switch provider.lowercased() {
        case "tvdb":
            HStack(spacing: 0) {
                Text("tv")
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 2)
                    .background(Color(hex: 0x4FB862), in: RoundedRectangle(cornerRadius: 3))
                Text("db").foregroundStyle(Theme.txt)
            }
            .font(.system(size: compact ? 11 : 13, weight: .heavy))
        case "tvmaze":
            Text("TVmaze").font(.system(size: compact ? 11 : 13, weight: .heavy)).foregroundStyle(Color(hex: 0x3C948B))
        case "hybrid":
            Text("Hybrid").font(.system(size: compact ? 11 : 13, weight: .heavy)).foregroundStyle(Theme.edition)
        default:
            Text("TMDB")
                .font(.system(size: compact ? 9.5 : 11, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0x90CEA1), Color(hex: 0x01B4E4)],
                                                startPoint: .leading, endPoint: .trailing))
                .padding(.horizontal, compact ? 5 : 7)
                .padding(.vertical, compact ? 2 : 3)
                .background(Color(hex: 0x0D253F), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color(hex: 0x01B4E4).opacity(0.35)))
        }
    }
}

private func kindName(_ result: MediaSearchResult) -> String {
    result.isAnime ? "Anime" : (result.kind == .movie ? "Movie" : "Series")
}

/// A grid tile: 2:3 art, glass kind chip, "In library" badge or the + / eye
/// buttons, then title and "YYYY · Kind".
private struct AddTile: View {
    let result: MediaSearchResult
    let pick: () -> Void
    let preview: () -> Void

    private var subline: String {
        var parts: [String] = []
        if let year = result.year { parts.append(String(year)) }
        parts.append(kindName(result))
        if result.inLibrary { parts.append("In library") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w342"))
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
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
                Text(result.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
                Text(subline)
                    .font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
    }
}

/// A list row: 38×52 thumb, title + year, "Kind · via TMDB", Add / Open ↗.
private struct AddListRow: View {
    let result: MediaSearchResult
    let pick: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w92"))
                .frame(width: 38, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                (Text(result.title).foregroundStyle(Theme.txt)
                    + Text(result.year.map { "  \($0)" } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
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
                (Text(result.title).foregroundStyle(Theme.txt)
                    + Text(result.year.map { "  \($0)" } ?? "").foregroundStyle(Theme.mut).font(.system(size: 13)))
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

// MARK: - Step 2 (EditionConfig + the options below it)

enum AddPick {
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
}

private struct TierConfig: Equatable {
    var enabled: Bool
    var rootId: Int?
    var profileId: Int?
    var monitor = "all"
}

private let monitorOptions: [(String, String)] = [
    ("all", "All"), ("future", "Future"), ("missing", "Missing"), ("existing", "Existing"), ("recent", "Recent"),
    ("pilot", "Pilot"), ("firstSeason", "First Season"), ("lastSeason", "Last Season"),
    ("monitorSpecials", "Monitor Specials"), ("none", "None"),
]

private let providerOptions: [(String, String)] = [
    ("auto", "Automatic (Settings default)"), ("tmdb", "TMDB"), ("tvdb", "TVDB"), ("tvmaze", "TVmaze"), ("hybrid", "Hybrid"),
]

private struct EditionConfigurator: View {
    @Environment(AppModel.self) private var model
    @Environment(\.motionEnabled) private var motion
    let pick: AddPick
    let back: () -> Void
    let added: (Int, String) -> Void

    @State private var roots: [RootFolder] = []
    @State private var profiles: [QualityProfileSummary] = []
    @State private var hd = TierConfig(enabled: true)
    @State private var uhd = TierConfig(enabled: false)
    @State private var seeded = false
    @State private var folderName = ""
    @State private var seriesType = "standard"
    @State private var provider = "auto"
    @State private var monitor = "all"
    @State private var minAvail = "announced"
    @State private var minAvailTouched = false
    @State private var searchNow = true
    @State private var adding = false
    @State private var error: String?
    @State private var fourK: FourKAvailability?
    @State private var checkingFourK = false
    @State private var fourKFailed = false

    private var isSeries: Bool { pick.kind == .series }
    private var subtitle: String {
        if case .tvdb = pick { return "Identified via TVDB — no TMDB match found · configure quality editions" }
        return "Configure quality editions — each is tracked independently"
    }
    private var effectiveAnime: Bool { pick.tmdbAnime || (isSeries && seriesType == "anime") }
    private var derivedFolder: String { pick.year.map { "\(pick.title) (\($0))" } ?? pick.title }

    /// profilesForItem: kindless profiles plus the title's own kind (and anime).
    private var kindProfiles: [QualityProfileSummary] {
        var kinds: Set<String> = [pick.kind.rawValue]
        if effectiveAnime { kinds.insert("anime") }
        return profiles.filter { $0.mediaKind == nil || kinds.contains($0.mediaKind!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                (Text(pick.title).foregroundStyle(Theme.txt)
                    + Text(pick.year.map { " \($0)" } ?? "").foregroundStyle(Theme.mut))
                    .font(.system(size: 17, weight: .bold))
                Text(subtitle)
                .font(.system(size: 13)).foregroundStyle(Theme.mut)
            }
            .padding(.bottom, 4)

            editionCard(.hd, config: $hd).reveal(0, y: 10)
            editionCard(.uhd, config: $uhd).reveal(1, y: 10)

            field("Folder name") {
                TextField("", text: $folderName, prompt: Text(derivedFolder).foregroundStyle(Theme.dim))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.txt)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .panel(Theme.panel2, radius: 11)
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach([QualityTier.hd, .uhd], id: \.self) { tier in
                    let config = tier == .hd ? hd : uhd
                    if config.enabled, let root = roots.first(where: { $0.id == config.rootId }) {
                        HStack(spacing: 7) {
                            TierPill(tier: tier)
                            Text(joinPath(root.path, folderName.isEmpty ? derivedFolder : folderName))
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(Theme.mut)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                Text("Defaults from Settings → Default profiles — change once, applied to every add.")
                    .font(.system(size: 12)).foregroundStyle(Theme.dim)
            }

            if isSeries {
                field("Series type") {
                    menuPicker(selection: $seriesType, options: [
                        ("standard", "Standard · S01E05"), ("daily", "Daily · 2020-05-25"), ("anime", "Anime · absolute 005"),
                    ])
                }
                field("Metadata provider") {
                    menuPicker(selection: $provider, options: providerOptions)
                }
                monitorControl
            } else {
                field("Minimum availability") {
                    menuPicker(selection: Binding<String>(get: { minAvail }, set: { minAvail = $0; minAvailTouched = true }),
                               options: AvailabilityOption.allCases.map { ($0.rawValue, $0.label) })
                }
            }

            Toggle(isOn: $searchNow) {
                Text("Start search for missing on add")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.txt)
            }
            .tint(Theme.indigo)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .panel(Theme.card, radius: 12)

            if let error {
                Text(error).font(.system(size: 13)).foregroundStyle(Theme.danger)
            }

            HStack(spacing: 10) {
                Button(action: back) {
                    Text("Back")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.txt)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .panel(Theme.panel2, radius: Theme.radius)
                }
                .buttonStyle(PressScaleStyle())
                Button {
                    Task { await add() }
                } label: {
                    Text(adding ? "Adding…" : (isSeries ? "Add series" : "Add movie"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.fusion, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .disabled(adding || !canAdd)
                .opacity(canAdd ? 1 : 0.5)
            }
            .padding(.top, 4)
        }
        .task { await loadOptions() }
        .onChange(of: model.settings?.defaultMovieMinimumAvailability, initial: true) {
            if !minAvailTouched, let value = model.settings?.defaultMovieMinimumAvailability { minAvail = value }
        }
        .onAppear {
            if pick.tmdbAnime { seriesType = "anime" }
        }
    }

    private var canAdd: Bool {
        let tiers = [hd, uhd].filter(\.enabled)
        return !tiers.isEmpty && tiers.allSatisfy { $0.rootId != nil && $0.profileId != nil }
    }

    // MARK: Edition card

    private func editionCard(_ tier: QualityTier, config: Binding<TierConfig>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(tier.color).frame(width: 9, height: 9)
                Text(tier.chipLabel).font(.system(size: 13.5, weight: .bold)).foregroundStyle(Theme.txt)
                if tier == .hd {
                    Text("default")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.done)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Theme.done.opacity(0.15), in: Capsule())
                }
                Spacer(minLength: 0)
                Toggle("", isOn: config.enabled.animation(motion ? .snappy : nil))
                    .labelsHidden()
                    .tint(tier.color)
            }
            if config.wrappedValue.enabled {
                VStack(alignment: .leading, spacing: 10) {
                    field("Root folder") {
                        menuPicker(selection: config.rootId, options: roots.map { ($0.id, $0.path) }, mono: true)
                    }
                    field("Quality profile") {
                        menuPicker(selection: config.profileId, options: kindProfiles.map { ($0.id, $0.name) })
                    }
                    if tier == .uhd, case .tmdb = pick { fourKPanel }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(13)
        .panel(Theme.card, radius: Theme.radiusLg)
    }

    /// FourKAvailabilityPanel: a quick indexer probe for a genuine 4K release.
    private var fourKPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("4K availability").font(.system(size: 12.5, weight: .bold)).foregroundStyle(Theme.txt)
                Spacer()
                Button {
                    Task { await checkFourK() }
                } label: {
                    Text(checkingFourK ? "Checking…" : "Quick check 4K availability")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.i2)
                }
                .buttonStyle(.plain)
                .disabled(checkingFourK)
            }
            if let fourK {
                if fourK.foundUhd == true {
                    Label {
                        Text(fourKSummary(fourK))
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.done)
                    if let tags = fourK.formatTags, !tags.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag.label)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.edition)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.edition.opacity(0.14), in: Capsule())
                            }
                        }
                    }
                } else {
                    Label("No genuine 4K found right now.", systemImage: "xmark")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.miss)
                }
            } else if fourKFailed {
                Text("Couldn't check 4K availability.").font(.system(size: 12.5)).foregroundStyle(Theme.danger)
            }
        }
        .padding(11)
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.line))
    }

    private func fourKSummary(_ result: FourKAvailability) -> String {
        let n = result.queriedIndexers ?? 0
        var text = "4K available · seen on \(n) " + (n == 1 ? "indexer" : "indexers")
        let seasons: [Int] = (result.seasonsSeen ?? []).compactMap { $0 }
        if isSeries && !seasons.isEmpty {
            text += " · seasons " + seasons.map { String($0) }.joined(separator: ", ")
        }
        return text
    }

    // MARK: MonitorControl

    private var monitorControl: some View {
        let all: [(QualityTier, Binding<TierConfig>)] = [(.hd, $hd), (.uhd, $uhd)]
        let rows = all.filter { $0.1.wrappedValue.enabled }
        let mixed = rows.contains { $0.1.wrappedValue.monitor != monitor }
        return VStack(alignment: .leading, spacing: 10) {
            (Text("Monitoring").foregroundStyle(Theme.txt).fontWeight(.bold)
                + Text(" · \(pick.title)").foregroundStyle(Theme.mut))
                .font(.system(size: 13))
                .lineLimit(1)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("All editions").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.txt)
                    Text("Sets every tier" + (mixed ? " — one edition differs, so this reads “Mixed”." : "."))
                        .font(.system(size: 11.5)).foregroundStyle(Theme.mut)
                }
                Spacer(minLength: 8)
                Menu {
                    ForEach(monitorOptions.indices, id: \.self) { idx in
                        let value = monitorOptions[idx].0
                        Button(monitorOptions[idx].1) {
                            monitor = value
                            hd.monitor = value
                            uhd.monitor = value
                        }
                    }
                } label: {
                    selectLabel(mixed ? "Mixed" : monitorLabel(monitor))
                }
            }
            ForEach(rows.indices, id: \.self) { i in
                let tier = rows[i].0
                let config = rows[i].1
                let override = config.wrappedValue.monitor != monitor
                HStack(spacing: 8) {
                    TierPill(tier: tier)
                    Text(override ? "override" : "follows all")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(override ? Theme.miss : Theme.dim)
                    if override {
                        Button { config.wrappedValue.monitor = monitor } label: {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.mut)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Reset to all")
                    }
                    Spacer(minLength: 8)
                    Menu {
                        ForEach(monitorOptions.indices, id: \.self) { idx in
                            let value = monitorOptions[idx].0
                            Button(monitorOptions[idx].1) { config.wrappedValue.monitor = value }
                        }
                    } label: {
                        selectLabel(monitorLabel(config.wrappedValue.monitor))
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(13)
        .panel(Theme.card, radius: Theme.radiusLg)
    }

    private func monitorLabel(_ value: String) -> String {
        monitorOptions.first(where: { $0.0 == value })?.1 ?? "—"
    }

    // MARK: Pieces

    private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.mut)
            content()
        }
    }

    private func menuPicker<V: Hashable>(selection: Binding<V?>, options: [(V, String)], mono: Bool = false) -> some View {
        Menu {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i].1) { selection.wrappedValue = options[i].0 }
            }
        } label: {
            selectLabel(options.first(where: { $0.0 == selection.wrappedValue })?.1 ?? "Choose…", mono: mono, full: true)
        }
    }

    private func menuPicker(selection: Binding<String>, options: [(String, String)]) -> some View {
        Menu {
            ForEach(options.indices, id: \.self) { i in
                Button(options[i].1) { selection.wrappedValue = options[i].0 }
            }
        } label: {
            selectLabel(options.first(where: { $0.0 == selection.wrappedValue })?.1 ?? "—", full: true)
        }
    }

    private func selectLabel(_ text: String, mono: Bool = false, full: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(mono ? .system(size: 13, design: .monospaced) : .system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.txt)
                .lineLimit(1)
                .truncationMode(.middle)
            if full { Spacer(minLength: 4) }
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.mut)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .frame(maxWidth: full ? .infinity : nil)
        .panel(Theme.panel2, radius: 10)
    }

    private func joinPath(_ root: String, _ folder: String) -> String {
        root.hasSuffix("/") ? root + folder : root + "/" + folder
    }

    // MARK: Data

    private func loadOptions() async {
        guard !seeded, let client = model.client else { return }
        async let rootsCall = client.rootFolders()
        async let profilesCall = client.qualityProfileSummaries()
        async let defaultsCall = client.addDefaults()
        roots = (try? await rootsCall) ?? []
        profiles = (try? await profilesCall) ?? []
        let defaults = (try? await defaultsCall) ?? []
        hd = preset(.hd, current: hd, defaults: defaults)
        uhd = preset(.uhd, current: uhd, defaults: defaults)
        seeded = true
    }

    /// makeDefaults: the saved add-default slot, else a root whose path fits
    /// the kind and tier, else the first; profiles by 4K-ness.
    private func preset(_ tier: QualityTier, current: TierConfig, defaults: [AddDefaultSlot]) -> TierConfig {
        var config = current
        let resolvedKind = (pick.tmdbAnime || seriesType == "anime") ? "anime" : pick.kind.rawValue
        let slot = defaults.first { $0.profileKind == resolvedKind && $0.tier == tier }
        let wants4k = tier == .uhd
        func matches(_ text: String, _ pattern: String) -> Bool {
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        func kindMatch(_ r: RootFolder) -> Bool {
            isSeries ? matches(r.path, "tv|anime|series|show") : matches(r.path, "movie|film")
        }
        func tierMatch(_ r: RootFolder) -> Bool { matches(r.path, "4k|2160|uhd") == wants4k }
        let root = roots.first(where: { kindMatch($0) && tierMatch($0) }) ?? roots.first(where: kindMatch)
            ?? roots.first(where: tierMatch) ?? roots.first
        config.rootId = slot?.rootFolderId ?? root?.id
        func is4k(_ p: QualityProfileSummary) -> Bool {
            matches(p.name, "4k|2160|uhd|ultra") || (p.allowedQualities ?? []).contains { matches($0, "2160|4k|uhd") }
        }
        let list = kindProfiles
        var profile: QualityProfileSummary? = nil
        if resolvedKind == "anime" { profile = list.first(where: { $0.mediaKind == "anime" && is4k($0) == wants4k }) }
        if profile == nil { profile = list.first(where: { is4k($0) == wants4k }) }
        if profile == nil { profile = list.first }
        config.profileId = slot?.qualityProfileId ?? profile?.id
        return config
    }

    private func checkFourK() async {
        guard case .tmdb(let result) = pick, let client = model.client else { return }
        checkingFourK = true
        fourKFailed = false
        do {
            fourK = try await client.checkFourK(FourKAvailabilityRequest(
                tmdbId: result.tmdbId, title: result.title, kind: result.kind, year: result.year, isAnime: effectiveAnime))
        } catch {
            fourKFailed = true
        }
        checkingFourK = false
    }

    private func add() async {
        guard let client = model.client else { return }
        adding = true
        error = nil
        defer { adding = false }
        let trimmed = folderName.trimmingCharacters(in: .whitespaces)
        let folderEdited = !trimmed.isEmpty && trimmed != derivedFolder
        var editions: [EditionAddBody] = []
        for (tier, config) in [(QualityTier.hd, hd), (.uhd, uhd)] where config.enabled {
            guard let root = config.rootId, let profile = config.profileId else { continue }
            editions.append(EditionAddBody(
                tier: tier, rootFolderId: root, qualityProfileId: profile,
                monitor: isSeries && config.monitor != monitor ? config.monitor : nil,
                folderName: folderEdited ? trimmed : nil))
        }
        let body: LibraryAddBody
        switch pick {
        case .tmdb(let result):
            body = LibraryAddBody(
                title: result.title, kind: result.kind, year: result.year, tmdbId: result.tmdbId, tvdbId: nil,
                isAnime: effectiveAnime, editions: editions, searchNow: searchNow,
                monitor: isSeries ? monitor : "all", minimumAvailability: isSeries ? nil : minAvail,
                seriesType: isSeries ? seriesType : nil,
                metadataProvider: isSeries && provider != "auto" ? provider : nil)
        case .tvdb(let result):
            let global = model.settings?.metadataProvider ?? "tmdb"
            body = LibraryAddBody(
                title: result.title, kind: .series, year: result.year, tmdbId: nil, tvdbId: result.tvdbId,
                isAnime: effectiveAnime, editions: editions, searchNow: searchNow, monitor: monitor,
                minimumAvailability: nil, seriesType: seriesType,
                metadataProvider: provider != "auto" ? provider : (global == "tmdb" ? "tvdb" : global))
        }
        do {
            let item = try await client.addItem(body)
            added(item.id, pick.title)
        } catch {
            self.error = "Couldn't add this title. \(error.localizedDescription)"
            model.toast("Couldn't add \(pick.title)", variant: .error)
        }
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
