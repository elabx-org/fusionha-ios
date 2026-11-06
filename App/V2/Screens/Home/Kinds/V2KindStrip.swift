import SwiftUI
import FusionhaKit

/// A kind's row on the phone and the folded Duo (Home mock): "Movies" with
/// its count ("2,636 ›", which opens All titles on that kind), then its
/// newest posters as a sideways strip with their tickets.
struct V2KindStrip: View {
    let kind: V2HomeKind
    let gutter: CGFloat
    let open: () -> Void
    @Environment(\.motionEnabled) private var motion

    static let poster: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            V2KindHead(kind: kind, open: open)
                .padding(.horizontal, gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(Array(kind.items.enumerated()), id: \.element.id) { i, item in
                        V2PosterCard(item: item, artWidth: Self.poster, showsMeta: false)
                            .frame(width: Self.poster)
                            .landing(i, motion: motion)
                    }
                }
            }
            .contentMargins(.horizontal, gutter, for: .scrollContent)
            .scrollClipDisabled()
        }
    }
}

/// A kind's heading: its name, and its count as the way into All titles.
struct V2KindHead: View {
    let kind: V2HomeKind
    let open: () -> Void

    var body: some View {
        V2HomeSectionHead(title: kind.kind.plural, action: kind.count.formatted(), chevron: true,
                          accessibilityAction: "All \(kind.count.formatted()) \(kind.kind.plural.lowercased())",
                          tap: open)
    }
}
