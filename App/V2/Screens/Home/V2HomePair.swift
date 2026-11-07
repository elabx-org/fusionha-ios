import SwiftUI
import FusionhaKit

/// Two Home columns side by side on a wide page. Flat (and on an iPad) they
/// are equal halves with the ordinary 20pt gap: the open Duo is one panel
/// and nothing is kept for the hinge (owner, 2026-11-06). Only in book pose
/// do they split at the real fold (`FoldColumns`).
struct V2HomePair<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @State private var panes: FoldColumns.Panes?
    @State private var width: CGFloat = 0

    static var gap: CGFloat { 20 }

    var body: some View {
        let lead = panes.map { CGFloat($0.lead) } ?? (width - Self.gap) / 2
        let gap = panes.map { CGFloat($0.gap) } ?? Self.gap
        FoldPairLayout(lead: max(lead, 0), gap: gap) {
            leading
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: FoldColumns.Panes?.self) { proxy in
            V2HomePairFold.panes(proxy)
        } action: { panes = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

/// Book pose only: the panes either side of the fold, in the view's space.
enum V2HomePairFold {
    static func panes(_ proxy: GeometryProxy) -> FoldColumns.Panes? {
        FoldInfo.verticalFold(proxy).flatMap { x in
            FoldColumns.panes(width: Double(proxy.size.width),
                              fold: Double(x.lowerBound)...Double(x.upperBound), minLead: 120, minTrail: 120)
        }
    }
}
