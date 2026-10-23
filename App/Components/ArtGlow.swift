import SwiftUI
import UIKit
import FusionhaKit

extension View {
    /// A soft glow of the title's own art under it (owner-approved layout A,
    /// mock `.glow`): the same image, small, blurred and saturated, dropped
    /// 12pt and inset a little. The only colour on the Library ground comes
    /// from the titles; there is no page-wide tint.
    func artGlow(_ url: URL?, radius: CGFloat = 14) -> some View {
        background {
            if url != nil {
                SoftArt(url: url)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .scaleEffect(0.92)
                    .offset(y: 12)
                    .blur(radius: 20)
                    .saturation(Theme.isMono ? 0 : 1.9)
                    .opacity(Theme.isLight ? 0.45 : 0.6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// Small art drawn by SwiftUI itself, for layers that blur or filter it
/// (`PosterImage` draws through UIKit, which SwiftUI's blur and colour
/// effects do not reach). Decoded at a fixed small size: it is only colour.
struct SoftArt: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: PosterWashRenderer.washed(image)).resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await ImagePipeline.shared.image(for: url, fill: CGSize(width: 160, height: 240), scale: 1)
        }
    }
}
