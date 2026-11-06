import SwiftUI
import FusionhaKit

/// One film on the v2 Collection tab, as the Library shows it: a film in the
/// library is its Library card (`V2PosterCard`: clean art, the title, its
/// HD/4K badges; a tap opens it); one that isn't keeps the same art and
/// caption with an outline HD badge (missing) and an Add button, the
/// collection's own add (`DetailStore.addFromCollection`). The title open
/// now has a quiet ring.
struct V2CollectionCard: View {
    @Environment(AppModel.self) private var model
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    let part: CollectionPart
    let isHere: Bool
    var artWidth: CGFloat?

    private var item: MediaItem? {
        guard part.owned == true, let id = part.libraryItemId else { return nil }
        return model.library.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let item {
                V2PosterCard(item: item, artWidth: artWidth, showsMeta: false)
            } else {
                standIn
            }
        }
        .overlay(alignment: .top) {
            if isHere {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(page?.ink.opacity(0.55) ?? Theme.txt.opacity(0.55), lineWidth: 2)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAddTraits(isHere ? .isSelected : [])
    }

    /// A film not in the model's library (missing, or not loaded yet).
    private var standIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openOwned) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay { DiscoverArt(url: TMDBImage.resized(part.posterUrl, to: "w500")) }
                    .shelfPoster(radius: 12)
            }
            .buttonStyle(DiscoverPressStyle())
            .disabled(part.libraryItemId == nil)
            Text(part.title ?? "")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(part.owned == true ? (page?.ink ?? Theme.txt) : (page?.inkMuted ?? Theme.mut))
                .lineLimit(1)
                .padding(.top, 7)
            HStack(spacing: 6) {
                EditionTicketPair(hd: badges.hd, uhd: badges.uhd)
                if part.owned != true, model.me?.can("add") ?? true {
                    Button("Add") { store.addFromCollection([part.tmdbId]) }
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Theme.accentText)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add \(part.title ?? "film") to library")
                }
            }
            .padding(.top, 5)
        }
    }

    /// Owned tiers filled; a film with none yet, or not in the library, an
    /// outline HD (missing).
    private var badges: (hd: EditionBadgeState?, uhd: EditionBadgeState?) {
        let tiers = part.owned == true ? (part.tiers ?? []) : []
        if tiers.isEmpty { return (.missing, nil) }
        return (tiers.contains(.hd) ? .onDisk : nil, tiers.contains(.uhd) ? .onDisk : nil)
    }

    private func openOwned() {
        guard let id = part.libraryItemId, !isHere else { return }
        model.open(id)
    }
}
