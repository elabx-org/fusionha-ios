import SwiftUI
import FusionhaKit

/// The Library home's poster shelf (mock browse.js, kit `shelfHead`): its
/// header is a menu of sources (`V2LibraryShelfSource`) with a subtitle
/// ("Last added: 64 Zoo Lane, 1 Nov" for Recently added), an ellipsis menu
/// holds "See all" (the grid takes the same titles) and the sources, and
/// the posters scroll sideways (running on under the folded Duo's column).
/// Hidden when no source has titles.
struct V2LibraryShelf: View {
    let home: V2LibraryHome
    @Binding var source: V2LibraryShelfSource
    /// The page's width (the poster size follows the device).
    let paneWidth: CGFloat
    let seeAll: (V2LibraryShelfSource) -> Void
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The chosen source, else the first one with titles.
    private var shown: V2LibraryShelfSource? {
        let sources = home.sources
        return sources.contains(source) ? source : sources.first
    }

    private var wide: Bool { paneWidth >= 700 }
    /// The mock's poster widths: flat open 94, folded Duo 78, phone 84.
    private var posterWidth: CGFloat {
        if wide { return 94 }
        return OuterDisplay.isFoldedDuo(sizeClass: sizeClass) ? 78 : 84
    }

    var body: some View {
        if let shown, let items = home.shelves[shown] {
            let w = posterWidth
            VStack(alignment: .leading, spacing: 12) {
                header(shown, items: items)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: wide ? 16 : 14) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            V2PosterCard(item: item, artWidth: w, showsMeta: false)
                                .frame(width: w)
                                .landing(i, motion: motion)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private func header(_ shown: V2LibraryShelfSource, items: [MediaItem]) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Menu {
                    sourcePicker
                } label: {
                    HStack(spacing: 5) {
                        Text(shown.title)
                            .font(.system(size: 21, weight: .bold))
                            .tracking(-0.4)
                            .foregroundStyle(page?.ink ?? Theme.txt)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    }
                }
                .accessibilityLabel("Shelf, \(shown.title)")
                .accessibilityAddTraits(.isHeader)
                Text(subtitle(shown, items: items))
                    .font(.system(size: 13))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Menu {
                Button("See all", systemImage: "square.grid.2x2") { seeAll(shown) }
                sourcePicker
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(shown.title) options")
        }
        .sensoryFeedback(.selection, trigger: source)
    }

    private var sourcePicker: some View {
        Picker("Shelf", selection: $source) {
            ForEach(home.sources) { s in
                Label(s.title, systemImage: s.systemImage).tag(s)
            }
        }
    }

    /// Recently added names its newest title and day; the others count.
    private func subtitle(_ shown: V2LibraryShelfSource, items: [MediaItem]) -> String {
        if shown == .recentlyAdded, let first = items.first,
           let added = Format.timestamp(first.addedAt) ?? Format.day(first.addedAt) {
            return "Last added: \(first.title), \(added.formatted(.dateTime.day().month(.abbreviated)))"
        }
        return "\(items.count) \(items.count == 1 ? "title" : "titles")"
    }
}
