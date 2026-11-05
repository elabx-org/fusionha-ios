import SwiftUI
import FusionhaKit

/// The title's ground across the stretch it is about to fill, while the
/// handle drags the seam toward full width.
///
/// The title keeps its split width for the whole drag (`FoldSeam`: no
/// column is re-laid out per frame) and only takes the full width when it
/// lands there, so the room between the seam and the title is painted with
/// the full-width ground it lands on. The ground keeps one size and is only
/// uncovered, and its last few points fade into the title's own edge.
struct V2SeamGround: View {
    let context: DuoSeamContext
    let x: CGFloat
    @Environment(AppModel.self) private var model

    /// How far the ground runs over the title's edge, fading out (under the
    /// page's 20pt text margin).
    private static let blend: CGFloat = 16

    var body: some View {
        let seam = max(0, x)
        let reach = context.rest + Self.blend - seam
        if reach > Self.blend {
            PageGround(palette: palette, recipe: .page)
                .frame(width: context.width)
                .offset(x: -seam)
                .frame(width: reach, alignment: .leading)
                .mask {
                    HStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: Self.blend)
                    }
                    .ignoresSafeArea()
                }
                .clipped()
                .offset(x: seam)
                .frame(maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The open title's palette, as its page paints it (`V2TitleView`).
    private var palette: PagePalette {
        let tokens = Theme.palette
        guard let id = model.presentedItem?.id else { return .tokens(tokens) }
        let store = model.detailStore(for: id)
        let seed = model.library.first { $0.id == id }
        let art = PageArtSource.url(backdrop: store.detail?.backdropUrl ?? seed?.backdropUrl,
                                    poster: store.detail?.posterUrl ?? seed?.posterUrl)
        guard let art, let colors = ArtPaletteExtractor.shared.cached(art) else { return .tokens(tokens) }
        return PagePalette.art(colors, tokens: tokens)
    }
}
