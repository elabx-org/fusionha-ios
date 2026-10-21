import SwiftUI
import FusionhaKit

/// Places its children side by side at given tracks (`FoldColumns.Track`):
/// the first child in the first track, and so on. Moving the tracks (the fold
/// appears, the Duo half folds) moves the same children, so their state
/// (scroll, "Show all") survives (DC3).
struct TrackLayout: Layout {
    var tracks: [FoldColumns.Track]
    /// The whole row's width (wider than the viewport when it scrolls).
    var width: CGFloat
    var height: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            guard index < tracks.count else {
                subview.place(at: bounds.origin, proposal: .zero)
                continue
            }
            let track = tracks[index]
            subview.place(at: CGPoint(x: bounds.minX + CGFloat(track.x), y: bounds.minY),
                          proposal: ProposedViewSize(width: CGFloat(track.width), height: bounds.height))
        }
    }
}

/// Sideways scrolling that comes to rest on a whole number of `stride`s:
/// a column at a time without a fold, a fold page at a time with one, so a
/// column never rests across the fold.
struct StrideScrollTarget: ScrollTargetBehavior {
    var stride: CGFloat
    /// The furthest resting offset; `nil` is the end of the content.
    var maxOffset: CGFloat?

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard stride > 0 else { return }
        let end = max(context.contentSize.width - context.containerSize.width, 0)
        let limit = min(maxOffset ?? end, end)
        let snapped = (target.rect.minX / stride).rounded() * stride
        target.rect.origin.x = min(max(snapped, 0), limit)
    }
}

/// Two panes side by side (a list beside its detail) that meet at the Duo's
/// fold when one runs top to bottom through them, flat open included, with the
/// fold gutter between them (`FoldColumns.panes`). `nil`: keep the usual split.
enum FoldPanes {
    static func of(_ proxy: GeometryProxy, minLead: CGFloat, minTrail: CGFloat) -> (lead: CGFloat, gap: CGFloat)? {
        guard let x = FoldInfo.verticalFold(proxy),
              let panes = FoldColumns.panes(width: Double(proxy.size.width),
                                            fold: Double(x.lowerBound)...Double(x.upperBound),
                                            minLead: Double(minLead), minTrail: Double(minTrail))
        else { return nil }
        return (CGFloat(panes.lead), CGFloat(panes.gap))
    }
}

/// One grid row placed on given tracks (`PosterTracks`): child i in track i,
/// the row as tall as its tallest child at its track's width. A poster row
/// that keeps the fold in a gutter, in the Web layout and in a Spread span.
struct TrackRowLayout: Layout {
    var tracks: [FoldColumns.Track]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = zip(subviews, tracks).map { view, track in
            view.sizeThatFits(ProposedViewSize(width: CGFloat(track.width), height: nil)).height
        }.max() ?? 0
        return CGSize(width: proposal.width ?? CGFloat(tracks.last?.maxX ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, subview) in subviews.enumerated() {
            guard index < tracks.count else {
                subview.place(at: bounds.origin, proposal: .zero)
                continue
            }
            let track = tracks[index]
            subview.place(at: CGPoint(x: bounds.minX + CGFloat(track.x), y: bounds.minY),
                          proposal: ProposedViewSize(width: CGFloat(track.width), height: nil))
        }
    }
}
