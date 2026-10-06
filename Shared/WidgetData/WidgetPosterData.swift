import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Keeps poster bytes widget-sized. TMDB's w92/w154 files pass through; a
/// larger image (a server or proxy URL the TMDB size swap can't shrink) is
/// downsampled to a small JPEG, so decoding it never costs the extension
/// megabytes of its memory budget.
enum WidgetPosterData {
    static let passThroughBytes = 64 * 1024
    static let maxPixels = 240

    static func small(_ data: Data) -> Data? {
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
