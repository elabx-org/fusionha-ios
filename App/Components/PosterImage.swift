import ImageIO
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
    @State private var image: UIImage?
    @State private var fade = false

    var body: some View {
        let _ = PerfCount.hit("PosterImage.body")
        LinearGradient(colors: [Theme.panel2, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                if let image { PosterArt(image: image, fade: fade) }
            }
            .task(id: url) {
                guard let url else { image = nil; return }
                if let cached = ImagePipeline.shared.cached(url) {
                    fade = false
                    image = cached
                    return
                }
                image = nil
                let loaded = await ImagePipeline.shared.image(for: url)
                guard !Task.isCancelled else { return }
                fade = true
                image = loaded
            }
    }
}

/// Aspect-filled, clipped art that takes exactly the size it is offered.
private struct PosterArt: UIViewRepresentable {
    let image: UIImage
    let fade: Bool

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
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

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 10, height: 10))
    }
}

/// Loads, downsizes and caches artwork. AsyncImage kept full-size bitmaps with
/// no memory cache, so scrolling a large library re-downloaded and re-decoded
/// every poster and memory grew until the app was killed.
@MainActor
final class ImagePipeline {
    static let shared = ImagePipeline()

    private let memory = NSCache<NSURL, UIImage>()
    private var inflight: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 300 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()

    private init() {
        memory.totalCostLimit = 96 << 20
    }

    /// "Reset cache & reload": forget decoded art and the on-disk responses.
    func removeAll() {
        memory.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }

    func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let running = inflight[url] { return await running.value }
        let session = self.session
        // Backdrops are shown full width; posters never wider than a third.
        let maxPixel: CGFloat = url.path.contains("/w1280/") || url.path.contains("/original/") ? 1400 : 480
        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let (data, _) = try? await session.data(from: url) else { return nil }
            return Self.downsample(data, maxPixel: maxPixel)
        }
        inflight[url] = task
        let result = await task.value
        inflight[url] = nil
        if let result {
            let cost = Int(result.size.width * result.size.height * result.scale * result.scale * 4)
            memory.setObject(result, forKey: url as NSURL, cost: cost)
        }
        return result
    }

    nonisolated private static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let thumb = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumb) else { return nil }
        return UIImage(cgImage: cg)
    }
}
