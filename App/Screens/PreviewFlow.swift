import SwiftUI

/// A wrapping row (genre chips).
struct PreviewFlow: Layout {
    var spacing: CGFloat = 7
    /// The gap between rows; nil = `spacing`.
    var rowSpacing: CGFloat? = nil
    /// Rounding room: placed into exactly the width it asked for, a row's
    /// last item could land a fraction of a point past the edge and wrap
    /// onto a row the size never counted, drawing over what follows.
    private static let slack: CGFloat = 1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width + Self.slack {
                x = 0
                y += rowHeight + (rowSpacing ?? spacing)
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX + Self.slack {
                x = bounds.minX
                y += rowHeight + (rowSpacing ?? spacing)
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
