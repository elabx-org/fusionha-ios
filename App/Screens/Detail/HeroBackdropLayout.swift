import SwiftUI
import FusionhaKit

/// Where the title page's hero backdrop (`DetailHeroBackdrop`) puts its art
/// and washes, in points from the top of the header.
struct HeroBackdropLayout: Equatable {
    enum Style: Equatable {
        /// The single column's hero: the full art above the title.
        case hero
        /// The open Duo's band: a lighter shade over a shorter title block.
        case band
    }

    var style: Style = .hero
    /// The art's darkened edge: the white title block ends 14 to 18 pt above it.
    var edge: CGFloat
    /// Where the dark title edge has handed over to the ground wash: just
    /// above the first body text under the title (the tagline).
    var handover: CGFloat
    /// Where the art has faded out under the text column: the top of Versions.
    var foot: CGFloat
    /// The far side's foot (the open Duo's right page; nil: `foot`).
    var farFoot: CGFloat?
    /// The text column's trailing x (nil: the full width). The art's fades
    /// and the ground wash split here.
    var column: CGFloat?
    /// How far the title's dark shade reaches (nil: `column`). On the open
    /// Duo a long title runs past the left page and keeps its shade.
    var shadeColumn: CGFloat?
    /// The far side holds text too (the open Duo's tabs page), so it keeps
    /// the ground wash; otherwise it stays clear and the art reads there.
    var farWash = true
    /// The header's top in global coordinates, when the art runs up under
    /// the bar above it.
    var originY: CGFloat?

    /// The ground wash lets go over this much past the foot, where the art
    /// has already gone, so it meets the page's ground unseen.
    static let tail: CGFloat = 72

    var lowest: CGFloat { max(foot, farFoot ?? foot) }

    /// The hand-over ends just above the tagline: the version strip's chips
    /// sit on their own card plates inside it, so it can run long and soft.
    /// `stripEnd` is the facts block's strip bottom (0 without chips).
    static func handover(edge: CGFloat, stripEnd: CGFloat) -> CGFloat {
        edge + min(max(stripEnd + 10, 40), 100)
    }

    /// A single wide column (iPad, the open Duo's title beside the list):
    /// the ground wash follows the text column and the far side stays clear.
    static func textColumn(width: CGFloat, gutter: CGFloat) -> CGFloat? {
        let column = gutter + CGFloat(ReadableWidth.max) + 40
        return width > column + 160 ? column : nil
    }
}

/// What the title page's header measures for its backdrop.
struct HeroHeaderMetrics: Equatable {
    /// The version strip's bottom, from the top of the facts block.
    var stripEnd: CGFloat = 44
    /// The top of Versions in the page's content.
    var versionsTop: CGFloat = 0
}

/// The open Duo's left page as it scrolls: the top of Versions on screen
/// (global). Only the band's backdrop reads it, so scrolling redraws that
/// alone.
@Observable
final class HeroScrollTracker {
    var versionsOnScreen: CGFloat?
}

/// Art URLs whose hero has already eased in (the loading shell's), so the
/// loaded page does not replay the zoom.
@MainActor
enum HeroArtReveal {
    static var shown = Set<URL>()
}
