import SwiftUI
import FusionhaKit

/// The split title's header: the display-face title and the meta line in
/// white on the art's darkened edge (as on the hero, in every theme). The art
/// itself is `DetailSpreadBody`'s backdrop: it runs behind the band across
/// both pages, up under the bar and the system column, and on down the left
/// page behind the facts; the text stays 20 pt in.
struct DetailSpreadBand: View {
    let detail: ItemDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DetailHeroTitle(detail: detail, size: 36, lines: 1)
            HeroMetaLine(detail: detail, onArt: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .bottomLeading)
    }
}
