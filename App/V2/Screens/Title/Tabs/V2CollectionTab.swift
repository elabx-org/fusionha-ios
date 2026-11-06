import SwiftUI
import FusionhaKit

/// The Collection tab in v2: v1's header (thumb, name, completion, Add all
/// missing, Monitor) in the page's one ink, over the franchise as Library
/// cards: the Library grid's columns and poster size (`V2LibraryColumns`),
/// each film's HD/4K badges under its art, nothing on the art (owner,
/// build 805: three ~245pt posters with green ticks and no captions).
struct V2CollectionTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    let detail: ItemDetail
    @State private var width: CGFloat = 0

    var body: some View {
        if let collection = store.collection {
            VStack(alignment: .leading, spacing: 20) {
                V2CollectionHeader(collection: collection)
                grid(collection)
            }
        } else {
            Text(store.collectionFailed ? "Could not load this collection." : "Loading collection…")
                .font(.system(size: 13))
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func grid(_ collection: CollectionDetail) -> some View {
        let columns = V2LibraryColumns.count(for: width)
        let gap = CGFloat(V2LibraryGrid.spacing)
        let items = Array(repeating: GridItem(.flexible(), spacing: gap, alignment: .top), count: columns)
        return LazyVGrid(columns: items, alignment: .leading, spacing: 18) {
            ForEach(collection.parts, id: \.tmdbId) { part in
                V2CollectionCard(part: part, isHere: detail.tmdbId != nil && part.tmdbId == detail.tmdbId,
                                 artWidth: width > 0 ? V2LibraryColumns.posterWidth(for: width) : nil)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

/// "Part of a collection": the franchise, how much of it is in the library
/// in words ("2 of 3 in library · 1 missing") and as a one-ink track (filled
/// on disk, outlined in the library with no file, empty missing), then Add
/// all missing and Monitor.
private struct V2CollectionHeader: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page
    let collection: CollectionDetail
    @State private var monitorAll = true
    @State private var monitorPending = false

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }

    var body: some View {
        let missing = CollectionProgress.missingIds(collection)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Color.clear
                    .frame(width: 56, height: 84)
                    .overlay { DiscoverArt(url: TMDBImage.resized(collection.posterUrl, to: "w342")) }
                    .shelfPoster(radius: 10, shadow: false)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    // The page's small label ("Metadata via"), not v1's caps.
                    Text("Part of a collection")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                    Text(collection.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ink)
                        .accessibilityAddTraits(.isHeader)
                    track
                    Text(Self.summary(CollectionProgress(collection)))
                        .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(muted)
                }
            }
            HStack(spacing: 14) {
                if model.me?.can("add") ?? true, !missing.isEmpty {
                    Button(addTitle(missing), systemImage: "plus") {
                        store.addFromCollection(missing)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)
                }
                Spacer(minLength: 0)
                if canMonitor {
                    Toggle(isOn: Binding(get: { monitorAll }, set: { toggle($0) })) {
                        Label("Monitor collection", systemImage: monitorAll ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(monitorAll ? ink : muted)
                    }
                    .fixedSize()
                    .tint(Theme.primary)
                    .disabled(monitorPending || CollectionProgress.ownedLibraryIds(collection).isEmpty)
                }
            }
            if canMonitor {
                // What the toggle does (web MovieCollectionTab: it PATCHes the
                // films already in the library; new films are not watched yet).
                Text("Monitors every film from this collection that's in your library.")
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .v2CardStyle()
    }

    private var canMonitor: Bool { model.me?.can("edit") ?? true }

    /// "Add 24 Jump Street" for one missing film, "Add 3 missing" for more.
    private func addTitle(_ missing: [Int]) -> String {
        if missing.count == 1, let part = collection.parts.first(where: { $0.tmdbId == missing[0] }),
           let title = part.title, !title.isEmpty {
            return "Add \(title)"
        }
        return "Add \(missing.count) missing"
    }

    /// "2 of 3 in library · 1 missing"; a film in the library with no file
    /// yet adds "1 not downloaded".
    static func summary(_ p: CollectionProgress) -> String {
        let inLibrary = p.present + p.tracked
        var parts = ["\(inLibrary) of \(p.total) in library"]
        if p.tracked > 0 { parts.append("\(p.tracked) not downloaded") }
        if p.missing > 0 { parts.append("\(p.missing) missing") }
        return parts.joined(separator: " · ")
    }

    private var track: some View {
        HStack(spacing: 3) {
            ForEach(collection.parts, id: \.tmdbId) { part in
                let shape = Capsule()
                Group {
                    switch CollectionPartState(part) {
                    case .present: shape.fill(ink)
                    case .tracked: shape.strokeBorder(ink, lineWidth: 1.2)
                    case .missing: shape.fill(muted.opacity(0.25))
                    }
                }
                .frame(width: 22, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(CollectionProgress.railLabel(collection.parts))
    }

    private func toggle(_ on: Bool) {
        monitorAll = on
        monitorPending = true
        Task {
            await store.monitorCollection(on)
            monitorPending = false
        }
    }
}
