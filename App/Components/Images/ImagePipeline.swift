import SwiftUI
import UIKit

/// Loads, downsizes and caches artwork. AsyncImage kept full-size bitmaps with
/// no memory cache, so scrolling a large library re-downloaded and re-decoded
/// every poster and memory grew until the app was killed.
///
/// Art is decoded at the pixel size of the frame it fills (points × display
/// scale), so a @3x screen gets @3x art and a small row thumb stays small. A
/// cached copy is reused while it still covers the frame; a larger frame for
/// the same URL decodes again from the on-disk response.
@MainActor
final class ImagePipeline {
    static let shared = ImagePipeline()

    private final class Entry {
        let image: UIImage
        let isFull: Bool
        init(_ decoded: ImageDownsampler.Decoded) { image = decoded.image; isFull = decoded.isFull }
    }

    private let memory = NSCache<NSURL, Entry>()
    private var inflight: [String: Task<ImageDownsampler.Decoded?, Never>] = [:]
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 300 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()

    private init() {
        memory.totalCostLimit = 128 << 20
    }

    /// "Reset cache & reload": forget decoded art and the on-disk responses.
    func removeAll() {
        memory.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }

    /// The cached art for `url` if it is sharp enough to aspect-fill `fill`
    /// pixels (any cached copy when `fill` is `.zero`).
    func cached(_ url: URL, fill: CGSize = .zero) -> UIImage? {
        guard let entry = memory.object(forKey: url as NSURL) else { return nil }
        guard !entry.isFull, fill.width > 0, fill.height > 0 else { return entry.image }
        let pixels = CGSize(width: entry.image.size.width * entry.image.scale,
                            height: entry.image.size.height * entry.image.scale)
        // A few percent short is invisible and saves a re-decode on tiny resizes.
        return ImageDownsampler.fillFactor(pixels: pixels, fill: fill) <= 1.05 ? entry.image : nil
    }

    /// Loads `url` decoded to aspect-fill `fill` pixels, tagged with `scale`.
    func image(for url: URL, fill: CGSize = .zero, scale: CGFloat = 1) async -> UIImage? {
        if let hit = cached(url, fill: fill) { return hit }
        let key = "\(url.absoluteString)|\(Int(fill.width))x\(Int(fill.height))"
        let task = inflight[key] ?? start(url, fill: fill, scale: scale)
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        guard let result else { return nil }
        store(result, for: url)
        return result.image
    }

    private func start(_ url: URL, fill: CGSize, scale: CGFloat) -> Task<ImageDownsampler.Decoded?, Never> {
        let session = self.session
        let fallback = Self.fallbackMaxPixel(for: url)
        return Task.detached(priority: .userInitiated) {
            guard let (data, _) = try? await session.data(from: url) else { return nil }
            return ImageDownsampler.decode(data, fill: fill, fallbackMax: fallback, scale: scale)
        }
    }

    /// Keeps the sharper copy when two frames decoded the same URL.
    private func store(_ decoded: ImageDownsampler.Decoded, for url: URL) {
        let key = url as NSURL
        let cg = decoded.image.cgImage
        let pixels = (cg?.width ?? 0) * (cg?.height ?? 0)
        if let old = memory.object(forKey: key), let oldCG = old.image.cgImage,
           old.isFull || oldCG.width * oldCG.height > pixels { return }
        memory.setObject(Entry(decoded), forKey: key, cost: pixels * 4)
    }

    /// Long-side cap for a caller that does not know its frame yet.
    nonisolated private static func fallbackMaxPixel(for url: URL) -> CGFloat {
        url.path.contains("/original/") ? 2048 : 1400
    }
}

/// What a piece of art is loading: the URL and its frame in pixels, rounded
/// up to 32px so a tiny resize does not restart the load.
struct ArtRequest: Hashable {
    let url: URL?
    let scale: CGFloat
    private let width: CGFloat
    private let height: CGFloat

    init(url: URL?, points: CGSize, scale: CGFloat) {
        self.url = url
        self.scale = scale
        func bucket(_ v: CGFloat) -> CGFloat { (max(v, 0) * scale / 32).rounded(.up) * 32 }
        width = bucket(points.width)
        height = bucket(points.height)
    }

    /// The frame in pixels.
    var pixels: CGSize { CGSize(width: width, height: height) }

    /// Laid out with a real size (before layout the frame is still zero).
    var hasFrame: Bool { width > 0 && height > 0 }
}
