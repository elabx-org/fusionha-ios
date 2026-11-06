import SwiftUI
import FusionhaKit

// v2's Add-collection page (plan S11, mock discover-add.js `collection`):
// the collection's art header with its counts and one-ink lane, Select all
// missing / Deselect all, the films as Library-size posters (owned ones
// dimmed with their tickets, missing ones selectable), then how to add
// them on W1 cards. The calls and the edition config stay v1's.

/// The art header: name, "11 films · 5 in your library · 6 missing", lane.
struct CollectionSheetHeader: View {
    let name: String
    let backdrop: String?
    let total: Int
    let owned: Int
    let missing: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(white: 0.1)
            PosterImage(url: TMDBImage.resized(backdrop, to: "w780"))
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.78)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 5) {
                Text(name)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.3)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("\(total) films · \(owned) in your library · \(missing) missing")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                CollectionLane(have: owned, of: total)
                    .frame(width: 200)
                    .padding(.top, 3)
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }
}

/// An amount as one ink on an empty track (CLAUDE.md rails rule).
struct CollectionLane: View {
    let have: Int
    let of: Int

    var body: some View {
        GeometryReader { geo in
            let share = of > 0 ? min(1, CGFloat(have) / CGFloat(of)) : 0
            Capsule().fill(.white.opacity(0.22))
                .overlay(alignment: .leading) {
                    Capsule().fill(.white).frame(width: geo.size.width * share)
                }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// The films as posters; tapping a missing one selects or clears it.
struct CollectionPartGrid: View {
    let parts: [CollectionPart]
    @Binding var selected: Set<Int>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 11, alignment: .top)],
                  alignment: .leading, spacing: 14) {
            ForEach(parts, id: \.tmdbId) { part in
                CollectionPartTile(part: part, selected: selected.contains(part.tmdbId)) {
                    if selected.contains(part.tmdbId) { selected.remove(part.tmdbId) } else { selected.insert(part.tmdbId) }
                }
            }
        }
    }
}

private struct CollectionPartTile: View {
    let part: CollectionPart
    let selected: Bool
    let toggle: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.browseLook) private var look
    @Environment(\.pagePalette) private var page

    private var owned: Bool { part.owned == true }
    private var item: MediaItem? { part.libraryItemId.flatMap { id in model.library.first { $0.id == id } } }
    private var inks: BrowseInks { BrowseInks(page: page) }

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 6) {
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay { PosterImage(url: TMDBImage.resized(part.posterUrl, to: "w342")) }
                    .shelfPoster(radius: 10, ring: selected ? Theme.primary : nil, ringWidth: selected ? 2.5 : 0.5)
                    .overlay(alignment: .topTrailing) { if !owned { mark } }
                Text(part.title ?? "TMDB #\(part.tmdbId)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(inks.ink)
                    .lineLimit(1)
                caption
            }
            .opacity(owned ? 0.6 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(owned)
        .accessibilityLabel(part.title ?? "Film")
        .accessibilityValue(owned ? "In your library" : selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var caption: some View {
        if owned, let item, let look {
            look.tickets(item)
        } else {
            Text(owned ? "In your library" : [part.year.map(String.init), "missing"].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 11.5))
                .foregroundStyle(inks.muted)
                .lineLimit(1)
        }
    }

    private var mark: some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 20, weight: .semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, selected ? Theme.primary : .black.opacity(0.35))
            .padding(6)
            .accessibilityHidden(true)
    }
}
