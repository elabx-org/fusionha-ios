import SwiftUI
import FusionhaKit

// MARK: - Complete your collections

struct CollectionsRail: View {
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
                    Image(systemName: "square.grid.2x2").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.i2)
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

struct CollectionCard: View {
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

struct CollectionsSkeleton: View {
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
