import SwiftUI
import UIKit
import FusionhaKit

/// A meta line led by the title's network mark (mock kit `mark(net, 'mono')`,
/// owner pick 2026-11-05 over the white `.netd` plate): the studio's logo as a
/// one-ink mark on transparent (`V2LogoAlpha`: the logo's alpha, two-tone
/// logos knocked out to their light parts, in the line's primary ink at
/// 85%), then `content`. A logo on a solid tile shows nothing. Nothing but the
/// content until the logo has loaded, and nothing at all without a logo (the
/// mark is never the name in text); it fades in when it arrives. The mark
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
            if let logo, let studio, let url, let ink = V2LogoAlpha.mask(for: logo, url: url) {
                mark(ink)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(studio.name)
                    .transition(.opacity)
            }
            content
        }
        .task(id: url) { await load() }
    }

    /// 13pt tall silhouette, a very wide one capped at 64pt and shrunk to fit.
    private func mark(_ logo: UIImage) -> some View {
        let aspect = logo.size.height > 0 ? logo.size.width / logo.size.height : 1
        let width = min(64, 13 * aspect)
        return Image(uiImage: logo)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: min(13, width / max(aspect, 0.01)))
            .frame(height: 13)
            .foregroundStyle(.primary)
            .opacity(0.85)
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
