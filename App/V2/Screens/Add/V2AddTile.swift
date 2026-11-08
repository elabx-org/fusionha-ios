import SwiftUI
import FusionhaKit

/// One Add result as a v2 Library card (mock discover-add.js): clean 2:3 art,
/// the title, then what you own (its HD and 4K tickets) or the year and kind
/// with an Add (+) on that row. TMDB and TVDB results look the same (owner,
/// Add results mock 2026-11-08). Preview is the press-and-hold menu, so
/// nothing sits on the poster; TVDB results have no preview.
struct V2AddTile: View {
    let card: AddResultCard
    let pick: () -> Void
    let preview: (() -> Void)?
    @Environment(AppModel.self) private var model
    @Environment(\.pagePalette) private var page

    private var ink: Color { page?.ink ?? Theme.txt }
    private var muted: Color { page?.inkMuted ?? Theme.mut }
    private var owned: MediaItem? {
        guard let id = card.libraryItemId else { return nil }
        return model.library.first { $0.id == id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { PosterImage(url: TMDBImage.resized(card.posterUrl, to: "w500")) }
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
            if let preview { Button("Preview", systemImage: "eye", action: preview) }
            Button(card.inLibrary ? "Open" : "Add", systemImage: card.inLibrary ? "chevron.right" : "plus",
                   action: pick)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .modifier(V2AddPreviewAction(preview: preview))
    }

    private var caption: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TitleYear.display(card.title, nil).title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                Text(card.inLibrary ? "In library" : card.subline)
                    .font(.system(size: 11.5))
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !card.inLibrary {
                V2AddPlus(title: card.title, size: 28, action: pick).padding(-8)
            }
        }
        .padding(.horizontal, 1)
    }
}

/// The Add (+): the accent circle in a 44pt target.
struct V2AddPlus: View {
    let title: String
    var size: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Theme.primary, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle(scale: 0.9))
        .accessibilityLabel("Add \(title)")
    }
}

/// VoiceOver's Preview action, only where there is a preview.
struct V2AddPreviewAction: ViewModifier {
    let preview: (() -> Void)?

    func body(content: Content) -> some View {
        if let preview {
            content.accessibilityAction(named: "Preview", preview)
        } else {
            content
        }
    }
}
