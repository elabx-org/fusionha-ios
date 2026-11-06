import SwiftUI
import FusionhaKit

/// v2's dress for the shared Add title flow (`AddLookOverride`, set in
/// `V2RootView`): Find on the list pane's ground, the setup on the pick's
/// art ground with W1 cards, results as Library cards (`V2AddTile`), the
/// versions in one ink, Find | setup across the flat open Duo (mock
/// discover-add.js: Find about a third, the setup the rest), and the new
/// title opened once added.
enum V2AddLook {
    static let override = AddLookOverride(
        findGround: { content in
            AnyView(content.v2PageGround(art: nil, recipe: .listPane, showsArt: false))
        },
        setupGround: { content, backdrop, poster in
            // The setup draws its own hero art; the ground takes its colours.
            AnyView(content.v2PageGround(art: PageArtSource.url(backdrop: backdrop, poster: poster),
                                         recipe: .page, showsArt: false))
        },
        card: { content, radius in AnyView(content.v2CardStyle(padding: 0, radius: radius)) },
        tile: { result, pick, preview in AnyView(V2AddTile(result: result, pick: pick, preview: preview)) },
        // The Library grid's poster (`V2LibraryColumns`: nearest 130pt).
        tileWidth: 112...148,
        flatSpread: panes(width:height:))

    /// Find | setup on a page with no fold through it: wide and tall enough
    /// for both (the flat open Duo, an iPad), Find about a third.
    static func panes(width: Double, height: Double) -> FoldColumns.Panes? {
        guard width >= 760, height >= 480 else { return nil }
        let lead = min(max((width * 0.36).rounded(), 300), 400)
        return FoldColumns.panes(width: width, fold: lead...lead, minLead: 300, minTrail: 420, gutter: 0)
    }
}
