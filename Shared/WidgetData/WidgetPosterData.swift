import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Keeps poster bytes widget-sized. TMDB's small files pass through; a
/// larger image (a server or proxy URL the TMDB size swap can't shrink) is
/// downsampled to a JPEG no bigger than the size asked for, so decoding it
/// never costs the extension megabytes of its memory budget.
enum WidgetPosterData {
    static let passThroughBytes = 64 * 1024
    static let maxPixels = 240

    /// The longest side to keep for a TMDB size (`w500` → a 500 × 750
    /// poster): never below `maxPixels`, so the row sizes keep their 240.
    static func pixelLimit(forSize size: String) -> Int {
        guard size.hasPrefix("w"), let width = Int(size.dropFirst()) else { return maxPixels }
        return max(maxPixels, width * 3 / 2)
    }

    static func small(_ data: Data, maxPixels: Int = WidgetPosterData.maxPixels) -> Data? {
        guard data.count > passThroughBytes else { return data }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}
