import SwiftUI
import FusionhaKit

// MARK: - iPhone Duo / wide layout
//
// Folded (a phone-sized window) the app is the phone app: one column, the
// title detail opens as a sheet. With room for two columns (at least 560 x 500
// points, `ShellSplitRule`, the web's rule: the iPhone Duo's inner display, an
// iPad) the shell becomes two columns like the web's wide layout: the tabs on
// the leading side and the open title on the trailing side, in place of the
// sheet. When the Duo is half open (Book) the system reports the
// fold as a reserved `.division` region; the split then lines up with the
// fold so neither column runs across it, and nothing is drawn in the fold.
//
// Every size is container-relative (no screen sizes, idioms or orientation
// checks). The open title lives in `AppModel.presentedItem`, so folding and
// unfolding keeps it: sheet <-> trailing column.

/// Where the fold runs through a container, from its reserved `.division`
/// regions. `nil` ranges mean no fold (folded, flat open, any other device).
struct FoldInfo: Equatable {
    var size: CGSize = .zero
    /// The fold's x-range when it runs top to bottom (book, landscape).
    var vertical: ClosedRange<CGFloat>?
    /// The fold's y-range when it runs side to side (book, portrait).
    var horizontal: ClosedRange<CGFloat>?

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
    }

    /// The frames of the container's `.division` reserved regions (the fold),
    /// in the container's own coordinates.
    static func divisionFrames(_ proxy: GeometryProxy) -> [CGRect] {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division).map(\.frame)
        }
        return []
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
            // Flat open: the web's list | detail, the detail a phone-width-plus column.
            shown = true
            axis = .horizontal
            let detail = CGFloat(ShellSplitRule.detailWidth(for: Double(width)))
            primary = max(width - detail - 1, 0)
            gap = 1
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
                    ItemDetailView(itemId: ref.id, onClose: { model.presentedItem = nil })
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
}

/// Library / Discover poster columns for a content width: three on every
/// phone (unchanged), two in a narrow column, more as the width grows (the
/// web's `repeat(auto-fill, minmax(…))`).
enum PosterColumns {
    static func count(for width: CGFloat) -> Int {
        guard width > 0 else { return 3 }
        if width < 300 { return 2 }
        if width < 520 { return 3 }
        return max(4, Int((width + 6) / 150))
    }
}

/// A poster grid whose column count follows its own width (`PosterColumns`):
/// three tracks on phones, more when unfolded. 18 × 6 gaps like the Library.
struct AdaptivePosterGrid<Content: View>: View {
    var spacing: CGFloat = 18
    @ViewBuilder var content: Content
    @State private var columns = 3

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .top), count: columns),
                  alignment: .leading, spacing: spacing) {
            content
        }
        .onGeometryChange(for: Int.self) { PosterColumns.count(for: $0.size.width) } action: { columns = $0 }
    }
}
