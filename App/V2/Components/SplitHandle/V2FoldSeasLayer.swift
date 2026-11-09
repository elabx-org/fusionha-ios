import SwiftUI
import UIKit
import FusionhaKit

/// One of the seas' masks (`FoldSeas.field`) as an image stretched over the
/// strip: `.sea`, how much of the trailing page shows; `.shade`, the
/// shading over both. Worked out off the main thread at half the strip's
/// height (the water is soft) and redrawn only when the strip's size or
/// where the seas meet changes.
struct V2FoldSeasLayer: View {
    enum Kind { case sea, shade }

    let kind: Kind
    let meeting: Double
    @State private var image: CGImage?
    @State private var size: CGSize = .zero

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                // Until the masks are ready: a plain meeting down the middle.
                kind == .sea ? AnyView(HStack(spacing: 0) { Color.clear; Color.black }) : AnyView(Color.clear)
            }
        }
        .onGeometryChange(for: CGSize.self) { CGSize(width: $0.size.width.rounded(), height: $0.size.height.rounded()) } action: {
            size = $0
        }
        .task(id: Key(size: size, meeting: (meeting * 50).rounded())) {
            guard size.width > 0, size.height > 0 else { return }
            let w = Int(size.width), h = max(1, Int(size.height / 2)), m = meeting, kind = kind
            let made = await Task.detached(priority: .utility) { Self.make(kind, w, h, m) }.value
            guard !Task.isCancelled else { return }
            image = made
        }
    }

    private struct Key: Equatable {
        let size: CGSize
        let meeting: Double
    }

    private nonisolated static func make(_ kind: Kind, _ w: Int, _ h: Int, _ meeting: Double) -> CGImage? {
        let field = FoldSeas.field(width: w, height: h, meeting: meeting)
        switch kind {
        case .sea:
            // As an alpha mask: black at the sea's strength.
            var rgba = [UInt8](repeating: 0, count: w * h * 4)
            for i in 0..<(w * h) { rgba[i * 4 + 3] = field.sea[i] }
            return image(rgba, w, h)
        case .shade:
            return image(field.shade, w, h)
        }
    }

    private nonisolated static func image(_ rgba: [UInt8], _ w: Int, _ h: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

/// A colour's tone, for lifting a near-black ground and for where the seas meet.
enum V2GutterTone {
    static func luminance(_ color: Color) -> Double {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return 1 }
        return 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
    }

    /// The luminance after a dark ground's lift (about what the fold shows).
    static func lifted(_ color: Color) -> Double {
        let l = luminance(color)
        return l + FoldSeas.lift(luminance: l)
    }

    static func saturation(_ color: Color) -> Double {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getHue(&h, saturation: &s, brightness: &v, alpha: &a) else { return 0 }
        return Double(s)
    }
}
