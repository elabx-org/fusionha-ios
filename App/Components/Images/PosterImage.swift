import SwiftUI
import UIKit

/// A clean poster: no text over the art (design rule), and the web's dark
/// gradient placeholder while loading or when there is no art.
///
/// The art is drawn by a UIImageView over the placeholder, and its fade-in is a
/// Core Animation animation. A SwiftUI `withAnimation` fade kept SwiftUI's
/// display link re-running the view graph every frame while any poster in a
/// scrolling list was fading in, which was most of a fast scroll.
struct PosterImage: View {
    let url: URL?
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var shownURL: URL?
    @State private var fade = false
    /// The laid-out frame, in points: the art is decoded for exactly this.
    @State private var box: CGSize = .zero

    private var placeholder: some View {
        LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        let _ = PerfCount.hit("PosterImage.body")
        let request = ArtRequest(url: url, points: box, scale: displayScale)
        // The placeholder stays underneath, so the fade reads as the old
        // crossfade. Layout is still done by the same resizable, aspect-filled
        // SwiftUI `Image` as before (kept invisible), and the art is drawn over
        // exactly its frame, so every caller sizes the poster as it always has.
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                    .hidden()
                    .overlay { PosterArt(image: image, fade: fade) }
                    .background { placeholder }
            } else {
                placeholder
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { box = $0 }
        .task(id: request) { await load(request) }
    }

    /// Decodes the art at this frame's pixel size. A resize that the cached
    /// copy still covers swaps nothing; a larger one swaps in the sharper copy
    /// without the fade.
    private func load(_ request: ArtRequest) async {
        guard let url = request.url else { image = nil; shownURL = nil; return }
        guard request.hasFrame else { return }
        let pipeline = ImagePipeline.shared
        if let cached = pipeline.cached(url, fill: request.pixels) {
            if image !== cached { fade = false; image = cached; shownURL = url }
            return
        }
        if shownURL != url { image = nil }
        let loaded = await pipeline.image(for: url, fill: request.pixels, scale: request.scale)
        guard !Task.isCancelled, let loaded else { return }
        fade = shownURL != url
        image = loaded
        shownURL = url
    }
}

/// Aspect-filled art drawn by UIKit, with a Core Animation fade-in.
private struct PosterArt: UIViewRepresentable {
    let image: UIImage
    let fade: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.image = image
        if fade, !UIAccessibility.isReduceMotionEnabled {
            view.alpha = 0
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) { view.alpha = 1 }
        }
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        guard view.image !== image else { return }
        if fade, !UIAccessibility.isReduceMotionEnabled {
            UIView.transition(with: view, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction]) { view.image = image }
        } else {
            view.image = image
        }
    }

    /// Fills whatever frame the overlay offers (the hidden `Image`'s frame).
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: image.size)
    }
}
