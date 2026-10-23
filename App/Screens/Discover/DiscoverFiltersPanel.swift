import SwiftUI
import FusionhaKit

// MARK: - Discover with filters

/// "Discover with filters". With the iPhone Duo's fold through it (a Spread
/// spanning both pages, or the Web layout) it drops its card, so no panel
/// runs across the fold: the heading before the fold and Show filters after
/// it, the fields as many a side as fit (`DiscoverFold.fieldTracks`) and the
/// results on poster tracks either side of the fold (`AdaptivePosterGrid`).
struct DiscoverFiltersPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.paneSize) private var pane
    /// `repeat(auto-fit, minmax(150px, 1fr))` across the panel's inside (page gutters 2 × 16, padding 2 × 14).
    private var filterColumns: [GridItem] {
        let count = DiscoverWidthRule.filterColumns(Double(max(0, pane.width - 60)), fields: 5)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: pane.width > 0 ? count : 2)
    }
    let kind: SearchKind
    let canAdd: Bool
    let canRequest: Bool
    @State private var open = false
    @State private var filter = DiscoverFilter()
    @State private var genres: [DiscoverGenre] = []
    @State private var providers: [WatchProvider] = []
    @State private var state: RailLoad<MediaSearchResult> = .loading
    /// The panel's own width and the fold through it.
    @State private var measured = GridFold()
    /// The fold runs through the panel: no card, the pieces split at it.
    private var folded: Bool { measured.fold != nil }
    private var fieldTracks: [FoldColumns.Track]? {
        DiscoverFold.fieldTracks(fields: 5, width: Double(measured.width), fold: measured.foldRange)
    }

    var body: some View {
        Group {
            if kind == .all {
                pickKind
            } else {
                panel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: GridFold.self) { GridFold($0) } action: { measured = $0 }
        #if DEBUG
        // CI screenshots: `FUSIONHA_SCREENSHOT_DISCOVER_FILTERS=1` opens the panel.
        .onAppear { if ProcessInfo.processInfo.environment["FUSIONHA_SCREENSHOT_DISCOVER_FILTERS"] != nil { open = true } }
        #endif
    }

    /// Kind "All": which kinds filter. Centred as on the web; before the fold when one runs through.
    private var pickKind: some View {
        (Text("Pick ") + Text("Movies").foregroundColor(Theme.txt).fontWeight(.semibold)
         + Text(", ") + Text("Series").foregroundColor(Theme.txt).fontWeight(.semibold)
         + Text(", or ") + Text("Anime").foregroundColor(Theme.txt).fontWeight(.semibold)
         + Text(" above to filter by genre, year, rating, or provider."))
            .font(.system(size: 14))
            .foregroundStyle(Theme.mut)
            .multilineTextAlignment(folded ? .leading : .center)
            .lineSpacing(3)
            .frame(maxWidth: lead.map { CGFloat($0) } ?? .infinity, alignment: folded ? .leading : .center)
            .padding(.vertical, 28)
    }

    /// The room before the fold's gutter, when the fold runs through the panel.
    private var lead: Double? {
        guard let fold = measured.foldRange else { return nil }
        return FoldColumns.gap(around: fold).lowerBound
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if folded {
                FoldSpanRow { heading } trailing: { toggleButton }
            } else {
                HStack(spacing: 12) {
                    heading
                    Spacer(minLength: 0)
                    toggleButton
                }
            }
            if open {
                fields
                    .padding(.top, 16)
                results
                    .padding(.top, 20)
            }
        }
        .padding(folded ? 0 : 14)
        .background {
            if !folded { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panel) }
        }
        .overlay {
            if !folded { RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.line) }
        }
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

    private var heading: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.i2)
            Text("Discover with filters").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.txt)
        }
    }

    private var toggleButton: some View {
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

    /// The five fields: the web's auto-fit grid, or as many a side of the fold as fit.
    @ViewBuilder
    private var fields: some View {
        if let tracks = fieldTracks {
            TrackGrid(tracks: tracks, rowSpacing: 12) { fieldList }
        } else {
            LazyVGrid(columns: filterColumns, alignment: .leading, spacing: 12) { fieldList }
        }
    }

    @ViewBuilder
    private var fieldList: some View {
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
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.mut)
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
            // Same 18 × 6 rhythm as the Library grid.
            AdaptivePosterGrid {
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
