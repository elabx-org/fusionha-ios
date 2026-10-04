import SwiftUI
import FusionhaKit

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, downloading, missing, complete, attention
    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All"
        case .downloading: return "Downloading"
        case .missing: return "Missing"
        case .complete: return "Complete"
        case .attention: return "Needs attention"
        }
    }

    func matches(_ item: MediaItem) -> Bool {
        let monitored = item.editions.filter(\.monitored)
        switch self {
        case .all: return true
        case .downloading: return item.editions.contains { $0.status == .downloading || $0.status == .upgrading }
        case .missing: return monitored.contains { $0.status == .missing }
        case .complete: return !monitored.isEmpty && monitored.allSatisfy { $0.status == .downloaded }
        case .attention: return item.hasAttention == true
        }
    }
}

enum LibraryKind: String, CaseIterable, Identifiable {
    case all, movies, series, anime
    var id: Self { self }
    var title: String { rawValue.capitalized }

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all: return true
        case .movies: return item.kind == .movie && item.isAnime != true
        case .series: return item.kind == .series && item.isAnime != true
        case .anime: return item.isAnime == true
        }
    }
}

enum LibraryQuality: String, CaseIterable, Identifiable {
    case all, hd, uhd
    var id: Self { self }
    var title: String { self == .all ? "All" : (self == .hd ? "HD" : "4K") }

    func matches(_ item: MediaItem) -> Bool {
        switch self {
        case .all: return true
        case .hd: return item.editions.contains { $0.tier == .hd }
        case .uhd: return item.editions.contains { $0.tier == .uhd }
        }
    }
}

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [MediaItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var query = ""
    @State private var filter: LibraryFilter = .all
    @State private var kind: LibraryKind = .all
    @State private var quality: LibraryQuality = .all
    @Namespace private var zoom

    private var base: [MediaItem] {
        items.filter { kind.matches($0) && quality.matches($0) &&
            (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }
    }

    private var visible: [MediaItem] {
        base.filter(filter.matches).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                pulse
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 12)], spacing: 18) {
                    ForEach(visible) { item in
                        NavigationLink(value: item) {
                            PosterCard(item: item)
                                .matchedTransitionSource(id: item.id, in: zoom)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { contextActions(for: item) }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Library")
            .navigationDestination(for: MediaItem.self) { item in
                ItemDetailView(item: item)
                    .navigationTransition(.zoom(sourceID: item.id, in: zoom))
            }
            .searchable(text: $query, prompt: "Search this library")
            .refreshable { await load() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
                ToolbarItem(placement: .topBarTrailing) { AccountButton() }
            }
            .overlay { stateOverlay }
            .task { await load() }
        }
    }

    /// The web's LibraryPulse status filter, as morphing glass chips.
    private var pulse: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(LibraryFilter.allCases) { f in
                        FilterChip(title: f.title, count: base.filter(f.matches).count, selected: f == filter) {
                            withAnimation(.smooth) { filter = f }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Type", selection: $kind) {
                ForEach(LibraryKind.allCases) { Text($0.title).tag($0) }
            }
            Picker("Quality", selection: $quality) {
                ForEach(LibraryQuality.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Filter")
    }

    @ViewBuilder
    private func contextActions(for item: MediaItem) -> some View {
        Button("Automatic search", systemImage: "magnifyingglass") {
            Task { try? await model.client?.searchItem(id: item.id) }
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        if items.isEmpty {
            if loading {
                ProgressView()
            } else if let error {
                ContentUnavailableView("Couldn't load the library", systemImage: "wifi.exclamationmark", description: Text(error))
            } else {
                ContentUnavailableView("Your library is empty", systemImage: "square.grid.2x2")
            }
        } else if visible.isEmpty {
            ContentUnavailableView.search(text: query)
        }
    }

    private func load() async {
        guard let client = model.client else { return }
        do {
            items = try await client.library()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

/// Poster-forward card: clean art, edition chips in the body below (design rule).
struct PosterCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PosterImage(url: TMDBImage.resized(item.posterUrl, to: "w342"))
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) { liveBadge }
            Text(item.title).font(.footnote.weight(.semibold)).lineLimit(1)
            HStack(spacing: 4) {
                ForEach(item.editions) { EditionChip(tier: $0.tier, status: $0.status) }
            }
        }
    }

    @ViewBuilder
    private var liveBadge: some View {
        if item.editions.contains(where: { $0.status == .downloading }) {
            Image(systemName: "arrow.down")
                .font(.caption2.bold())
                .foregroundStyle(Theme.grab)
                .symbolEffect(.pulse)
                .frame(width: 27, height: 27)
                .glassEffect(.regular, in: .circle)
                .padding(6)
        }
    }
}

/// One glass capsule in the status filter row.
private struct FilterChip: View {
    let title: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)").monospacedDigit().foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(selected ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .capsule)
    }

    private var glass: Glass {
        selected ? Glass.regular.tint(Theme.indigo.opacity(0.45)).interactive() : Glass.regular.interactive()
    }
}
