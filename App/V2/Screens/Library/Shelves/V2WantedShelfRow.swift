import SwiftUI
import FusionhaKit

/// One wanted shelf (mock kit `shelfHead` + a poster rail): the name at
/// 21pt bold with its title count beside it, as the grid's own heading
/// ("All titles 843"), then the posters running under the page gutters to
/// the screen edge, clean art with the title and tickets under it
/// (`V2PosterCard`, the same 112pt as Home's kind strips). Content, not glass.
struct V2WantedShelfRow: View {
    let shelf: WantedShelf
    let gutter: CGFloat
    @Environment(\.motionEnabled) private var motion
    @Environment(\.pagePalette) private var page

    static let poster: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            head
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(Array(shelf.items.enumerated()), id: \.element.id) { i, item in
                        V2PosterCard(item: item, artWidth: Self.poster, showsMeta: false)
                            .frame(width: Self.poster)
                            .landing(i, motion: motion)
                    }
                }
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollClipDisabled()
            // The page pads its content by the gutter; the rail runs past it.
            .padding(.horizontal, -gutter)
        }
    }

    private var head: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(shelf.title)
                .font(.system(size: 21, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(page?.ink ?? Theme.txt)
            Text(shelf.count.formatted())
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(page?.inkMuted ?? Theme.mut)
                .contentTransition(.numericText())
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shelf.title), \(shelf.count) \(shelf.count == 1 ? "title" : "titles")")
        .accessibilityAddTraits(.isHeader)
    }
}
