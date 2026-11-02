import SwiftUI

/// The hero backdrop's layers as gradients over its frame, for one side of
/// it (the text column, or the open Duo's far page with its own `foot`).
/// Points are from the top of the header; `top` is how far the frame runs up
/// under the bar. Every change of strength is eased over many points, so no
/// step reads as a line.
///
/// - The art: sharp in its own box (`artBottom`, the old hero's framing, so
///   it is never zoomed further), easing over 72 pt into its blurred
///   continuation, which carries the art's colour on behind the facts and
///   overview and fades out over the lower third, at `foot`.
/// - The title shade: a light shade under the bar and the dark edge the
///   white title sits on, in every theme; it eases out by `handover`.
/// - The ground wash: the ground colour behind the text under the title,
///   eased in over the same span, so body text keeps 4.5:1 over the worst
///   art (0.85 dark, 0.9 Daylight, where it keeps the art a pale wash). It
///   holds until the art has gone, then lets go past the foot.
struct HeroBackdropProfile {
    let layout: HeroBackdropLayout
    let top: CGFloat
    /// The frame's height (from its top, under the bar).
    let height: CGFloat
    /// The sharp art's box bottom, in header points.
    let artBottom: CGFloat
    let foot: CGFloat
    let ground: Double

    private var edge: CGFloat { layout.edge }
    private var sharpEnd: CGFloat { min(artBottom, max(foot, edge + 24)) }
    private var sharpStart: CGFloat { max(sharpEnd - 72, -top) }
    /// The art's lower third, never above the sharp art's own fade and never
    /// shorter than 48 pt (the sharp art can end at the foot itself).
    private var fadeStart: CGFloat { min(max(sharpStart, foot - (foot + top) / 3), foot - 48) }

    func sharpMask() -> LinearGradient {
        vertical(.black, [(sharpStart, 1)] + Self.ease(sharpStart, 1, sharpEnd, 0))
    }

    func continuationMask() -> LinearGradient {
        vertical(.black, [(fadeStart, 1)] + Self.ease(fadeStart, 1, foot, 0))
    }

    func titleShade(_ color: Color) -> LinearGradient {
        let lead: [(CGFloat, Double)] = switch layout.style {
        case .hero: [(-top, 0.28), (edge * 0.18, 0), (edge * 0.42, 0), (edge * 0.7, 0.55), (edge - 14, 0.82)]
        case .band: [(-top, 0.3), (edge * 0.35, 0.2), (edge - 12, 0.78)]
        }
        let last = lead[lead.count - 1]
        return vertical(color, lead + Self.ease(last.0, last.1, layout.handover, 0))
    }

    /// The open Duo's far page: the bar's shade, then nearly clear so the art reads.
    func farShade(_ color: Color) -> LinearGradient {
        vertical(color, [(-top, 0.3), (edge * 0.35, 0.12), (edge - 12, 0.2)]
                    + Self.ease(edge - 12, 0.2, layout.handover, 0))
    }

    func groundWash(_ color: Color) -> LinearGradient {
        vertical(color, Self.ease(edge - 14, 0, layout.handover, ground)
                    + Self.ease(foot, ground, foot + HeroBackdropLayout.tail, 0))
    }

    /// Smoothstep from `a` at `y0` to `b` at `y1` in seven stops: no kink at
    /// either end, so the eye finds no edge.
    static func ease(_ y0: CGFloat, _ a: Double, _ y1: CGFloat, _ b: Double) -> [(CGFloat, Double)] {
        (0...6).map { i in
            let t = Double(i) / 6
            let s = t * t * (3 - 2 * t)
            return (y0 + (y1 - y0) * CGFloat(t), a + (b - a) * s)
        }
    }

    /// A top-to-bottom gradient of `color` at the given opacities, at header
    /// points (clamped to the frame and kept in order).
    private func vertical(_ color: Color, _ points: [(CGFloat, Double)]) -> LinearGradient {
        let height = max(height, 1)
        var last = 0.0
        let stops = points.map { point -> Gradient.Stop in
            last = max(last, Self.unit((point.0 + top) / height))
            return .init(color: color.opacity(point.1), location: last)
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    static func unit(_ value: CGFloat) -> Double {
        Double(min(max(value, 0), 1))
    }
}

/// The text column's layer over the far side's, blended across 80 pt at
/// `column` (an x in the frame). Without a column, the text column's alone.
struct HeroSplit<Near: View, Far: View>: View {
    let column: CGFloat?
    let width: CGFloat
    @ViewBuilder var near: Near
    @ViewBuilder var far: Far

    var body: some View {
        if let column, width > 0 {
            ZStack {
                far.mask { ramp(column, from: .clear, to: .black) }
                near.mask { ramp(column, from: .black, to: .clear) }
            }
        } else {
            near
        }
    }

    /// Complementary ramps: the sides cross-fade over the blend.
    private func ramp(_ column: CGFloat, from: Color, to: Color) -> LinearGradient {
        LinearGradient(stops: [
            .init(color: from, location: HeroBackdropProfile.unit((column - 40) / width)),
            .init(color: to, location: HeroBackdropProfile.unit((column + 40) / width)),
        ], startPoint: .leading, endPoint: .trailing)
    }
}
