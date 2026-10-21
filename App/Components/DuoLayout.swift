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

/// Where the fold runs through a container, from its reserved `.division`
/// regions. `nil` ranges mean no fold (folded, flat open, any other device).
struct FoldInfo: Equatable {
    var size: CGSize = .zero
    /// The fold's x-range when it runs top to bottom (book, landscape).
    var vertical: ClosedRange<CGFloat>?
    /// The fold's y-range when it runs side to side (book, portrait).
    var horizontal: ClosedRange<CGFloat>?
    /// The fold's x-range when the Duo lies flat open (inactive, zero wide)
    /// and it runs top to bottom through the container. `nil` when `vertical`
    /// is set, or there is no fold.
    var flatVertical: ClosedRange<CGFloat>?

    init() {}

    /// Reads the fold from a container's geometry. The regions are empty on the
    /// first geometry pass and filled in on a later one, so this is read on
    /// every geometry change, never cached.
    init(_ proxy: GeometryProxy) {
        size = proxy.size
        for frame in FoldInfo.divisionFrames(proxy) {
            guard frame.width > 0 || frame.height > 0 else { continue }
            if frame.height >= frame.width {
                vertical = frame.minX...max(frame.minX, frame.maxX)
            } else {
                horizontal = frame.minY...max(frame.minY, frame.maxY)
            }
        }
        if vertical == nil && horizontal == nil {
            flatVertical = FoldInfo.verticalFold(proxy)
        }
    }

    /// The top-to-bottom room to keep empty: half open, the active fold as
    /// reported; flat open, the zero-wide fold with the fold gutter around it.
    var verticalGap: ClosedRange<CGFloat>? {
        if let vertical { return vertical }
        guard let x = flatVertical else { return nil }
        let gap = FoldColumns.gap(around: Double(x.lowerBound)...Double(x.upperBound))
        return CGFloat(gap.lowerBound)...CGFloat(gap.upperBound)
    }

    /// A top-to-bottom fold inside this container, active or not (flat open it
    /// is zero wide), as its x-range in the container's coordinates. Layouts
    /// with columns keep their columns off it (`FoldColumns`).
    static func verticalFold(_ proxy: GeometryProxy) -> ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        let width = proxy.size.width
        let frame = proxy.reservedRegions(kind: .division, options: .includeInactive)
            .map(\.frame)
            .first { $0.height > 0 && $0.height >= $0.width && $0.minX > 0 && $0.maxX < width }
        return frame.map { $0.minX...max($0.minX, $0.maxX) }
    }

    /// The frames of the container's `.division` reserved regions (the fold),
    /// in the container's own coordinates.
    static func divisionFrames(_ proxy: GeometryProxy) -> [CGRect] {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).map(\.frame)
        }
        return []
    }

    /// Whether a fold, folded flat or not (an inactive `.division` counts), runs
    /// top to bottom through the middle of this container. Grids use it to pick
    /// an even column count, so the fold falls in a gutter, never on a poster.
    static func crossesMiddle(_ proxy: GeometryProxy) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        let width = proxy.size.width
        guard width > 0 else { return false }
        return proxy.reservedRegions(kind: .division, options: .includeInactive).contains { region in
            let frame = region.frame
            return frame.height >= frame.width && abs(frame.midX - width / 2) <= max(frame.width, 12)
        }
    }
}

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
            } else {
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

/// Library / Discover poster columns for a content width: three on every
/// phone (unchanged), two in a narrow column, more as the width grows (the
/// web's `repeat(auto-fill, minmax(…))`).
enum PosterColumns {
    /// `evenForFold`: a fold crosses the grid's middle (`FoldInfo.crossesMiddle`),
    /// so an odd count drops by one and the fold lands in the centre gutter.
    static func count(for width: CGFloat, evenForFold: Bool = false) -> Int {
        let count = baseCount(for: width)
        return evenForFold && count % 2 == 1 ? max(2, count - 1) : count
    }

    private static func baseCount(for width: CGFloat) -> Int {
        guard width > 0 else { return 3 }
        if width < 300 { return 2 }
        if width < 520 { return 3 }
        return max(4, Int((width + 10) / 150))
    }
}

/// A poster grid whose column count follows its own width (`PosterColumns`):
/// three tracks on phones, more when unfolded, an even count when the fold
/// crosses it. 22 × 10 gaps like the Library.
struct AdaptivePosterGrid<Content: View>: View {
    var spacing: CGFloat = 22
    var columnSpacing: CGFloat = 10
    @ViewBuilder var content: Content
    @State private var columns = 3

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: columnSpacing, alignment: .top), count: columns),
                  alignment: .leading, spacing: spacing) {
            content
        }
        .onGeometryChange(for: Int.self) { proxy in
            PosterColumns.count(for: proxy.size.width, evenForFold: FoldInfo.crossesMiddle(proxy))
        } action: { columns = $0 }
    }
}
