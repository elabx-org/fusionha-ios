import SwiftUI
import FusionhaKit

/// One card of the open Duo's Coming up: clean art only (nothing on it),
/// the 2:3 poster for Posters or the 16:9 backdrop for Backdrops (the
/// poster when a title has no backdrop). Content, not glass.
struct V2ComingUpWideCard: View {
    let card: V2ComingUpCard
    let size: CGSize
    let backdrop: Bool
    let tap: () -> Void

    private var art: URL? {
        let item = card.item
        return backdrop
            ? TMDBImage.resized(item.backdropUrl ?? item.posterUrl, to: "w780")
            : TMDBImage.resized(item.posterUrl ?? item.backdropUrl, to: "w500")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: backdrop ? 22 : 18, style: .continuous)
    }

    var body: some View {
        Button(action: tap) {
            PosterImage(url: art, size: size)
                .frame(width: size.width, height: size.height)
                .clipShape(shape)
                .overlay(shape.strokeBorder(.white.opacity(0.08)))
                .shadow(color: .black.opacity(0.35), radius: 14, y: 12)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.item.title), \(card.reason)")
    }
}
