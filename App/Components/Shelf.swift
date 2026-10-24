import SwiftUI

// MARK: Shelf (redesign)
//
// Posters are objects on a lit shelf: clipped to a small radius, a highlight
// on the top edge, a faint hairline, and a deep shadow below. Nothing is ever
// drawn on the art.

extension View {
    /// The lit-poster finish. `ring` replaces the hairline (selection,
    /// attention); `shadow` is off for thumbnails inside rows.
    func shelfPoster(radius: CGFloat = 8, ring: Color? = nil, ringWidth: CGFloat = 0.5, shadow: Bool = true) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return background(Theme.card)
            .clipShape(shape)
            // The top-edge highlight as a gradient stroke, not a masked stroke
            // (a mask is an offscreen pass per poster while a grid scrolls).
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top,
                                                       endPoint: .init(x: 0.5, y: 0.04)), lineWidth: 1))
            .overlay(shape.strokeBorder(ring ?? Theme.txt.opacity(0.07), lineWidth: ringWidth))
            .background { if shadow { ShelfShadow(radius: radius) } }
    }
}

/// The shelf's deep shadow below a poster (`Theme.shelfShadow`, blur 11,
/// dropped 12): a pre-blurred nine-slice image under the card instead of a
/// `.shadow`, which re-rendered the whole card offscreen every frame.
private struct ShelfShadow: View {
    let radius: CGFloat

    var body: some View {
        let made = ArtBlurCache.shared.shadow(radius: radius, isLight: Theme.isLight)
        let cap = made.bleed + radius + 1
        Image(uiImage: made.image)
            .resizable(capInsets: EdgeInsets(top: cap, leading: cap, bottom: cap, trailing: cap), resizingMode: .stretch)
            .padding(-made.bleed)
            .offset(y: 12)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
