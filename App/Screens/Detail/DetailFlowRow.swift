import SwiftUI

// MARK: - Layout

/// Wrapping row for chips (genres, pills).
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rowGap = lineSpacing ?? spacing
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + rowGap
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rowGap = lineSpacing ?? spacing
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        // Centre each item vertically within its row.
        var rows: [[(Subviews.Element, CGSize)]] = [[]]
        var rowWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            // A pixel of slack: layout rounds bounds to the pixel grid, which must not re-wrap a row that fit when sized.
            if rowWidth > 0 && rowWidth + size.width > bounds.width + 1 {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append((view, size))
            rowWidth += size.width + spacing
        }
        for row in rows {
            rowHeight = row.map { $0.1.height }.max() ?? 0
            x = bounds.minX
            for (view, size) in row {
                view.place(at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + rowGap
        }
    }
}
