import SwiftUI
import UIKit
import CryptoKit
import FusionhaKit

/// An artwork's three dominant colours (v2 page ground, mock palette-lift.js),
/// before the lift: the lift depends on the palette, so a palette switch
/// re-lifts without reading the art again.
///
/// The art comes through `ImagePipeline` (the hero's w780 copy when it is
/// already decoded, otherwise a small decode of the same URL), is drawn into
/// a 40×40 bitmap off the main thread, and `PaletteMath.dominant` picks the
/// colours. Results are kept in memory and in a small disk cache, keyed by
/// the art's URL, so a page that comes back paints its ground on the first
/// frame.
actor ArtPaletteExtractor {
    static let shared = ArtPaletteExtractor()

    /// The side of the sampled bitmap (the mock's canvas).
    static let side = 40

    /// Readable from any thread, so a view can draw a cached palette at once.
    nonisolated let memory = ArtPaletteMemory()
    private var inflight: [String: Task<[HSLColor]?, Never>] = [:]
    private let folder: URL? = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = caches.appendingPathComponent("ArtPalette", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// The art URL the page ground samples: the hero's w780 copy of a TMDB
    /// URL, any other URL as it is.
    static func sampleURL(_ raw: String?) -> URL? {
        TMDBImage.resized(raw, to: "w780")
    }

    /// The memory copy only (no disk, no network).
    nonisolated func cached(_ url: URL) -> [HSLColor]? {
        memory.get(url.absoluteString)
    }

    /// The dominant colours of `url`, or nil when it does not load.
    func colors(for url: URL) async -> [HSLColor]? {
        let key = url.absoluteString
        if let hit = memory.get(key) { return hit }
        if let disk = readDisk(key) {
            memory.set(disk, for: key)
            return disk
        }
        if let running = inflight[key] { return await running.value }
        PerfCount.hit("ArtPalette.extract")
        let task = Task<[HSLColor]?, Never> {
            guard let source = await Self.source(url) else { return nil }
            let pixels = await Task.detached(priority: .utility) { Self.pixels(source) }.value
            let top = PaletteMath.dominant(pixels)
            return top.isEmpty ? nil : top
        }
        inflight[key] = task
        let result = await task.value
        inflight[key] = nil
        if let result {
            memory.set(result, for: key)
            writeDisk(result, key)
        }
        return result
    }

    /// Forget every palette ("Reset cache & reload").
    func removeAll() {
        memory.removeAll()
        if let folder { try? FileManager.default.removeItem(at: folder) }
        if let folder { try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    }

    // MARK: Source and sampling

    /// The decoded art from the shared pipeline (a small decode is enough:
    /// it is only colour).
    @MainActor
    private static func source(_ url: URL) async -> CGImage? {
        await ImagePipeline.shared.image(for: url, fill: CGSize(width: 160, height: 90), scale: 1)?.cgImage
    }

    /// The art stretched into a `side`×`side` sRGB bitmap (the mock's
    /// `drawImage(im, 0, 0, 40, 40)`), as pixels.
    static func pixels(_ source: CGImage) -> [RGBA8] {
        let n = side
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return [] }
        let drawn: Bool = bytes.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(source, in: CGRect(x: 0, y: 0, width: n, height: n))
            return true
        }
        guard drawn else { return [] }
        var out: [RGBA8] = []
        out.reserveCapacity(n * n)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            out.append(RGBA8(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2]))
        }
        return out
    }

    // MARK: Disk

    private func file(_ key: String) -> URL? {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder?.appendingPathComponent(digest).appendingPathExtension("json")
    }

    private func readDisk(_ key: String) -> [HSLColor]? {
        guard let file = file(key), let data = try? Data(contentsOf: file),
              let rows = try? JSONDecoder().decode([[Double]].self, from: data) else { return nil }
        let colors = rows.compactMap { $0.count == 3 ? HSLColor(h: $0[0], s: $0[1], l: $0[2]) : nil }
        return colors.isEmpty ? nil : colors
    }

    private func writeDisk(_ colors: [HSLColor], _ key: String) {
        guard let file = file(key), let data = try? JSONEncoder().encode(colors.map { [$0.h, $0.s, $0.l] }) else { return }
        try? data.write(to: file, options: .atomic)
    }
}

/// The in-memory palettes: an NSCache, which is thread-safe.
final class ArtPaletteMemory: @unchecked Sendable {
    private final class Box {
        let colors: [HSLColor]
        init(_ colors: [HSLColor]) { self.colors = colors }
    }

    private let cache: NSCache<NSString, Box> = {
        let cache = NSCache<NSString, Box>()
        cache.countLimit = 400
        return cache
    }()

    func get(_ key: String) -> [HSLColor]? {
        cache.object(forKey: key as NSString)?.colors
    }

    func set(_ colors: [HSLColor], for key: String) {
        cache.setObject(Box(colors), forKey: key as NSString)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
