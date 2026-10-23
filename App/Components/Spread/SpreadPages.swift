import SwiftUI
import FusionhaKit

/// The Spread's right page while nothing is picked. S1 shows the shell's
/// "Select a title" hint on every tab; S2–S6 put each tab's most useful real
/// item here (the owner's "never empty" rule) by adding a case per tab.
struct SpreadRightPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.tab {
        case .you:
            // Account (S6, first part): Watchlists & lists or Sign-in methods.
            AccountRightPage()
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
    /// Where the trailing piece sits in the row's height (the Library span's
    /// tools sit on the grid, the owner's mock: bottom).
    var trailingAlignment: VerticalAlignment = .top
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @State private var panes: FoldColumns.Panes?

    var body: some View {
        Group {
            if let panes {
                FoldPairLayout(lead: CGFloat(panes.lead), gap: CGFloat(panes.gap), trailingAlignment: trailingAlignment) {
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
/// then the second in the rest; as tall as the taller one. The first is
/// top-aligned, the second at `trailingAlignment`; with `fillHeight` both are
/// offered the row's full height (two cards of one height).
struct FoldPairLayout: Layout {
    var lead: CGFloat
    var gap: CGFloat
    var trailingAlignment: VerticalAlignment = .top
    var fillHeight = false

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
        let height: CGFloat? = fillHeight ? bounds.height : nil
        for (index, subview) in subviews.enumerated() {
            switch index {
            case 0:
                subview.place(at: bounds.origin, proposal: ProposedViewSize(width: a, height: height))
            case 1:
                let own = fillHeight ? bounds.height : subview.sizeThatFits(ProposedViewSize(width: b, height: nil)).height
                let y = trailingAlignment == .bottom ? bounds.maxY - own
                    : trailingAlignment == .center ? bounds.midY - own / 2 : bounds.minY
                subview.place(at: CGPoint(x: bounds.minX + a + gap, y: y),
                              proposal: ProposedViewSize(width: b, height: height))
            default:
                subview.place(at: bounds.origin, proposal: .zero)
            }
        }
    }
}
