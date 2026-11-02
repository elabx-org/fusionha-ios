import SwiftUI
import FusionhaKit

/// The split title's header: the art as a band across both pages, the
/// display-face title and the meta line in white on its darkened edge (as on
/// the hero, in every theme). The art runs up under the bar and under the
/// system column; the text stays 20 pt in.
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
        .background { art }
    }

    private var art: some View {
        ZStack {
            PosterImage(url: ItemDetailArt.hero(backdrop: detail.backdropUrl, poster: detail.posterUrl))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            LinearGradient(stops: [
                .init(color: Theme.scrim.opacity(0.3), location: 0),
                .init(color: Theme.scrim.opacity(0.2), location: 0.35),
                .init(color: Theme.scrim.opacity(0.78), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
        }
        .clipped()
        .ignoresSafeArea(.container, edges: [.top, .horizontal])
        .accessibilityHidden(true)
    }
}
