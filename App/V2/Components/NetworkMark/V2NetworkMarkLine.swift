import SwiftUI
import UIKit
import FusionhaKit

/// A meta line led by the title's network mark (mock kit `.netd`): the
/// studio's logo on a small white plate, so a coloured logo on transparent
/// stays legible on any art and any palette, then `content`. Nothing but the
/// content until the logo has loaded, and nothing at all without a logo (the
/// mark is never the name in text); it fades in when it arrives. The plate
/// sits in the meta line, never on the art. Content, not glass.
struct V2NetworkMarkLine<Content: View>: View {
    let studio: Studio?
    var spacing: CGFloat = 7
    @ViewBuilder let content: Content
    @Environment(\.motionEnabled) private var motion
    @State private var image: UIImage?
    @State private var shownURL: URL?

    private var url: URL? { TMDBImage.resized(studio?.logoUrl, to: "w185") }

    var body: some View {
        // A logo already decoded this session draws on the first frame.
        let cached = url.flatMap { ImagePipeline.shared.cached($0) }
        let logo = shownURL == url ? (image ?? cached) : cached
        HStack(spacing: spacing) {
            if let logo, let studio {
                plate(logo)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(studio.name)
                    .transition(.opacity)
            }
            content
        }
        .task(id: url) { await load() }
    }

    /// 11pt tall logo, a very wide one capped at 58pt and shrunk to fit.
    private func plate(_ logo: UIImage) -> some View {
        let aspect = logo.size.height > 0 ? logo.size.width / logo.size.height : 1
        let width = min(58, 11 * aspect)
        return Image(uiImage: logo)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: min(11, width / max(aspect, 0.01)))
            .frame(height: 11)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 22)
            .background(.white, in: Capsule())
            .overlay(Capsule().strokeBorder(.black.opacity(0.06)))
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
            .fixedSize()
    }

    private func load() async {
        guard let url else { image = nil; shownURL = nil; return }
        if let hit = ImagePipeline.shared.cached(url) { image = hit; shownURL = url; return }
        let loaded = await ImagePipeline.shared.image(for: url)
        guard !Task.isCancelled, let loaded else { return }
        withAnimation(motion ? .easeOut(duration: 0.25) : nil) {
            image = loaded
            shownURL = url
        }
    }
}
