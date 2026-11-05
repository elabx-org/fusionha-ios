import SwiftUI
import FusionhaKit

/// The ground across the room the seam opens while the handle moves it, as
/// no column is re-laid out mid-drag (`FoldSeam`):
/// - toward full width (from the split): the title keeps its split width,
///   so the room between the seam and the title gets the full-width ground
///   it lands on, its last few points fading into the title's own edge;
/// - toward close: the list keeps its split width, so the room between the
///   list and the title gets the list pane's ground.
/// Each ground keeps one size and is only uncovered.
struct V2SeamGround: View {
    let context: DuoSeamContext
    let x: CGFloat
    @Environment(AppModel.self) private var model

    /// How far the ground runs over the title's edge, fading out (under the
    /// page's 20pt text margin).
    private static let blend: CGFloat = 16

    var body: some View {
        let seam = max(0, x)
        if !context.fullWidth, context.rest + Self.blend - seam > Self.blend {
            uncovered(.page, from: seam, width: context.rest + Self.blend - seam, fades: true)
        } else if seam > context.rest {
            uncovered(.listPane, from: context.rest, width: seam - context.rest, fades: false)
        }
    }

    /// `recipe`'s ground laid out across the whole display, shown from
    /// `start` for `width` points.
    private func uncovered(_ recipe: PageGround.Recipe, from start: CGFloat, width: CGFloat, fades: Bool) -> some View {
        PageGround(palette: palette, recipe: recipe)
            .frame(width: context.width)
            .offset(x: -start)
            .frame(width: width, alignment: .leading)
            .mask {
                HStack(spacing: 0) {
                    Rectangle()
                    if fades {
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: Self.blend)
                    }
                }
                .ignoresSafeArea()
            }
            .clipped()
            .offset(x: start)
            .frame(maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
