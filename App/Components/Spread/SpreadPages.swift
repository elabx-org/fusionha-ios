import SwiftUI
import FusionhaKit

/// The Spread's right page while nothing is picked. S1 shows the shell's
/// "Select a title" hint on every tab; S2–S6 put each tab's most useful real
/// item here (the owner's "never empty" rule) by adding a case per tab.
struct SpreadRightPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.tab {
        case .search:
            SearchRightPageHint()
        default:
            SelectTitleHint()
        }
    }
}

/// The trailing column with no title open: what will appear there.
struct SelectTitleHint: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Theme.dim)
            Text("Select a title")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.txt)
            Text("Its versions, seasons and files open here.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

/// Two pieces of a row that spans both Spread pages: `leading` ends half a
/// gutter before the fold, `trailing` starts half a gutter after it, in the
/// row's own coordinates (it reads the fold itself, so it works at any inset).
/// Without a fold inside the row the pieces stack, leading first.
struct FoldSpanRow<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @State private var panes: FoldColumns.Panes?

    var body: some View {
        Group {
            if let panes {
                FoldPairLayout(lead: CGFloat(panes.lead), gap: CGFloat(panes.gap)) {
                    leading
                    trailing
                }
            } else {
                VStack(alignment: .leading, spacing: spacing) {
                    leading
                    trailing
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: FoldColumns.Panes?.self) { proxy in
            FoldInfo.verticalFold(proxy).flatMap { x in
                FoldColumns.panes(width: Double(proxy.size.width),
                                  fold: Double(x.lowerBound)...Double(x.upperBound), minLead: 120, minTrail: 120)
            }
        } action: { panes = $0 }
    }
}

/// Two children side by side: the first `lead` wide, then `gap` kept empty,
/// then the second in the rest; as tall as the taller one, each top-aligned.
struct FoldPairLayout: Layout {
    var lead: CGFloat
    var gap: CGFloat

    private func widths(_ total: CGFloat) -> (CGFloat, CGFloat) {
        let first = min(max(lead, 0), total)
        return (first, max(total - first - gap, 0))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? lead * 2 + gap
        let (a, b) = widths(total)
        let heights = zip(subviews, [a, b]).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
        return CGSize(width: total, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (a, b) = widths(bounds.width)
        for (index, subview) in subviews.enumerated() {
            switch index {
            case 0:
                subview.place(at: bounds.origin, proposal: ProposedViewSize(width: a, height: nil))
            case 1:
                subview.place(at: CGPoint(x: bounds.minX + a + gap, y: bounds.minY),
                              proposal: ProposedViewSize(width: b, height: nil))
            default:
                subview.place(at: bounds.origin, proposal: .zero)
            }
        }
    }
}
