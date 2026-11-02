import SwiftUI
import FusionhaKit

/// The split title's header: the display-face title and the meta line in
/// white on the art's darkened edge (as on the hero, in every theme). The art
/// itself is `DetailSpreadBody`'s backdrop: it runs behind the band across
/// both pages, up under the bar and the system column, and on down both
/// pages; the text stays 20 pt in. `onTextWidth` reports how far the text
/// runs, so a long title keeps its dark shade past the left page.
struct DetailSpreadBand: View {
    let detail: ItemDetail
    var onTextWidth: (CGFloat) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DetailHeroTitle(detail: detail, size: 36, lines: 1)
            HeroMetaLine(detail: detail, onArt: true)
        }
        .padding(.horizontal, 20)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onTextWidth($0) }
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }
}
