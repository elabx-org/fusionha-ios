import SwiftUI
import FusionhaKit

// Add › Find: the source switch, search field, results grid or list.

extension AddTitleSheet {
    // MARK: Find

    @ViewBuilder
    var searchStep: some View {
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
    var providerNote: some View {
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

    func header(title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.txt)
            Text(sub).font(.system(size: 13)).foregroundStyle(Theme.mut)
        }
        .padding(.trailing, 30)
        .padding(.bottom, 4)
    }

    var sourceSegment: some View {
        HStack(spacing: 0) {
            sourceButton(.tmdb)
            if kind != .movie { sourceButton(.tvdb) }
        }
        .padding(3)
        .panel(Theme.panel2, radius: 11)
        .sensoryFeedback(.selection, trigger: source)
    }

    func sourceButton(_ value: MetadataSource) -> some View {
        let active = source == value
        // Shown but unreachable without a TVDB key, so people learn it exists.
        let locked = value == .tvdb && !tvdbConfigured
        // The provider's own colour, like the web's source switch.
        let tint = value == .tmdb ? Theme.brand(0x01B4E4) : Theme.brand(0x4FB862)
        return Button {
            withAnimation(motion ? Motion.indicator : nil) { source = value }
        } label: {
            ProviderMark(provider: value == .tmdb ? "tmdb" : "tvdb", size: 12)
                .opacity(locked ? 0.4 : 1)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.12))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(tint.opacity(0.5), lineWidth: 1))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(value == .tmdb ? "Search TMDB" : "Search TVDB")
        .accessibilityHint(locked ? "Needs a TVDB key → Settings" : "")
    }

    var placeholder: String {
        if source == .tvdb { return "Search series on TheTVDB" }
        switch kind {
        case .all: return "Search movies, series & anime"
        case .movie: return "Search for a movie"
        case .series: return "Search for a series"
        case .anime: return "Search for anime"
        }
    }

    var searchField: some View {
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
                        .font(.system(size: 11, weight: .bold))
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

    var sectionLabel: String {
        if term.isEmpty { return "Trending this week" }
        return source == .tvdb ? "TVDB results for “\(term)”" : "Results for “\(term)”"
    }

    var sectionCount: Int? {
        if term.isEmpty { return nil }
        guard searchState == .loaded else { return nil }
        return source == .tvdb ? tvdbResults.count : results.count
    }

    var sectionRow: some View {
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
                Text("VIA").font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.mut)
                ProviderMark(provider: source == .tvdb ? "tvdb" : "tmdb", size: 10)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .overlay(Capsule().strokeBorder(Theme.line))
        }
        .padding(.top, 4)
    }

    func viewButton(grid: Bool) -> some View {
        Button {
            withAnimation(motion ? Motion.indicator : nil) { gridView = grid }
        } label: {
            Image(systemName: grid ? "square.grid.2x2" : "list.bullet")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(gridView == grid ? Theme.txt : Theme.mut)
                .frame(width: 26, height: 22)
                .background(gridView == grid ? Theme.card : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .padding(.horizontal, -9).padding(.vertical, -11)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(grid ? "Grid view" : "List view")
    }

    @ViewBuilder
    var resultsBody: some View {
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
    func tmdbList(_ list: [MediaSearchResult]) -> some View {
        if gridView {
            // Three across on a phone and the folded Duo, more on a wider page.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 10, alignment: .top)], spacing: 14) {
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

    func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}
