import SwiftUI
import FusionhaKit

/// Tiles that wrap like the web's `display: flex; flex-wrap: wrap` with
/// `flex: 1; min-width: N`: as many per line as fit at `minItemWidth`, each
/// line's tiles stretched to share its width. `balanced` evens the lines out
/// so the last never holds a lone tile (5 tiles as 3 + 2, not 4 + 1).
struct StretchWrapLayout: Layout {
    var minItemWidth: CGFloat
    var spacing: CGFloat = 12
    var lineSpacing: CGFloat = 12
    var balanced = false

    private func perLine(_ width: CGFloat, count: Int) -> Int {
        let fit = PaneRule.autoColumns(width: Double(width), min: Double(minItemWidth), gap: Double(spacing), items: count)
        return balanced ? PaneRule.balancedColumns(fitting: fit, items: count) : fit
    }

    private func lines(_ count: Int, width: CGFloat) -> [Range<Int>] {
        let n = max(1, perLine(width, count: count))
        return stride(from: 0, to: count, by: n).map { $0..<min($0 + n, count) }
    }

    private func itemWidth(_ line: Range<Int>, width: CGFloat) -> CGFloat {
        max(0, (width - spacing * CGFloat(line.count - 1)) / CGFloat(line.count))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (minItemWidth + spacing) * CGFloat(subviews.count) - spacing
        var height: CGFloat = 0
        for (index, line) in lines(subviews.count, width: width).enumerated() {
            let w = itemWidth(line, width: width)
            let tallest = line.map { subviews[$0].sizeThatFits(ProposedViewSize(width: w, height: nil)).height }.max() ?? 0
            height += tallest + (index > 0 ? lineSpacing : 0)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in lines(subviews.count, width: bounds.width) {
            let w = itemWidth(line, width: bounds.width)
            let tallest = line.map { subviews[$0].sizeThatFits(ProposedViewSize(width: w, height: nil)).height }.max() ?? 0
            var x = bounds.minX
            for index in line {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: w, height: tallest))
                x += w + spacing
            }
            y += tallest + lineSpacing
        }
    }
}
