import SwiftUI
import FusionhaKit

/// The collection on v2's Overview: its name and "2 of 3 in library ›" into
/// the Collection tab, over the films as Library cards (`V2CollectionCard`)
/// at the Library grid's poster size (`V2LibraryColumns`).
struct V2CollectionRail: View {
    @Environment(DetailStore.self) private var store
    @Environment(\.pagePalette) private var page
    let collection: CollectionDetail
    let detail: ItemDetail

    var body: some View {
        if !collection.parts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(collection.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(page?.ink ?? Theme.txt)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    Button {
                        withAnimation { store.tab = .collection }
                    } label: {
                        Label(link, systemImage: "chevron.right")
                            .labelStyle(TrailingIconLabel())
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(page?.inkMuted ?? Theme.mut)
                    .buttonStyle(.plain)
                }
                .padding(.top, 22)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: CGFloat(V2LibraryGrid.spacing)) {
                        ForEach(collection.parts, id: \.tmdbId) { part in
                            V2CollectionCard(part: part, isHere: part.tmdbId == detail.tmdbId)
                                .containerRelativeFrame(.horizontal) { width, _ in
                                    V2LibraryColumns.posterWidth(for: width)
                                }
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var link: String {
        let p = CollectionProgress(collection)
        return "\(p.present + p.tracked) of \(p.total) in library"
    }
}

/// Title, then the icon after it ("2 of 3 in library ›").
private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}
