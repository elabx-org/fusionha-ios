import SwiftUI
import FusionhaKit

/// The page's list | detail (web `ListsDuoSplit`): with a top-to-bottom fold
/// through the page (the open iPhone Duo, flat or Book) the list is the left
/// page and the detail the right, the fold in the gutter between them, so
/// nothing sits on it; otherwise the list alone (a source pushes its detail).
struct WatchlistsSplit<Leading: View, Detail: View>: View {
    let panes: FoldColumns.Panes?
    @ViewBuilder var list: Leading
    @ViewBuilder var detail: Detail
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let panes {
                FoldPairLayout(lead: CGFloat(panes.lead), gap: CGFloat(panes.gap), fillHeight: true) {
                    list
                    detail
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                // A fold through a page too narrow for both panes: the list
                // keeps before its gutter.
                list.foldLeadingColumn()
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: panes)
    }
}
