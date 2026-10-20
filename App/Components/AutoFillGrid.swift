import SwiftUI
import FusionhaKit

/// The web's card grids, `repeat(auto-fill, minmax(min(N, 100%), 1fr))`: as
/// many equal columns as fit at `minItemWidth` (one at least), filled row by
/// row. A row is as tall as its tallest card and each card is offered that
/// height (CSS grid's `align-items: stretch`), so cards that fill their frame
/// line up; the rest sit at the top. On a phone it is one column, the stack it
/// replaces.
struct AutoFillGrid: Layout {
    var minItemWidth: CGFloat
    var spacing: CGFloat = 12
    var lineSpacing: CGFloat?

    private var rowGap: CGFloat { lineSpacing ?? spacing }

    private func columns(_ width: CGFloat) -> Int {
        PaneRule.autoColumns(width: Double(width), min: Double(minItemWidth), gap: Double(spacing))
    }

    private func columnWidth(_ width: CGFloat, _ cols: Int) -> CGFloat {
        max(0, (width - spacing * CGFloat(cols - 1)) / CGFloat(cols))
    }

    private func rowHeights(_ subviews: Subviews, width: CGFloat) -> [CGFloat] {
        let cols = columns(width)
        let w = columnWidth(width, cols)
        return stride(from: 0, to: subviews.count, by: cols).map { start in
            (start..<min(start + cols, subviews.count))
                .map { subviews[$0].sizeThatFits(ProposedViewSize(width: w, height: nil)).height }
                .max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minItemWidth
        let heights = rowHeights(subviews, width: width)
        let total = heights.reduce(0, +) + rowGap * CGFloat(max(0, heights.count - 1))
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cols = columns(bounds.width)
        let w = columnWidth(bounds.width, cols)
        let heights = rowHeights(subviews, width: bounds.width)
        var y = bounds.minY
        for (row, height) in heights.enumerated() {
            for col in 0..<cols {
                let index = row * cols + col
                guard index < subviews.count else { break }
                let x = bounds.minX + CGFloat(col) * (w + spacing)
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                      proposal: ProposedViewSize(width: w, height: height))
            }
            y += height + rowGap
        }
    }
}
