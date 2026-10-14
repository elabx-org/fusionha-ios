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
            .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.04))))
            .overlay(shape.strokeBorder(ring ?? Theme.txt.opacity(0.07), lineWidth: ringWidth))
            .shadow(color: .black.opacity(shadow ? 0.9 : 0), radius: shadow ? 11 : 0, y: shadow ? 12 : 0)
    }
}

