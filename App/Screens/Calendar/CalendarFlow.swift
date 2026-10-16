import SwiftUI
import FusionhaKit

/// One rail per version in a wrapping row (HD and 4K side by side), drawn
/// like the library's rails.
struct CalRailWrap: View {
    let entry: CalendarEntry
    let now: Date
    var rowGap: CGFloat = 8
    var columnGap: CGFloat = 16
    @Environment(\.railConsolidate) private var consolidate

    var body: some View {
        CalRails(units: CalendarRails.entry(entry, now: now, consolidate: consolidate), rowGap: rowGap, columnGap: columnGap)
    }
}

/// A wrapping row (CSS `flex-wrap: wrap`) with centred items per line.
struct CalFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + size.width > width {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lines: [[(LayoutSubview, CGSize)]] = [[]]
        var x: CGFloat = 0
        for view in subviews {
            var size = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            size.width = min(size.width, bounds.width)
            if x > 0 && x + size.width > bounds.width {
                lines.append([])
                x = 0
            }
            lines[lines.count - 1].append((view, size))
            x += size.width + spacing
        }
        var y = bounds.minY
        for line in lines {
            let height = line.map { $0.1.height }.max() ?? 0
            var lx = bounds.minX
            for (view, size) in line {
                view.place(at: CGPoint(x: lx, y: y + (height - size.height) / 2),
                           proposal: ProposedViewSize(width: size.width, height: size.height))
                lx += size.width + spacing
            }
            y += height + lineSpacing
        }
    }
}
