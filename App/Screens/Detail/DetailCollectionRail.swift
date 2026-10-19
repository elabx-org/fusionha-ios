import SwiftUI
import FusionhaKit

/// The inline Collection rail on a movie page (DetailRailStack's
/// CollectionRail): the franchise's posters with the ownership badge, the
/// year under each, and a "N of M ›" link into the Collection tab. A tap opens
/// the tab; a long press offers "Add to library" on a missing film.
struct DetailCollectionRail: View {
    @Environment(DetailStore.self) private var store
    @Environment(AppModel.self) private var model
    let collection: CollectionDetail

    private var canAdd: Bool { model.me?.can("add") ?? true }

    var body: some View {
        if !collection.parts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(collection.name)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.txt)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Button(CollectionProgress(collection).railLink, action: openTab)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open the collection, \(CollectionProgress.railLabel(collection.parts))")
                }
                .padding(.top, 22)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(collection.parts, id: \.tmdbId) { part in
                            card(part)
                                .containerRelativeFrame(.horizontal) { width, _ in DetailSimilarRail.cardWidth(width) }
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private func openTab() {
        withAnimation { store.tab = .collection }
    }

    private func card(_ part: CollectionPart) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: openTab) {
                CollectionPartArt(part: part)
            }
            .buttonStyle(DiscoverPressStyle())
            .accessibilityLabel("Open \(part.title ?? "film")")
            .contextMenu {
                if part.owned == true {
                    Button("In your library", systemImage: "checkmark") {}.disabled(true)
                } else if canAdd {
                    Button("Add to library", systemImage: "plus") {
                        store.addFromCollection(CollectionProgress.addIds(for: part, in: collection))
                    }
                }
            }
            Group {
                if let year = part.year { Text(verbatim: "\(year)") } else { Text(part.title ?? "") }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.mut)
            .lineLimit(1)
        }
    }
}

/// A collection film's 2:3 poster with its three-state badge (green check on
/// disk, amber caution tracked with no file, none when not owned).
struct CollectionPartArt: View {
    let part: CollectionPart
    var isHere = false

    var body: some View {
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { DiscoverArt(url: TMDBImage.resized(part.posterUrl, to: "w500")) }
            .shelfPoster()
            .overlay(alignment: .topTrailing) {
                switch CollectionPartState(part) {
                case .present: PosterStatusBadge(kind: .inLibrary).padding(6)
                case .tracked: PosterStatusBadge(kind: .caution).padding(6)
                case .missing: EmptyView()
                }
            }
            .overlay {
                if isHere {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.accentText, lineWidth: 2)
                }
            }
    }
}
