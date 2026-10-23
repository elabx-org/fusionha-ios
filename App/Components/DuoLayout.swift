import SwiftUI
import FusionhaKit

// MARK: - iPhone Duo / wide layout
//
// Folded (a phone-sized window) the app is the phone app: one column, the
// title detail opens as a sheet. With room for two columns (at least 560 x 500
// points, `ShellSplitRule`, the web's rule: the iPhone Duo's inner display, an
// iPad) the shell becomes two columns like the web's wide layout: the tabs on
// the leading side and the open title on the trailing side, in place of the
// sheet. Only landscape-shaped windows split: in inner portrait (669 x 951)
// the tab bar stays at the bottom and the title keeps the phone's sheet, the
// HIG's horizontal bars (ruling Q-DC3); the sheet and the column share one
// `DetailStore` (DC3), so rotating keeps the open page. When the Duo is half
// open (Book) the system reports the
// fold as a reserved `.division` region; the split then lines up with the
// fold so neither column runs across it, and nothing is drawn in the fold.
// Flat open the fold is still there (an inactive, zero-wide `.division`):
// whenever `ShellSplitRule` splits, the split sits on it too, with the 40 pt
// fold gutter (`FoldColumns.gutter`) around it, instead of the web's 418 | 532.
// Without a fold (an iPad, any other device) the web's split is unchanged.
//
// Every size is container-relative (no screen sizes, idioms or orientation
// checks). The open title lives in `AppModel.presentedItem` and its state in
// `AppModel.detailStore(for:)`, so folding and unfolding keeps both: sheet <->
// trailing column (`DetailContinuity` in FusionhaKit).

/// Places one or two children: alone it fills the container; with a second
/// child it splits along `axis`, the first child `primary` long, then `gap`
/// (the fold, kept empty), then the second child. It is always the same
/// container, so the first child keeps its identity (scroll position, tab,
/// navigation) when the second appears or the split moves.
struct FoldSplitLayout: Layout {
    var axis: Axis = .horizontal
    var primary: CGFloat
    var gap: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count > 1 else {
            subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            return
        }
        switch axis {
        case .horizontal:
            let first = min(max(primary, 0), bounds.width)
            subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: first, height: bounds.height))
            let x = min(bounds.minX + first + gap, bounds.maxX)
            subviews[1].place(at: CGPoint(x: x, y: bounds.minY),
                              proposal: ProposedViewSize(width: bounds.maxX - x, height: bounds.height))
        case .vertical:
            let first = min(max(primary, 0), bounds.height)
            subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: first))
            let y = min(bounds.minY + first + gap, bounds.maxY)
            subviews[1].place(at: CGPoint(x: bounds.minX, y: y),
                              proposal: ProposedViewSize(width: bounds.width, height: bounds.maxY - y))
        }
        for extra in subviews.dropFirst(2) {
            extra.place(at: bounds.origin, proposal: .zero)
        }
    }
}

/// How the shell splits for a given container.
struct ShellSplit: Equatable {
    var axis: Axis = .horizontal
    var primary: CGFloat = 0
    var gap: CGFloat = 0
    /// Whether the trailing column shows at all.
    var shown = false

    /// The shell's split: a Spread's pages when `spread` is active, else the
    /// Web layout's (`init(fold:hasItem:)`).
    init(fold: FoldInfo, hasItem: Bool, spread: SpreadContext) {
        switch spread.mode {
        case .off:
            self.init(fold: fold, hasItem: hasItem)
        case .span:
            // The tab fills both pages; it keeps the fold clear itself.
            self.init()
        case .pages(let pages):
            self.init()
            shown = true
            primary = CGFloat(pages.left.width)
            gap = CGFloat(pages.gap)
        }
    }

    init() {}

    /// `hasItem`: a title is open. Decided from the container's own size (not
    /// the size class), so the app splits at the same sizes as the web.
    init(fold: FoldInfo, hasItem: Bool) {
        let width = fold.size.width
        if let x = fold.vertical {
            // Half open, fold top to bottom: one column each side of it, always,
            // so nothing (text, posters) runs across the fold.
            shown = true
            axis = .horizontal
            primary = x.lowerBound
            gap = x.upperBound - x.lowerBound
        } else if let y = fold.horizontal {
            // Half open, fold side to side: the tabs above it, the title below.
            shown = true
            axis = .vertical
            primary = y.lowerBound
            gap = y.upperBound - y.lowerBound
        } else if ShellSplitRule.splits(width: Double(width), height: Double(fold.size.height), hasItem: hasItem) {
            shown = true
            axis = .horizontal
            if let x = fold.flatVertical,
               let atFold = ShellSplitRule.foldSplit(width: Double(width),
                                                     fold: Double(x.lowerBound)...Double(x.upperBound)) {
                // Flat open on the Duo: the same rule decides, but the split
                // sits on the fold with a gutter, so the title never crosses it.
                primary = CGFloat(atFold.primary)
                gap = CGFloat(atFold.gap)
            } else {
                // No fold: the web's list | detail, the detail a phone-width-plus column.
                primary = CGFloat(ShellSplitRule.primaryWidth(for: Double(width)))
                gap = CGFloat(ShellSplitRule.divider)
            }
        }
    }
}

/// The trailing column: the open title, or a hint while none is open (only
/// shown when the fold splits the screen anyway).
struct ShellDetailColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread

    var body: some View {
        Group {
            if let ref = model.presentedItem {
                NavigationStack {
                    // The same store the sheet showed (`AppModel.detailStore`), so
                    // unfolding keeps the page, its child sheets and their drafts.
                    ItemDetailView(store: model.detailStore(for: ref.id), onClose: { model.presentedItem = nil })
                        .environment(\.detailInColumn, true)
                }
                .id(ref.id)
            } else if let route = model.spreadPreview, spread.isActive {
                // A Discover or Search preview (S3): its add and request open on this page.
                SpreadPreviewColumn(route: route)
                    .id(route.id)
            } else if spread.isActive {
                // The right page's default for the tab (S2–S6 fill it in).
                SpreadRightPage()
            } else {
                SelectTitleHint()
            }
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
        }
    }
}

extension EnvironmentValues {
    /// True when the title detail is the shell's trailing column rather than a sheet.
    @Entry var detailInColumn = false
    /// True while the Duo is half open with the fold top to bottom (Book pose):
    /// layouts that read across the whole width switch to one column (Q-DC5).
    @Entry var bookPose = false
}
