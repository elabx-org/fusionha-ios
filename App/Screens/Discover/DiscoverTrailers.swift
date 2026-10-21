import SwiftUI
import FusionhaKit

// MARK: - Latest Trailers

struct TrailerRail: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let kind: SearchKind
    let canAdd: Bool
    @State private var list = "popular"
    @State private var state: RailLoad<TrailerResult> = .loading

    var body: some View {
        RailSection(title: "Latest Trailers", count: count) {
            Image(systemName: "play.fill").font(.system(size: 18)).foregroundStyle(Theme.i2)
        } toggle: {
            DiscoverSegmented(options: [("popular", "Popular"), ("trending", "Trending"), ("top_rated", "Top Rated")],
                              selection: $list)
        } track: {
            switch state {
            case .loading: RailStateLine(text: "Loading trailers…")
            case .failed: RailStateLine(text: "Could not load trailers.", error: true)
            case .loaded(let items) where items.isEmpty: RailStateLine(text: "No trailers right now.")
            case .loaded(let items):
                RailTrack(count: items.count, cell: 300) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, trailer in
                        TrailerCard(trailer: trailer, canAdd: canAdd)
                            .railCell(300)
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
                store.railFailed(error)
                state = .failed
            }
        }
    }

    private var count: String? {
        guard case .loaded(let items) = state else { return nil }
        return items.count == 1 ? "1 trailer" : "\(items.count) trailers"
    }
}

/// A 16:9 backdrop with a centred play button (`TrailerRail.tsx`). The art
/// stays clean: "In library" sits on the meta line, and the corner ＋ (add-
/// capable callers, titles not in the library) opens the Add sheet.
struct TrailerCard: View {
    @Environment(AppModel.self) private var model
    @Environment(DiscoverStore.self) private var store
    let trailer: TrailerResult
    let canAdd: Bool

    /// The row's flag, or the loaded library (the web's `idByTmdb`).
    private var inLibrary: Bool {
        trailer.inLibrary || model.libraryItemId(for: trailer.asSearchResult) != nil
    }

    /// 300pt wide is 900px at @3x: the w1280 backdrop (posters stop at w780).
    private var art: URL? {
        if let backdrop = trailer.backdropUrl { return TMDBImage.resized(backdrop, to: "w1280") }
        return TMDBImage.resized(trailer.posterUrl, to: "w780")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { store.trailer = trailer } label: { backdrop }
                .buttonStyle(DiscoverPressStyle())
                .accessibilityLabel("Play \(trailer.title) trailer")
                .overlay(alignment: .topTrailing) {
                    if !inLibrary && canAdd { addButton }
                }
            meta
        }
    }

    private var backdrop: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay { DiscoverArt(url: art) }
            .overlay { Theme.scrim.opacity(0.28) }
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 52, height: 52)
                    .background(Theme.primary, in: Circle())
                    .scaleEffect(0.86)
            }
            .background(Theme.card)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Theme.line))
            .shadow(color: Theme.shelfShadow.opacity(0.6), radius: 12, y: 12)
    }

    /// The corner ＋: the Add sheet on this title, with the session "Add as".
    private var addButton: some View {
        Button {
            model.openAdd(trailer.asSearchResult, providerOverride: DiscoverSession.shared.providerOverride)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.onScrim)
                .frame(width: 30, height: 30)
                .background(Theme.scrim.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .padding(.horizontal, -7).padding(.vertical, -7)
        }
        .buttonStyle(.plain)
        .padding(8)
        .accessibilityLabel("Add \(trailer.title)")
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(trailer.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            HStack(spacing: 6) {
                Text(subline).font(.system(size: 11)).foregroundStyle(Theme.mut).lineLimit(1)
                Spacer(minLength: 0)
                if inLibrary {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.done)
                        .accessibilityLabel("In library")
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 2)
    }

    private var subline: String {
        let type = trailer.isAnime ? "Anime" : (trailer.kind == .movie ? "Movie" : "Series")
        if let year = trailer.displayYear { return "\(year) · \(type)" }
        return type
    }
}
