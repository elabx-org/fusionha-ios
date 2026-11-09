import SwiftUI
import FusionhaKit

/// The open title's ground behind the shell on the flat open Duo
/// (`TitlePageOverride.shellGround`): what shows wherever the title's page
/// does not reach while it lands or swaps (the system column, the display's
/// foot), so they take the title's colours from its first frame instead of
/// the plain ground (owner, build 805: the colour reached the column late).
/// The palette is the one the page paints (`V2TitleView`), already cached
/// when the slide-in starts (`V2OpenReadiness`); the art stays on the page.
struct V2TitleShellGround: View {
    let itemId: Int
    @Environment(AppModel.self) private var model

    var body: some View {
        PageGround(palette: palette, recipe: .page)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var palette: PagePalette { Self.look(model, itemId).palette }

    /// The open title's palette and art, as its page paints them (`V2TitleView`).
    static func look(_ model: AppModel, _ itemId: Int) -> (palette: PagePalette, art: URL?) {
        let tokens = Theme.palette
        let store = model.detailStore(for: itemId)
        let seed = model.library.first { $0.id == itemId }
        let art = PageArtSource.url(backdrop: store.detail?.backdropUrl ?? seed?.backdropUrl,
                                    poster: store.detail?.posterUrl ?? seed?.posterUrl)
        guard let art, let colors = ArtPaletteExtractor.shared.cached(art) else { return (.tokens(tokens), art) }
        return (PagePalette.art(colors, tokens: tokens), art)
    }
}
