import SwiftUI
import UIKit
import FusionhaKit

extension View {
    /// A soft glow of the title's own art under it (owner-approved layout A,
    /// mock `.glow`): the same image, small, blurred and saturated, dropped
    /// 12pt and inset a little. The only colour on the Library ground comes
    /// from the titles; there is no page-wide tint.
    ///
    /// Rendered once per URL and palette tone into a small bitmap
    /// (`ArtBlurCache`) and drawn as a plain image: no live blur, saturation
    /// or opacity pass while a grid scrolls. `aspect` is the card's width over
    /// height; `referenceWidth` its usual phone width (the blur scales with it).
    func artGlow(_ url: URL?, radius: CGFloat = 14, aspect: Double = 2 / 3, referenceWidth: Double = 120) -> some View {
        background {
            if url != nil {
                ArtGlowLayer(url: url, radius: radius, aspect: aspect, referenceWidth: referenceWidth)
            }
        }
    }
}

/// The glow's bitmap, stretched over the card and scaled out around its
/// centre by the spec's overscan (a transform, not an offscreen pass).
private struct ArtGlowLayer: View {
    let url: URL?
    let radius: CGFloat
    let aspect: Double
    let referenceWidth: Double

    var body: some View {
        let spec = ArtBlurSpec.glow(aspect: aspect, tone: ArtTone(isLight: Theme.isLight, isMono: Theme.isMono),
                                    cornerRadius: Double(radius), referenceWidth: referenceWidth)
        BlurredArtImage(url: url, spec: spec, contentMode: nil)
            .scaleEffect(x: spec.overscanX, y: spec.overscanY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// An ambient wash of the art behind a page (the title page and Preview):
/// rendered once, blurred and colour-adjusted, then aspect-filled, scaled
/// 1.28 and clipped as the live `blur(72)` version was.
struct AmbientArt: View {
    let url: URL?
    let kind: ArtBlurSpec.Kind
    var aspect: Double = 16 / 9

    var body: some View {
        let spec = ArtBlurSpec.ambient(kind, tone: ArtTone(isLight: Theme.isLight, isMono: Theme.isMono), aspect: aspect)
        Color.clear
            .overlay {
                BlurredArtImage(url: url, spec: spec, contentMode: .fill)
                    .scaleEffect(spec.overscanX)
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A rendered `ArtBlurSpec` bitmap. A cached copy draws on the first frame
/// (scrolling back never waits on a task); otherwise it loads once per key.
private struct BlurredArtImage: View {
    let url: URL?
    let spec: ArtBlurSpec
    /// `nil` stretches over the frame (a glow); `.fill` aspect-fills (ambient).
    let contentMode: ContentMode?
    @State private var loaded: (key: String, image: UIImage)?

    var body: some View {
        let key = url.map { spec.key(for: $0.absoluteString) }
        let image = key.flatMap { ArtBlurCache.shared.cached($0) } ?? (loaded?.key == key ? loaded?.image : nil)
        Group {
            if let image {
                if let contentMode {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                } else {
                    Image(uiImage: image).resizable()
                }
            } else {
                Color.clear
            }
        }
        .task(id: key) {
            guard let url, let key, ArtBlurCache.shared.cached(key) == nil else { return }
            guard let made = await ArtBlurCache.shared.image(for: url, spec: spec), !Task.isCancelled else { return }
            loaded = (key, made)
        }
    }
}
