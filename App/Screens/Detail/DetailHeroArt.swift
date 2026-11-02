import SwiftUI
import FusionhaKit

/// The hero's height (owner-approved title page, 2026-10-23): the art's
/// darkened edge, where the white title block sits. The art itself is
/// `DetailHeroBackdrop`, behind the hero, the loading shell and the open
/// Duo's band alike.
enum DetailHeroArt {
    /// 44% of the container, at least 330 and at most 480, so the version
    /// strip (D4) and the start of the page sit above the fold on a regular
    /// iPhone and the folded Duo. The 330 floor gives way to 55% of a short
    /// container (the Duo's outer display held sideways, 466pt tall) so the
    /// heading and actions stay in view (D3).
    static func height(for length: CGFloat) -> CGFloat {
        min(max(length * 0.44, min(330, length * 0.55)), 480)
    }
}

extension ItemDetailArt {
    /// The hero prefers the textless backdrop: a portrait poster carries its
    /// printed title, which ghosted behind ours (the "king" behind "Breaking Bad").
    static func hero(backdrop: String?, poster: String?) -> URL? {
        TMDBImage.resized(backdrop ?? poster, to: "original")
    }
}

/// Art choices shared by the title page's hero, loading shell and ambient.
enum ItemDetailArt {}
