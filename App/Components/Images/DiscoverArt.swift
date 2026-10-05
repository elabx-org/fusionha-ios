import SwiftUI
import UIKit

/// `DiscoverArt`: the art fades in from `blur(6px)` + transparent to sharp over 0.55s.
/// It is decoded at the pixel size of its frame, like `PosterImage`.
struct DiscoverArt: View {
    let url: URL?
    @Environment(\.accessibilityReduceMotion) private var osReduceMotion
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var shownURL: URL?
    @State private var shown = false
    @State private var box: CGSize = .zero

    var body: some View {
        let request = ArtRequest(url: url, points: box, scale: displayScale)
        // Color.clear keeps the layout size to the proposal: a filling image
        // would otherwise report its larger size and push its container out.
        Color.clear
            .onGeometryChange(for: CGSize.self) { $0.size } action: { box = $0 }
            .overlay {
                LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                        .blur(radius: shown ? 0 : 6)
                        .opacity(shown ? 1 : 0)
                }
            }
        .clipped()
        .task(id: request) { await load(request) }
    }

    private func load(_ request: ArtRequest) async {
        guard let url = request.url else { image = nil; shownURL = nil; return }
        guard request.hasFrame else { return }
        if let cached = ImagePipeline.shared.cached(url, fill: request.pixels) {
            image = cached
            shownURL = url
            shown = true
            return
        }
        // A sharper copy of the art already shown swaps in without the fade.
        let swap = shownURL == url
        if !swap { shown = false }
        let loaded = await ImagePipeline.shared.image(for: url, fill: request.pixels, scale: request.scale)
        guard !Task.isCancelled else { return }
        if swap, loaded == nil { return }
        image = loaded
        shownURL = url
        if swap || DiscoverMotion.reduced(osReduceMotion) {
            shown = true
        } else {
            withAnimation(.easeOut(duration: 0.55)) { shown = true }
        }
    }
}
