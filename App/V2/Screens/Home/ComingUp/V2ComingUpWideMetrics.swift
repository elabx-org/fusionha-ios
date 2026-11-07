import SwiftUI

/// The open Duo carousel's geometry per style (mock "Coming up as the
/// hero"): card size, the gap between slots, and the scale, opacity and
/// pull toward the centre at 0, 1, 2… slots from it. Posters: a 200pt
/// centre, two a side at 0.8 / 0.62, fading 0.85 / 0.55. Backdrops: a
/// 540pt 16:9 centre, neighbours at 0.78 and 0.6 peeking in from the edges.
/// Reduce Motion: no scaling or pull, a plain gap (the fade stays, as on
/// the folded carousel).
struct V2ComingUpWideMetrics {
    let size: CGSize
    let spacing: CGFloat
    let scales: [CGFloat]
    let opacities: [CGFloat]
    /// Extra pull toward the centre (pt) on top of the slot's place.
    let pulls: [CGFloat]

    init(style: V2ComingUpWideStyle, width: CGFloat, motion: Bool) {
        switch style {
        case .posters:
            size = CGSize(width: 200, height: 300)
            spacing = motion ? -20 : 18
            scales = motion ? [1, 0.8, 0.62, 0.5] : [1, 1]
            opacities = [1, 0.85, 0.55, 0]
            pulls = motion ? [0, 0, 30, 100] : [0, 0]
        case .backdrops:
            let w = width > 0 ? min(540, max(320, width - 160)) : 540
            size = CGSize(width: w, height: (w * 9 / 16).rounded())
            spacing = motion ? -(w * 0.13).rounded() : 24
            scales = motion ? [1, 0.78, 0.66] : [1, 1]
            opacities = [1, 0.6, 0.25]
            pulls = motion ? [0, 0, 60] : [0, 0]
        }
    }

    /// One slot: a card and its gap.
    var step: CGFloat { size.width + spacing }

    /// Signed slots from the centre of the row (−1 is the left neighbour).
    func slot(_ proxy: GeometryProxy) -> CGFloat {
        guard let bounds = proxy.bounds(of: .scrollView) else { return 0 }
        let frame = proxy.frame(in: .scrollView)
        return (frame.midX - bounds.width / 2) / max(step, 1)
    }

    func scale(_ slot: CGFloat) -> CGFloat { Self.at(scales, abs(slot)) }
    func opacity(_ slot: CGFloat) -> CGFloat { Self.at(opacities, abs(slot)) }
    func offset(_ slot: CGFloat) -> CGFloat { -Self.at(pulls, abs(slot)) * (slot < 0 ? -1 : 1) }

    /// Linear between the stops; the last one holds past the end.
    static func at(_ stops: [CGFloat], _ x: CGFloat) -> CGFloat {
        guard stops.count > 1 else { return stops.first ?? 0 }
        let x = min(max(x, 0), CGFloat(stops.count - 1))
        let i = min(Int(x), stops.count - 2)
        let f = x - CGFloat(i)
        return stops[i] + (stops[i + 1] - stops[i]) * f
    }
}
