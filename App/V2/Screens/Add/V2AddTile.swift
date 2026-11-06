import SwiftUI
import FusionhaKit

/// One Add result as a v2 Library card (mock discover-add.js): clean 2:3 art,
/// the title, then what you own (its HD and 4K tickets) or the year and kind
/// with an Add (+) on that row. Preview is the press-and-hold menu, so
/// nothing sits on the poster.
struct V2AddTile: View {
    let result: MediaSearchResult
    let pick: () -> Void
    let preview: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    /// The library's own item when the result is already there.
    private var owned: MediaItem? {
        guard result.inLibrary, let id = result.libraryItemId else { return nil }
        return model.library.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { PosterImage(url: TMDBImage.resized(result.posterUrl, to: "w500")) }
                .shelfPosterPlated(radius: 12)
            if let owned {
                V2PosterCaption(item: owned).padding(.horizontal, 1)
            } else {
                caption
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: pick)
        .contextMenu {
            Button("Preview", systemImage: "eye", action: preview)
            Button(result.inLibrary ? "Open" : "Add", systemImage: result.inLibrary ? "arrow.up.right" : "plus",
                   action: pick)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Preview", preview)
    }

    private var subline: String {
        ([result.year.map { String($0) }, kindName(result)] as [String?]).compactMap { $0 }.joined(separator: " · ")
    }

    private var caption: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TitleYear.display(result.title, nil).title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(result.inLibrary ? "In library" : subline)
                    .font(.system(size: 11.5))
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !result.inLibrary {
                Button(action: pick) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 28, height: 28)
                        .background(Theme.primary, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle(scale: 0.9))
                .padding(-8)
                .accessibilityLabel("Add \(result.title)")
            }
        }
        .padding(.horizontal, 1)
    }
}
