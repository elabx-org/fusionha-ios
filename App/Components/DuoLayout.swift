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
// Flat open the fold is inactive and zero wide, and nothing reserves it
// (option A, HIG): the Web layout uses the web's 418 | 532 split and a
// Spread a third | two thirds (`DuoSplit`). In either, flat, the sidebar
// button can hide the list (`ShellSplit.primaryHidden`).
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
    /// The sidebar button hid the first child (the list): it keeps its width
    /// just off the leading edge (its grid never re-flows) and the second
    /// child fills the container.
    var primaryHidden = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count > 1 else {
            subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            return
        }
        switch axis {
        case .horizontal where primaryHidden:
            let first = min(max(primary, 0), bounds.width)
            subviews[0].place(at: CGPoint(x: bounds.minX - first - gap, y: bounds.minY),
                              proposal: ProposedViewSize(width: first, height: bounds.height))
            subviews[1].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
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
    /// The list is hidden (the sidebar button, flat only): the trailing
    /// column fills the container.
    var primaryHidden = false

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
            // No fold, or the Duo flat open (option A: flat, nothing is
            // reserved): the web's list | detail, the detail a phone-width-plus column.
            shown = true
            axis = .horizontal
            primary = CGFloat(ShellSplitRule.primaryWidth(for: Double(width)))
            gap = CGFloat(ShellSplitRule.divider)
        }
    }
}

/// The trailing column: the open title, or a hint while none is open (only
/// shown when the fold splits the screen anyway).
struct ShellDetailColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(\.spread) private var spread
    @Environment(\.motionEnabled) private var motion
    @Environment(\.duoOpen) private var duoOpen
    @Environment(\.duoListToggle) private var listToggle
    /// The page following a swipe from its leading edge (`DuoPageEdge`).
    @State private var dragOffset: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    @State private var atRoot = true
    /// The page pulled down past its scroll's top (`DuoColumnPull`), and how
    /// far it has dropped once that closes it.
    @State private var pull = DuoColumnPull()
    @State private var drop: CGFloat = 0

    /// Which page is up: a new title or preview swings in over the last one.
    private var pageKey: String {
        if let ref = model.presentedItem { return "title-\(ref.id)" }
        if let route = model.spreadPreview, spread.isActive { return "preview-\(route.id)" }
        return spread.isActive ? "default" : "hint"
    }

    var body: some View {
        ZStack {
            page
                .transition(duoOpen ? DuoPageMotion.transition(motion: motion) : .opacity)
        }
        .modifier(DuoPageDragEffect(offset: dragOffset, width: width, motion: motion))
        .modifier(DuoColumnPullEffect(progress: pull.progress, drop: drop, motion: motion))
        .environment(\.duoColumnPull, duoOpen && model.rightPageHasItem ? pull : nil)
        // Gesture 6: pull the page down to close it, as its sheet does folded.
        .overlay(alignment: .top) {
            if duoOpen && model.rightPageHasItem { DuoColumnGrabber() }
        }
        .onChange(of: pull.closeRequests) { closeByPull() }
        .animation(duoOpen ? DuoPageMotion.animation(motion: motion) : nil, value: pageKey)
        .overlay(alignment: .leading) {
            Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
        }
        // Gestures 1 and 2: swipe the page away, or the list off and back.
        .overlay(alignment: .leading) {
            if duoOpen && model.rightPageHasItem {
                DuoPageEdge(width: width, canClose: atRoot, list: listToggle, offset: $dragOffset) {
                    model.presentedItem = nil
                    model.spreadPreview = nil
                }
            }
        }
        .onPreferenceChange(DuoPageAtRoot.self) { atRoot = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { width = $0.width; height = $0.height }
    }

    private func closeByPull() {
        withAnimation(.spring(duration: 0.28, bounce: 0)) { drop = height } completion: {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                model.presentedItem = nil
                model.spreadPreview = nil
                drop = 0
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        Group {
            if let ref = model.presentedItem {
                NavigationStack {
                    // The same store the sheet showed (`AppModel.detailStore`), so
                    // unfolding keeps the page, its child sheets and their drafts.
                    ItemDetailView(store: model.detailStore(for: ref.id), onClose: { model.presentedItem = nil })
                        .environment(\.detailInColumn, true)
                        .duoListToggleToolbar()
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
    }
}

extension EnvironmentValues {
    /// True when the title detail is the shell's trailing column rather than a sheet.
    @Entry var detailInColumn = false
    /// True while the Duo is half open with the fold top to bottom (Book pose):
    /// layouts that read across the whole width switch to one column (Q-DC5).
    @Entry var bookPose = false
}
