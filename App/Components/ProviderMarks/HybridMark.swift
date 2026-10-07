import SwiftUI

/// The "Hybrid" metadata mark (the web's `HybridMark` in
/// `metadata-logos.tsx`): three Borromean-interlocked rings tinted TMDB blue,
/// TVDB green and TVmaze amber on a 48×48 grid.
///
/// No ring sits wholly on top: each ring is knocked out where its one
/// designated over-ring crosses it (amber over blue, blue over green, green
/// over amber). Each ring is drawn in its own transparency layer and the
/// over-ring's fat (9.5) stroke is erased from that layer only, so the gaps
/// show whatever is behind the mark: correct on light and dark surfaces alike.
///
/// It is a concept, not a wordmark, so callers keep a visible "Hybrid" label
/// beside it; it is decorative unless `label` is passed.
struct HybridMark: View {
    var size: CGFloat = 40
    /// An accessibility label, for a context with no adjacent "Hybrid" text.
    var label: String?

    static let blue = Color(hex: 0x01B4E4)
    static let green = Color(hex: 0x4FB862)
    static let amber = Color(hex: 0xF4A02C)

    private static let radius: CGFloat = 11.5
    private static let ringWidth: CGFloat = 4.4
    private static let knockoutWidth: CGFloat = 9.5
    private static let blueCentre = CGPoint(x: 24, y: 17)
    private static let greenCentre = CGPoint(x: 18, y: 27.4)
    private static let amberCentre = CGPoint(x: 30, y: 27.4)

    /// Each ring, its colour and the over-ring that cuts it.
    private static let weave: [(ring: CGPoint, color: Color, over: CGPoint)] = [
        (blueCentre, blue, amberCentre),
        (greenCentre, green, blueCentre),
        (amberCentre, amber, greenCentre),
    ]

    var body: some View {
        Canvas { context, canvasSize in
            context.scaleBy(x: canvasSize.width / 48, y: canvasSize.height / 48)
            for strand in Self.weave {
                context.drawLayer { layer in
                    layer.stroke(Self.circle(strand.ring), with: .color(strand.color), lineWidth: Self.ringWidth)
                    layer.blendMode = .destinationOut
                    layer.stroke(Self.circle(strand.over), with: .color(.black), lineWidth: Self.knockoutWidth)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(label == nil)
        .accessibilityLabel(label ?? "")
        .accessibilityAddTraits(label == nil ? [] : .isImage)
    }

    private static func circle(_ centre: CGPoint) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    }
}

#Preview {
    HStack(spacing: 24) {
        HybridMark(size: 64)
        HybridMark(size: 18)
    }
    .padding()
    .background(Color.white)
    HStack(spacing: 24) {
        HybridMark(size: 64)
        HybridMark(size: 18)
    }
    .padding()
    .background(Color.black)
}
