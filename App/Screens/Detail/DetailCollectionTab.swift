import SwiftUI
import FusionhaKit

/// The movie Collection tab (MovieCollectionTab.tsx): the franchise header
/// (thumb, "Part of a collection", name, completion rail and counts, Add all
/// missing, Monitor) over a poster grid with each film's ownership badge and
/// owned tiers.
struct CollectionTab: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let detail: ItemDetail

    var body: some View {
        if let collection = store.collection {
            VStack(alignment: .leading, spacing: 20) {
                CollectionTabHeader(collection: collection)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .top)], spacing: 16) {
                    ForEach(collection.parts, id: \.tmdbId) { part in
                        CollectionFilmTile(part: part, isHere: detail.tmdbId != nil && part.tmdbId == detail.tmdbId,
                                           canAdd: model.me?.can("add") ?? true) {
                            store.addFromCollection([part.tmdbId])
                        }
                    }
                }
            }
        } else {
            Text(store.collectionFailed ? "Could not load this collection." : "Loading collection…")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CollectionTabHeader: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let collection: CollectionDetail
    @State private var monitorAll = true
    @State private var monitorPending = false

    var body: some View {
        let progress = CollectionProgress(collection)
        let missing = CollectionProgress.missingIds(collection)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Color.clear
                    .frame(width: 56, height: 84)
                    .overlay { DiscoverArt(url: TMDBImage.resized(collection.posterUrl, to: "w342")) }
                    .shelfPoster(shadow: false)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Part of a collection", systemImage: "square.grid.2x2")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.dim)
                    Text(collection.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.txt)
                        .accessibilityAddTraits(.isHeader)
                    CollectionCompletionRail(parts: collection.parts)
                    counts(progress)
                }
            }
            HStack(spacing: 14) {
                if model.me?.can("add") ?? true {
                    Button {
                        store.addFromCollection(missing)
                    } label: {
                        Label(missing.isEmpty ? "Nothing missing" : "Add all missing (\(missing.count))", systemImage: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 15)
                            .frame(height: 36)
                            .background(Theme.i1, in: Capsule())
                    }
                    .buttonStyle(DetailPressStyle())
                    .disabled(missing.isEmpty)
                    .opacity(missing.isEmpty ? 0.5 : 1)
                }
                Spacer(minLength: 0)
                if model.me?.can("edit") ?? true {
                    Toggle(isOn: Binding(get: { monitorAll }, set: { toggle($0) })) {
                        Label("Monitor", systemImage: monitorAll ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(monitorAll ? Theme.txt : Theme.mut)
                    }
                    .fixedSize()
                    .tint(Theme.i1)
                    .disabled(monitorPending || CollectionProgress.ownedLibraryIds(collection).isEmpty)
                    .accessibilityLabel("Monitor whole collection")
                }
            }
        }
        .padding(16)
        .detailCard(radius: 16, shadow: false)
    }

    private func counts(_ p: CollectionProgress) -> some View {
        var text = Text("\(p.present)").foregroundColor(Theme.txt)
        if p.tracked > 0 { text = text + Text(" · ") + Text("\(p.tracked) tracked").foregroundColor(Theme.miss) }
        if p.missing > 0 { text = text + Text(" · ") + Text("\(p.missing) missing").foregroundColor(Theme.miss) }
        return (text + Text(" of \(p.total)"))
            .font(.system(size: 12, weight: .bold).monospacedDigit())
            .foregroundStyle(Theme.mut)
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

/// The segmented completion rail: one solid segment per film (present done,
/// tracked miss, missing an empty outline).
struct CollectionCompletionRail: View {
    let parts: [CollectionPart]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(parts, id: \.tmdbId) { part in
                let shape = RoundedRectangle(cornerRadius: 3)
                Group {
                    switch CollectionPartState(part) {
                    case .present: StatusSwatch(token: .done, shape: shape, color: Theme.done)
                    case .tracked: StatusSwatch(token: .miss, shape: shape, color: Theme.miss)
                    case .missing: shape.strokeBorder(Theme.line)
                    }
                }
                .frame(width: 22, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(CollectionProgress.railLabel(parts))
    }
}

/// One film in the tab's grid: the badged poster, a persistent ＋ on a film not
/// yet in the library, then title, year and the owned tiers under the art.
private struct CollectionFilmTile: View {
    let part: CollectionPart
    let isHere: Bool
    let canAdd: Bool
    let add: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CollectionPartArt(part: part, isHere: isHere)
                .overlay(alignment: .bottomTrailing) {
                    if part.owned != true && canAdd {
                        Button(action: add) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .frame(width: 40, height: 40)
                                .background(Theme.i1, in: Circle())
                        }
                        .buttonStyle(DetailPressStyle())
                        .padding(8)
                        .accessibilityLabel("Add \(part.title ?? "film") to library")
                    }
                }
            Text(part.title ?? "").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.txt).lineLimit(1)
            if let year = part.year {
                Text(verbatim: "\(year)").font(.system(size: 12)).foregroundStyle(Theme.mut)
            }
            meta
        }
    }

    @ViewBuilder
    private var meta: some View {
        if part.owned == true {
            if let tiers = part.tiers, !tiers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tiers, id: \.self) { DetailTierChip(tier: $0) }
                }
            } else {
                Text("Tracked, no version yet").font(.system(size: 11.5)).foregroundStyle(Theme.miss)
            }
        } else {
            Text("Not in library").font(.system(size: 11.5)).foregroundStyle(Theme.dim)
        }
    }
}
