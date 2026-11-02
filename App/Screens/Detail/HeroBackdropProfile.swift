import SwiftUI

/// The hero backdrop's washes as gradients over its frame (`DetailHeroBackdrop`).
/// Points are from the top of the header; `top` is how far the frame runs
/// up under the bar.
///
/// - The art: full strength down to its lower third, then it fades out (no
///   edge) into the art-tinted ground.
/// - The title shade: a light shade under the bar and the dark edge the
///   white title sits on, in every theme. It hands over to the ground wash in
///   the gap between the meta line and the version strip.
/// - The ground wash: the ground colour behind the text under the title, so
///   body text keeps 4.5:1 over the worst art (`ground` is 0.85 on the dark
///   palettes, 0.9 on Daylight, which keeps the art a pale wash there). It
///   lets go once the art has mostly faded, so it meets the ground unseen.
///
/// On the open Duo the far page (right of `column`) keeps the art clear in
/// the band and lets it go just under the band, where its tabs begin.
struct HeroBackdropProfile {
    let layout: HeroBackdropLayout
    let top: CGFloat
    let size: CGSize
    let ground: Double
    /// The text column's trailing x in the frame (nil: the full width).
    let column: CGFloat?

    private var edge: CGFloat { layout.edge }
    /// The foot of the art under the text column, in header points.
    private var foot: CGFloat { size.height - top }
    /// The art's lower third begins here (never above the title block).
    private var fadeStart: CGFloat { min(max(foot * 2 / 3, edge - 24), foot - 8) }
    /// The ground wash holds until the art is half gone.
    private var washHold: CGFloat { min(max((fadeStart + foot) / 2, edge + 10), foot - 4) }

    func artMask(_ color: Color) -> LinearGradient {
        vertical(color, [(fadeStart, 1), (foot, 0)])
    }

    func farArtMask(_ color: Color) -> LinearGradient {
        vertical(color, [(edge - 12, 1), (edge + 28, 0)])
    }

    func titleShade(_ color: Color) -> LinearGradient {
        switch layout.style {
        case .hero:
            vertical(color, [(-top, 0.28), (edge * 0.18, 0), (edge * 0.42, 0), (edge * 0.7, 0.55),
                             (edge - 14, 0.82), (edge + 10, 0)])
        case .band:
            vertical(color, [(-top, 0.3), (edge * 0.35, 0.2), (edge - 12, 0.78), (edge + 10, 0)])
        }
    }

    /// The far page's shade: the bar's, then nearly clear so the art reads.
    func farShade(_ color: Color) -> LinearGradient {
        vertical(color, [(-top, 0.3), (edge * 0.35, 0.12), (edge, 0.2), (edge + 24, 0)])
    }

    func groundWash(_ color: Color) -> LinearGradient {
        vertical(color, [(edge - 14, 0), (edge + 10, ground), (washHold, ground), (foot, 0)])
    }

    /// The text column's layer over the far page's, blended across 40 pt at
    /// the column's edge. Without a column, the text column's layer alone.
    @ViewBuilder
    func split<Near: View, Far: View>(near: Near, far: Far) -> some View {
        if let column, size.width > 0 {
            ZStack {
                far
                near.mask {
                    LinearGradient(stops: [
                        .init(color: .black, location: Self.unit((column - 40) / size.width)),
                        .init(color: .clear, location: Self.unit((column + 40) / size.width)),
                    ], startPoint: .leading, endPoint: .trailing)
                }
            }
        } else {
            near
        }
    }

    /// A top-to-bottom gradient of `color` at the given opacities, at header
    /// points (clamped to the frame and kept in order).
    private func vertical(_ color: Color, _ points: [(y: CGFloat, opacity: Double)]) -> LinearGradient {
        let height = max(size.height, 1)
        var last = 0.0
        let stops = points.map { point -> Gradient.Stop in
            last = max(last, Self.unit((point.y + top) / height))
            return .init(color: color.opacity(point.opacity), location: last)
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    private static func unit(_ value: CGFloat) -> Double {
        Double(min(max(value, 0), 1))
    }
}
